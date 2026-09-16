package com.example.asaka.pi.controllers;

import com.example.asaka.pi.services.SReinsurance;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/app/reinsurance")
public class CReinsurance {

  @Autowired SReinsurance sReinsurance;

  /**
   * Import a batch of reinsurance rows and their PDF documents.
   *
   * Multipart:
   *   data       - JSON string. Either { "rows": [ {..}, {..} ] } or a raw JSON array.
   *                Every row uses the header names from the Excel template:
   *                reinsuranceContractUuid, currencyId, exchangeRate, totalDamageSum,
   *                totalDamageInForeignCurrency, totalSharePaymentSum,
   *                totalSharePaymentInForeignCurrency, claimUuid, contractNumber,
   *                claimNumber, claimDate, decisionDate, paymentDate,
   *                paymentAmountSum, paymentAmountInForeignCurrency,
   *                insuranceCompensationSum, insuranceCompensationInForeignCurrency,
   *                sharePaymentSum, sharePaymentInForeignCurrency, eventDateTime,
   *                regionId, countryId, districtId, place, eventInfo
   *   documents  - one or more PDFs named "<reinsuranceContractUuid>.pdf"
   *
   * Every non-blank row is inserted into PI_FOND_REINSURANCES with a shared
   * batch_id; invalid rows are stored with error_msg and skipped from the Fond
   * call. Then Send_Reinsurance_Batch and Send_Reinsurance_File_Batch are
   * invoked for that batch only.
   */
  @PostMapping(value = "/import", produces = "application/json")
  public ResponseEntity<?> importBatch(@RequestParam("data") String data,
                                       @RequestParam(value = "documents", required = false)
                                       MultipartFile[] documents) {
    try {
      JSONObject result = sReinsurance.importBatch(data, documents);
      return ResponseEntity.ok(result.toString());
    } catch (IllegalArgumentException e) {
      return ResponseEntity.status(HttpStatus.BAD_REQUEST)
          .body(new JSONObject().put("success", false).put("error", e.getMessage()).toString());
    } catch (Exception e) {
      return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
          .body(new JSONObject().put("success", false).put("error", e.getMessage()).toString());
    }
  }
}
