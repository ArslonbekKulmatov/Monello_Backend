-- ===========================================================================
-- Fond Claim / Decision / Payout batch import — schema + procedures
--
-- Author : Arslonbek Kulmatov
-- Purpose: Web-based bulk upload of Fond requests (ariza / qaror / to'lov).
--          Mirrors the reinsurance batch pattern.
--
--   Workflow:
--     1) Ariza (Claim)    → PI_FOND_CLAIMS   → Send_Claim_Batch(batch_id)
--     2) Qaror (Decision) → PI_FOND_DECISIONS → Send_Decision_Batch(batch_id)
--        - decisionId=2 (rad etildi)   → tugadi
--        - decisionId=1 (to'lov qaror) → 3-qadam
--     3) To'lov (Payout)  → PI_FOND_PAYOUTS  → Send_Payout_Batch(batch_id)
--
-- Apply order:
--   1) ALTER TABLE blocks below.
--   2) Add the three procedure declarations to PI_INSURANCE_SERVICE spec.
--   3) Add the three procedure bodies to PI_INSURANCE_SERVICE body.
--   4) Recompile package.
-- ===========================================================================


-- ----- 1) Table columns ----------------------------------------------------
Alter Table PI_FOND_CLAIMS Add (
  batch_id  Varchar2(64),
  error_msg Varchar2(4000),
  cr_by     Number(10)
);
Create Index Ix_Pi_Fond_Claims_Batch On PI_FOND_CLAIMS (batch_id);

Alter Table PI_FOND_DECISIONS Add (
  batch_id  Varchar2(64),
  error_msg Varchar2(4000),
  cr_by     Number(10)
);
Create Index Ix_Pi_Fond_Decisions_Batch On PI_FOND_DECISIONS (batch_id);

Alter Table PI_FOND_PAYOUTS Add (
  batch_id  Varchar2(64),
  error_msg Varchar2(4000),
  cr_by     Number(10)
);
Create Index Ix_Pi_Fond_Payouts_Batch On PI_FOND_PAYOUTS (batch_id);


-- ----- 2) PACKAGE SPEC — ADD (inside PI_INSURANCE_SERVICE spec) -----------
--
--   Procedure Send_Claim_Batch   (iBatch_Id Varchar2, oResp Out Clob);
--   Procedure Send_Decision_Batch(iBatch_Id Varchar2, oResp Out Clob);
--   Procedure Send_Payout_Batch  (iBatch_Id Varchar2, oResp Out Clob);
--


-- ----- 3) PACKAGE BODY — ADD (inside PI_INSURANCE_SERVICE body) -----------

  Procedure Send_Claim_Batch(iBatch_Id Varchar2, oResp Out Clob) Is
    vRequest  Json_Object_t := Json_Object_t();
    vResponse Clob;
    vData     Clob;
    vFondUuid Varchar2(512);
    vResults  Json_Array_t  := Json_Array_t();
    vRow      Json_Object_t;
    vOk       Number(10)    := 0;
    vFail     Number(10)    := 0;
  Begin
    For i In (Select *
                From Pi_Fond_Claims r
               Where r.batch_id = iBatch_Id
                 And r.fond_uuid Is Null
                 And r.error_msg Is Null) Loop

      Begin
        vData := '{
                    "polisUuid": "' || Nvl(i.polisUuid, '') || '",
                    "regionId": "' || Nvl(i.regionId, '') || '",
                    "areaTypeId": "' || Nvl(i.areaTypeId, '') || '",
                    "claimNumber": "' || Nvl(i.claimNumber, '') || '",
                    "claimDate": "' || Nvl(i.claimDate, '') || '",
                    "insuranceCompensationSum": "' || Nvl(i.insuranceCompensationSum, '') || '",
                    "applicant": '   || Generate_Applicant(i) || ',
                    "responsibleForDamage": ' || Generate_Responsible_For_Damage(i) || ',
                    "responsibleVehicleInfo": ' || Generate_Responsible_Vehicle_Info(i) || ',
                    "eventCircumstances": ' || Generate_Event_Circumstances(i) || ',
                    ' || Generate_Damage(i) || '
                  }';

        vRequest := Json_Object_t();
        vRequest.Put('body',        vData);
        vRequest.Put('token',       v_Token);
        vRequest.Put('method_type', 'POST');
        vRequest.Put('is_proxy',    True);
        vRequest.Put('proxy_ip',    '192.168.1.201');
        vRequest.Put('proxy_port',  8080);
        vRequest.Put('url',         c_Host || '/api/claim');

        vResponse := Core_Util.Send_Http(vRequest.To_Clob(), c_Mdw_Url);
        vFondUuid := Json_Value(vResponse, '$.data.result.uuid');

        vRow := Json_Object_t();
        vRow.Put('id',          i.id);
        vRow.Put('claimNumber', i.claimNumber);

        If vFondUuid Is Not Null Then
          Update Pi_Fond_Claims r
             Set r.request   = vData,
                 r.response  = vResponse,
                 r.fond_uuid = vFondUuid
           Where r.id = i.id;
          Commit;

          vRow.Put('sent',      True);
          vRow.Put('claimUuid', vFondUuid);
          vOk := vOk + 1;
        Else
          Update Pi_Fond_Claims r
             Set r.request   = vData,
                 r.response  = vResponse,
                 r.error_msg = Substr(Nvl(Json_Value(vResponse, '$.error.message'),
                                          Nvl(vResponse, 'no response')), 1, 4000)
           Where r.id = i.id;
          Commit;

          vRow.Put('sent',  False);
          vRow.Put('error', Substr(Nvl(Json_Value(vResponse, '$.error.message'),
                                       Nvl(vResponse, 'no response')), 1, 500));
          vFail := vFail + 1;
        End If;

        vResults.Append(vRow);

      Exception
        When Others Then
          Rollback;
          Update Pi_Fond_Claims r
             Set r.error_msg = Substr(Sqlerrm, 1, 4000)
           Where r.id = i.id;
          Commit;

          vRow := Json_Object_t();
          vRow.Put('id',    i.id);
          vRow.Put('sent',  False);
          vRow.Put('error', Substr(Sqlerrm, 1, 500));
          vResults.Append(vRow);
          vFail := vFail + 1;
      End;
    End Loop;

    Declare
      vOut Json_Object_t := Json_Object_t();
    Begin
      vOut.Put('batchId', iBatch_Id);
      vOut.Put('sent',    vOk);
      vOut.Put('failed',  vFail);
      vOut.Put('rows',    vResults);
      oResp := vOut.To_Clob();
    End;
  End Send_Claim_Batch;


  Procedure Send_Decision_Batch(iBatch_Id Varchar2, oResp Out Clob) Is
    vRequest  Json_Object_t := Json_Object_t();
    vResponse Clob;
    vData     Clob;
    vFondUuid Varchar2(512);
    vResults  Json_Array_t  := Json_Array_t();
    vRow      Json_Object_t;
    vOk       Number(10)    := 0;
    vFail     Number(10)    := 0;
  Begin
    For i In (Select *
                From Pi_Fond_Decisions r
               Where r.batch_id = iBatch_Id
                 And r.fond_uuid Is Null
                 And r.error_msg Is Null) Loop

      Begin
        vData := '{
                    "claimUuid": "' || Nvl(i.claim_uuid, '') || '",
                    "decision": {
                      "decisionId": ' || i.decision_id || ',
                      "rejectionReason": "' || Replace(Nvl(i.rejection_reason, ''), '"', '\"') || '",
                      "reasonForPayment": "' || Replace(Nvl(i.payment_reason, ''), '"', '\"') || '",
                      "decisionDate": "' || Nvl(i.decision_date, '') || '"
                    }
                  }';

        vRequest := Json_Object_t();
        vRequest.Put('body',        vData);
        vRequest.Put('token',       v_Token);
        vRequest.Put('method_type', 'POST');
        vRequest.Put('is_proxy',    True);
        vRequest.Put('proxy_ip',    '192.168.1.201');
        vRequest.Put('proxy_port',  8080);
        vRequest.Put('url',         c_Host || '/api/v3/claim/add-decision');

        vResponse := Core_Util.Send_Http(vRequest.To_Clob(), c_Mdw_Url);
        vFondUuid := Json_Value(vResponse, '$.data.result.uuid');

        vRow := Json_Object_t();
        vRow.Put('id',        i.id);
        vRow.Put('claim_uuid', i.claim_uuid);

        If vFondUuid Is Not Null Then
          Update Pi_Fond_Decisions r
             Set r.request   = vData,
                 r.response  = vResponse,
                 r.fond_uuid = vFondUuid
           Where r.id = i.id;
          Commit;

          vRow.Put('sent',          True);
          vRow.Put('decisionUuid',  vFondUuid);
          vOk := vOk + 1;
        Else
          Update Pi_Fond_Decisions r
             Set r.request   = vData,
                 r.response  = vResponse,
                 r.error_msg = Substr(Nvl(Json_Value(vResponse, '$.error.message'),
                                          Nvl(vResponse, 'no response')), 1, 4000)
           Where r.id = i.id;
          Commit;

          vRow.Put('sent',  False);
          vRow.Put('error', Substr(Nvl(Json_Value(vResponse, '$.error.message'),
                                       Nvl(vResponse, 'no response')), 1, 500));
          vFail := vFail + 1;
        End If;

        vResults.Append(vRow);

      Exception
        When Others Then
          Rollback;
          Update Pi_Fond_Decisions r
             Set r.error_msg = Substr(Sqlerrm, 1, 4000)
           Where r.id = i.id;
          Commit;

          vRow := Json_Object_t();
          vRow.Put('id',    i.id);
          vRow.Put('sent',  False);
          vRow.Put('error', Substr(Sqlerrm, 1, 500));
          vResults.Append(vRow);
          vFail := vFail + 1;
      End;
    End Loop;

    Declare
      vOut Json_Object_t := Json_Object_t();
    Begin
      vOut.Put('batchId', iBatch_Id);
      vOut.Put('sent',    vOk);
      vOut.Put('failed',  vFail);
      vOut.Put('rows',    vResults);
      oResp := vOut.To_Clob();
    End;
  End Send_Decision_Batch;


  Procedure Send_Payout_Batch(iBatch_Id Varchar2, oResp Out Clob) Is
    vRequest  Json_Object_t := Json_Object_t();
    vResponse Clob;
    vData     Clob;
    vFondUuid Varchar2(512);
    vResults  Json_Array_t  := Json_Array_t();
    vRow      Json_Object_t;
    vOk       Number(10)    := 0;
    vFail     Number(10)    := 0;
  Begin
    For i In (Select *
                From Pi_Fond_Payouts r
               Where r.batch_id = iBatch_Id
                 And r.fond_uuid Is Null
                 And r.error_msg Is Null) Loop

      Begin
        If i.type = 'LIFE' Then
          vData := '{
                      "decisionUuid": "' || Nvl(i.decision_uuid, '') || '",
                      "lifePayouts": [
                        {
                          "payoutSum": "' || Nvl(i.payment_sum, '') || '",
                          "payoutDate": "' || Nvl(i.payment_date, '') || '",
                          "paymentOrderNumber": "' || Nvl(i.payment_order_number, '') || '",
                          "recipient": "' || Replace(Nvl(i.recipient, ''), '"', '\"') || '",
                          "inheritanceDocumentNumberAndDate": "' || Nvl(i.inheritance_document_number, '') || '"
                        }
                      ]
                    }';
        Elsif i.type = 'HEALTH' Then
          vData := '{
                      "decisionUuid": "' || Nvl(i.decision_uuid, '') || '",
                      "healthPayouts": [
                        {
                          "payoutSum": "' || Nvl(i.payment_sum, '') || '",
                          "payoutDate": "' || Nvl(i.payment_date, '') || '",
                          "paymentOrderNumber": "' || Nvl(i.payment_order_number, '') || '",
                          "recipient": "' || Replace(Nvl(i.recipient, ''), '"', '\"') || '"
                        }
                      ]
                    }';
        Else
          vData := '{
                      "decisionUuid": "' || Nvl(i.decision_uuid, '') || '",
                      "otherPropertyPayouts": [
                        {
                          "payoutSum": "' || Nvl(i.payment_sum, '') || '",
                          "payoutDate": "' || Nvl(i.payment_date, '') || '",
                          "paymentOrderNumber": "' || Nvl(i.payment_order_number, '') || '",
                          "recipient": "' || Replace(Nvl(i.recipient, ''), '"', '\"') || '"
                        }
                      ]
                    }';
        End If;

        vRequest := Json_Object_t();
        vRequest.Put('body',        vData);
        vRequest.Put('token',       v_Token);
        vRequest.Put('method_type', 'POST');
        vRequest.Put('is_proxy',    True);
        vRequest.Put('proxy_ip',    '192.168.1.201');
        vRequest.Put('proxy_port',  8080);
        vRequest.Put('url',         c_Host || '/api/v3/claim/add-payout');

        vResponse := Core_Util.Send_Http(vRequest.To_Clob(), c_Mdw_Url);
        vFondUuid := Json_Value(vResponse, '$.data.result.uuid');

        vRow := Json_Object_t();
        vRow.Put('id',           i.id);
        vRow.Put('decisionUuid', i.decision_uuid);

        If vFondUuid Is Not Null Then
          Update Pi_Fond_Payouts r
             Set r.request   = vData,
                 r.response  = vResponse,
                 r.fond_uuid = vFondUuid
           Where r.id = i.id;
          Commit;

          vRow.Put('sent',       True);
          vRow.Put('payoutUuid', vFondUuid);
          vOk := vOk + 1;
        Else
          Update Pi_Fond_Payouts r
             Set r.request   = vData,
                 r.response  = vResponse,
                 r.error_msg = Substr(Nvl(Json_Value(vResponse, '$.error.message'),
                                          Nvl(vResponse, 'no response')), 1, 4000)
           Where r.id = i.id;
          Commit;

          vRow.Put('sent',  False);
          vRow.Put('error', Substr(Nvl(Json_Value(vResponse, '$.error.message'),
                                       Nvl(vResponse, 'no response')), 1, 500));
          vFail := vFail + 1;
        End If;

        vResults.Append(vRow);

      Exception
        When Others Then
          Rollback;
          Update Pi_Fond_Payouts r
             Set r.error_msg = Substr(Sqlerrm, 1, 4000)
           Where r.id = i.id;
          Commit;

          vRow := Json_Object_t();
          vRow.Put('id',    i.id);
          vRow.Put('sent',  False);
          vRow.Put('error', Substr(Sqlerrm, 1, 500));
          vResults.Append(vRow);
          vFail := vFail + 1;
      End;
    End Loop;

    Declare
      vOut Json_Object_t := Json_Object_t();
    Begin
      vOut.Put('batchId', iBatch_Id);
      vOut.Put('sent',    vOk);
      vOut.Put('failed',  vFail);
      vOut.Put('rows',    vResults);
      oResp := vOut.To_Clob();
    End;
  End Send_Payout_Batch;
