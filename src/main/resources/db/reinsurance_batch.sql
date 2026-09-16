-- ===========================================================================
-- Reinsurance batch import — schema + procedures
--
-- Author : Arslonbek Kulmatov
-- Purpose: Web-based upload of reinsurance batches (Excel + PDF documents)
--          without touching existing Send_Reinsurance / Send_Reinsurance_File.
--
-- Apply order:
--   1) Run the ALTER TABLE block below.
--   2) Add the two procedure declarations into the PI_INSURANCE_SERVICE
--      package spec (see block "PACKAGE SPEC — ADD").
--   3) Add the two procedure bodies into the PI_INSURANCE_SERVICE package
--      body (see block "PACKAGE BODY — ADD").
--   4) Register both procedures in CORE_METHODS if you want them callable
--      through the metadata-driven /api/app/request pipeline (optional —
--      the Java layer calls them directly by name).
-- ===========================================================================


-- ----- 1) Table columns ----------------------------------------------------
Alter Table PI_FOND_REINSURANCES Add (
  batch_id  Varchar2(64),
  error_msg Varchar2(4000),
  cr_by     Number(10)
);

Create Index Ix_Pi_Fond_Reins_Batch On PI_FOND_REINSURANCES (batch_id);


-- ----- 2) PACKAGE SPEC — ADD (inside PI_INSURANCE_SERVICE spec) -----------
--
--   -- Send only rows of one import batch to Fond (/reclaim/create)
--   Procedure Send_Reinsurance_Batch(iBatch_Id Varchar2, oResp Out Clob);
--
--   -- Upload the PDF payout files for one batch (/reclaim/upload-payout-file)
--   Procedure Send_Reinsurance_File_Batch(iBatch_Id Varchar2, oResp Out Clob);
--


-- ----- 3) PACKAGE BODY — ADD (inside PI_INSURANCE_SERVICE body) -----------

  Procedure Send_Reinsurance_Batch(iBatch_Id Varchar2, oResp Out Clob) Is
    vRequest  Json_Object_t := Json_Object_t();
    vResponse Clob;
    vData     Clob;
    vUuid     Varchar2(512);
    vResults  Json_Array_t  := Json_Array_t();
    vRow      Json_Object_t;
    vOk       Number(10)    := 0;
    vFail     Number(10)    := 0;
  Begin
    For i In (Select *
                From Pi_Fond_Reinsurances r
               Where r.batch_id = iBatch_Id
                 And r.uuid Is Null
                 And r.error_msg Is Null) Loop

      Begin
        If i.claim_uuid Is Not Null Then
          vData := '{
                      "reinsuranceContractUuid": "' || i.reinsurance_contract_uuid || '",
                      "totalDamageSum": "' || To_Char(Round(Replace(Replace(i.total_damages_sum, ' ', ''), ',', '.'), 2)) || '",
                      "totalSharePaymentSum": "' || Round(Replace(Replace(i.total_share_payment_sum, ' ', ''), ',', '.'), 2) || '",
                      "claims": [
                        {
                          "claimUuid": "' || Regexp_Replace(i.claim_uuid, '[^A-Za-z0-9\-]', '') || '",
                          "insuranceCompensationSum": "' || Round(Replace(Replace(i.insurance_compensation_sum, ' ', ''), ',', '.'), 2) || '",
                          "sharePaymentSum": "' || Round(Replace(Replace(i.share_payment_sum, ' ', ''), ',', '.'), 2) || '"
                        }
                      ]
                    }';
        Else
          vData := '{
                      "reinsuranceContractUuid": "' || i.reinsurance_contract_uuid || '",
                      "currencyId": "' || i.currency_id || '",
                      "exchangeRate": "' || Replace(Replace(i.exchange_rate, ' ', ''), ',', '.') || '",
                      "totalDamageSum": "' || To_Char(Round(Replace(Replace(i.total_damages_sum, ' ', ''), ',', '.'), 2)) || '",
                      "totalDamageInForeignCurrency": "' || Replace(Replace(i.total_damage_in_foreign_currency, ' ', ''), ',', '.') || '",
                      "totalSharePaymentSum": "' || Round(Replace(Replace(i.total_share_payment_sum, ' ', ''), ',', '.'), 2) || '",
                      "totalSharePaymentInForeignCurrency": "' || Replace(Replace(i.total_share_payment_in_foreign_currency, ' ', ''), ',', '.') || '",
                      "claims": [
                        {
                          "claimUuid": "' || Regexp_Replace(Nvl(i.claim_uuid, ''), '[^A-Za-z0-9\-]', '') || '",
                          "contractNumber": "' || Replace(i.contract_number, '"', '\"') || '",
                          "claimNumber": "' || i.claim_number || '",
                          "claimDate": "' || i.claim_date || '",
                          "decisionDate": "' || i.decision_date || '",
                          "paymentDate": "' || i.payment_date || '",
                          "paymentAmountSum": "' || Replace(Replace(i.payment_amount_sum, ' ', ''), ',', '.') || '",
                          "paymentAmountInForeignCurrency": "' || Replace(Replace(i.payment_amount_in_foreign_currency, ' ', ''), ',', '.') || '",
                          "insuranceCompensationSum": "' || Replace(Replace(i.insurance_compensation_sum, ' ', ''), ',', '.') || '",
                          "insuranceCompensationInForeignCurrency": "' || Replace(Replace(i.insurance_compensation_in_foreign_currency, ' ', ''), ',', '.') || '",
                          "sharePaymentSum": "' || Round(Replace(Replace(i.share_payment_sum, ' ', ''), ',', '.'), 2) || '",
                          "sharePaymentInForeignCurrency": "' || Replace(Replace(i.share_payment_in_foreign_currency, ' ', ''), ',', '.') || '",
                          "eventCircumstances": {
                            "eventDateTime": "' || i.event_date_time || ' 12:00:00",
                            "regionId": "' || Nvl(i.region_id, '10') || '",
                            "countryId": "' || i.country_id || '",
                            "districtId": "' || Nvl(i.district_id, '1010') || '",
                            "place": "' || Replace(i.place, '"', '\"') || '",
                            "eventInfo": "---"
                          }
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
        vRequest.Put('url',         c_Host || '/api/v3/reclaim/create');

        vResponse := Core_Util.Send_Http(vRequest.To_Clob(), c_Mdw_Url);
        vUuid     := Json_Value(vResponse, '$.data.result.uuid');

        vRow := Json_Object_t();
        vRow.Put('id',   i.id);
        vRow.Put('uuid_row', i.reinsurance_contract_uuid);

        If vUuid Is Not Null Then
          Update Pi_Fond_Reinsurances r
             Set r.request  = vData,
                 r.response = vResponse,
                 r.uuid     = vUuid
           Where r.id = i.id;
          Commit;

          vRow.Put('sent',      True);
          vRow.Put('claimUuid', vUuid);
          vOk := vOk + 1;
        Else
          Update Pi_Fond_Reinsurances r
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
          Update Pi_Fond_Reinsurances r
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
  End Send_Reinsurance_Batch;


  Procedure Send_Reinsurance_File_Batch(iBatch_Id Varchar2, oResp Out Clob) Is
    vRequest   Json_Object_t := Json_Object_t();
    vFileName  Varchar2(256);
    vData      Clob;
    vResponse  Clob;
    vResults   Json_Array_t  := Json_Array_t();
    vRow       Json_Object_t;
    vOk        Number(10)    := 0;
    vFail      Number(10)    := 0;
  Begin
    For i In (Select *
                From Pi_Fond_Reinsurances r
               Where r.batch_id     = iBatch_Id
                 And r.uuid         Is Not Null
                 And r.is_file_send Is Null) Loop

      Begin
        vFileName := i.reinsurance_contract_uuid || '.pdf';
        vData     := '{ "reClaimUuid": "' || i.uuid || '" }';

        vRequest := Json_Object_t();
        vRequest.Put('body',        Json_Object_t.Parse(vData));
        vRequest.Put('token',       v_Token);
        vRequest.Put('method_type', 'POST');
        vRequest.Put('is_proxy',    True);
        vRequest.Put('proxy_ip',    '192.168.1.201');
        vRequest.Put('proxy_port',  8080);
        vRequest.Put('url',         c_Host || '/api/v3/reclaim/upload-payout-file');
        vRequest.Put('file_name',   vFileName);

        vResponse := Core_Util.Send_Http(vRequest.To_Clob(),
                                         'http://192.168.1.198:9999/api/app/send-form-data-request');

        Update Pi_Fond_Reinsurances t
           Set t.file_name     = vFileName,
               t.file_request  = vData,
               t.file_response = vResponse
         Where t.id = i.id;
        Commit;

        vRow := Json_Object_t();
        vRow.Put('id',       i.id);
        vRow.Put('fileName', vFileName);

        If Json_Value(vResponse, '$.success') = 'true' Then
          Update Pi_Fond_Reinsurances t
             Set t.is_file_send = 'Y'
           Where t.id = i.id;
          Commit;

          vRow.Put('sent', True);
          vOk := vOk + 1;
        Else
          Update Pi_Fond_Reinsurances t
             Set t.error_msg = Substr(Nvl(Json_Value(vResponse, '$.error'),
                                          Nvl(vResponse, 'no response')), 1, 4000)
           Where t.id = i.id;
          Commit;

          vRow.Put('sent',  False);
          vRow.Put('error', Substr(Nvl(Json_Value(vResponse, '$.error'),
                                       Nvl(vResponse, 'no response')), 1, 500));
          vFail := vFail + 1;
        End If;

        vResults.Append(vRow);

      Exception
        When Others Then
          Rollback;
          Update Pi_Fond_Reinsurances t
             Set t.error_msg = Substr(Sqlerrm, 1, 4000)
           Where t.id = i.id;
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
  End Send_Reinsurance_File_Batch;
