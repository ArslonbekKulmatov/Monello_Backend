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
    vRequest      Json_Object_t := Json_Object_t();
    vResponse     Clob;
    vData         Clob;
    vUuid         Varchar2(512);
    vResults      Json_Array_t  := Json_Array_t();
    vRow          Json_Object_t;
    vOk           Number(10)    := 0;
    vFail         Number(10)    := 0;
    -- Pre-parsed numbers (Oracle 12.2+ safe conversion)
    vTotalDamage  Number;
    vTotalShare   Number;
    vInsCompen    Number;
    vShareSum     Number;
    vExRate       Number;
    vTotalDmgFC   Number;
    vTotalShrFC   Number;
    vPayAmtSum    Number;
    vPayAmtFC     Number;
    vInsCompenFC  Number;
    vShareSumFC   Number;
  Begin
    For i In (Select *
                From Pi_Fond_Reinsurances r
               Where r.batch_id = iBatch_Id
                 And r.uuid Is Null
                 And r.error_msg Is Null) Loop

      Begin
        -- Safe numeric parsing: strip spaces, convert comma-decimal to dot,
        -- fall back to NULL if the string is not a valid number.
        vTotalDamage := To_Number(Replace(Replace(i.total_damages_sum,                     ' ', ''), ',', '.') DEFAULT NULL ON CONVERSION ERROR);
        vTotalShare  := To_Number(Replace(Replace(i.total_share_payment_sum,               ' ', ''), ',', '.') DEFAULT NULL ON CONVERSION ERROR);
        vInsCompen   := To_Number(Replace(Replace(i.insurance_compensation_sum,            ' ', ''), ',', '.') DEFAULT NULL ON CONVERSION ERROR);
        vShareSum    := To_Number(Replace(Replace(i.share_payment_sum,                     ' ', ''), ',', '.') DEFAULT NULL ON CONVERSION ERROR);
        vExRate      := To_Number(Replace(Replace(i.exchange_rate,                         ' ', ''), ',', '.') DEFAULT NULL ON CONVERSION ERROR);
        vTotalDmgFC  := To_Number(Replace(Replace(i.total_damage_in_foreign_currency,      ' ', ''), ',', '.') DEFAULT NULL ON CONVERSION ERROR);
        vTotalShrFC  := To_Number(Replace(Replace(i.total_share_payment_in_foreign_currency, ' ', ''), ',', '.') DEFAULT NULL ON CONVERSION ERROR);
        vPayAmtSum   := To_Number(Replace(Replace(i.payment_amount_sum,                    ' ', ''), ',', '.') DEFAULT NULL ON CONVERSION ERROR);
        vPayAmtFC    := To_Number(Replace(Replace(i.payment_amount_in_foreign_currency,    ' ', ''), ',', '.') DEFAULT NULL ON CONVERSION ERROR);
        vInsCompenFC := To_Number(Replace(Replace(i.insurance_compensation_in_foreign_currency, ' ', ''), ',', '.') DEFAULT NULL ON CONVERSION ERROR);
        vShareSumFC  := To_Number(Replace(Replace(i.share_payment_in_foreign_currency,     ' ', ''), ',', '.') DEFAULT NULL ON CONVERSION ERROR);

        If vTotalDamage Is Null Then
          Raise_Application_Error(-20001, 'totalDamageSum is not a valid number: "' || i.total_damages_sum || '"');
        End If;
        If vTotalShare Is Null Then
          Raise_Application_Error(-20001, 'totalSharePaymentSum is not a valid number: "' || i.total_share_payment_sum || '"');
        End If;

        If i.claim_uuid Is Not Null Then
          vData := '{
                      "reinsuranceContractUuid": "' || i.reinsurance_contract_uuid || '",
                      "totalDamageSum": "' || To_Char(Round(vTotalDamage, 2)) || '",
                      "totalSharePaymentSum": "' || To_Char(Round(vTotalShare, 2)) || '",
                      "claims": [
                        {
                          "claimUuid": "' || Regexp_Replace(i.claim_uuid, '[^A-Za-z0-9\-]', '') || '",
                          "insuranceCompensationSum": "' || To_Char(Round(Nvl(vInsCompen, 0), 2)) || '",
                          "sharePaymentSum": "' || To_Char(Round(Nvl(vShareSum, 0), 2)) || '"
                        }
                      ]
                    }';
        Else
          vData := '{
                      "reinsuranceContractUuid": "' || i.reinsurance_contract_uuid || '",
                      "currencyId": "' || Nvl(i.currency_id, '') || '",
                      "exchangeRate": "' || Nvl(To_Char(vExRate), '0') || '",
                      "totalDamageSum": "' || To_Char(Round(vTotalDamage, 2)) || '",
                      "totalDamageInForeignCurrency": "' || Nvl(To_Char(vTotalDmgFC), '0') || '",
                      "totalSharePaymentSum": "' || To_Char(Round(vTotalShare, 2)) || '",
                      "totalSharePaymentInForeignCurrency": "' || Nvl(To_Char(vTotalShrFC), '0') || '",
                      "claims": [
                        {
                          "claimUuid": "' || Regexp_Replace(Nvl(i.claim_uuid, ''), '[^A-Za-z0-9\-]', '') || '",
                          "contractNumber": "' || Replace(Nvl(i.contract_number, ''), '"', '\"') || '",
                          "claimNumber": "' || Nvl(i.claim_number, '') || '",
                          "claimDate": "' || Nvl(i.claim_date, '') || '",
                          "decisionDate": "' || Nvl(i.decision_date, '') || '",
                          "paymentDate": "' || Nvl(i.payment_date, '') || '",
                          "paymentAmountSum": "' || Nvl(To_Char(vPayAmtSum), '0') || '",
                          "paymentAmountInForeignCurrency": "' || Nvl(To_Char(vPayAmtFC), '0') || '",
                          "insuranceCompensationSum": "' || Nvl(To_Char(vInsCompen), '0') || '",
                          "insuranceCompensationInForeignCurrency": "' || Nvl(To_Char(vInsCompenFC), '0') || '",
                          "sharePaymentSum": "' || To_Char(Round(Nvl(vShareSum, 0), 2)) || '",
                          "sharePaymentInForeignCurrency": "' || Nvl(To_Char(vShareSumFC), '0') || '",
                          "eventCircumstances": {
                            "eventDateTime": "' || Nvl(i.event_date_time, '') || ' 12:00:00",
                            "regionId": "' || Nvl(i.region_id, '10') || '",
                            "countryId": "' || Nvl(i.country_id, '') || '",
                            "districtId": "' || Nvl(i.district_id, '1010') || '",
                            "place": "' || Replace(Nvl(i.place, ''), '"', '\"') || '",
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
