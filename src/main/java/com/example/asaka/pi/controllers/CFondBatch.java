package com.example.asaka.pi.controllers;

import com.example.asaka.pi.services.SFondBatch;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Fond batch import endpoints — Ariza (claim), Qaror (decision), To'lov (payout).
 *
 * Each endpoint accepts a JSON body of the shape:
 *   { "rows": [ {"colName": "value", ...}, ... ] }
 *
 * Header keys arrive as Excel dot-notation
 * (e.g. "applicant.person.passportData.pinfl") and are mapped to
 * lower_snake_case table columns server-side.
 *
 * Workflow the caller drives:
 *   1) POST /api/app/fond/claim/import     — send ariza(s) → claim UUIDs
 *   2) POST /api/app/fond/decision/import  — send qaror(s) → decision UUIDs
 *      - rows with decisionId=2 stop here (rejection)
 *      - rows with decisionId=1 continue
 *   3) POST /api/app/fond/payout/import    — send to'lov(s) → payout UUIDs
 */
@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/app/fond")
public class CFondBatch {

  @Autowired SFondBatch sFondBatch;

  @PostMapping(value = "/claim/import", produces = "application/json")
  public ResponseEntity<?> importClaim(@RequestBody String data) {
    return handle(data, "claim");
  }

  @PostMapping(value = "/decision/import", produces = "application/json")
  public ResponseEntity<?> importDecision(@RequestBody String data) {
    return handle(data, "decision");
  }

  @PostMapping(value = "/payout/import", produces = "application/json")
  public ResponseEntity<?> importPayout(@RequestBody String data) {
    return handle(data, "payout");
  }

  private ResponseEntity<?> handle(String data, String kind) {
    try {
      JSONObject r;
      switch (kind) {
        case "claim":    r = sFondBatch.importClaim(data); break;
        case "decision": r = sFondBatch.importDecision(data); break;
        default:         r = sFondBatch.importPayout(data);
      }
      return ResponseEntity.ok(r.toString());
    } catch (IllegalArgumentException e) {
      return ResponseEntity.status(HttpStatus.BAD_REQUEST)
          .body(new JSONObject().put("success", false).put("error", e.getMessage()).toString());
    } catch (Exception e) {
      return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
          .body(new JSONObject().put("success", false).put("error", e.getMessage()).toString());
    }
  }
}
