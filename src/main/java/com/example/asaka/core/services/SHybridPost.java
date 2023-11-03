package com.example.asaka.core.services;

import lombok.extern.slf4j.Slf4j;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

@Service
@Slf4j
public class SHybridPost {
  @Autowired
  SApp sApp;

  public String auth() {
    try {
      HttpHeaders headers = new HttpHeaders();
      headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);
      RestTemplate rt = new RestTemplate();
      HttpEntity<String> entity = new HttpEntity<>("username=998971470304&password=998971470304&grant_type=password", headers);
      ResponseEntity<String> resEntity = rt.exchange("https://devhybrid.pochta.uz/token", HttpMethod.POST, entity, String.class);
      return resEntity.getBody();
    } catch (Exception e) {
      log.error(e.getMessage());
      return e.getMessage();
    }
  }

  public String checkCreatingMail(String params) {
    try {
      JSONObject result = new JSONObject(params);
      result.put("method", "pi.hybridPost.checkCreatingMail");
      result.put("params", new JSONObject(params));
      return sApp.post(result.toString(), true);
    } catch (Exception e) {
      log.error(e.getMessage());
      return e.getMessage();
    }
  }

  public String createMail(String params) {
    try {
      JSONObject payload = new JSONObject(params);
      HttpHeaders headers = new HttpHeaders();
      headers.add("Content-type", "application/json");
      headers.add("Authorization", "Bearer " + payload.getString("Token"));
      RestTemplate rt = new RestTemplate();
      HttpEntity<String> entity = new HttpEntity<>(params, headers);
      ResponseEntity<String> resEntity = rt.exchange("https://devhybrid.pochta.uz/api/PdfMail", HttpMethod.POST, entity, String.class);
      // Put "params" data into "resEntity" json object
      JSONObject body = new JSONObject(resEntity.getBody());
      body.put("Document", payload.getString("Document64"));
      body.put("Cover_Id", payload.getNumber("Cover_Id"));
      // Put "resEntity" into "result" for inserting to database
      JSONObject result = new JSONObject();
      result.put("method", "pi.hybridPost.createMail");
      result.put("params", body);
      // Insert "result" to database and return data
      return sApp.post(result.toString(), true);
    } catch (Exception e) {
      log.error(e.getMessage());
      return e.getMessage();
    }
  }

  public String checkSendingMail(String params) {
    try {
      JSONObject result = new JSONObject();
      result.put("method", "pi.hybridPost.checkSendMail");
      result.put("params", params);
      return sApp.post(result.toString(), true);
    } catch (Exception e) {
      log.error(e.getMessage());
      return null;
    }
  }

  public String sendMail(String params) {
    JSONObject resp = new JSONObject();
    try {
      JSONObject payload = new JSONObject(params);
      String hybrid_id = payload.getString("hybrid_id");
      HttpHeaders headers = new HttpHeaders();
      headers.add("Content-type", "application/json");
      headers.add("Authorization", "Bearer " + payload.getString("token"));
      RestTemplate rt = new RestTemplate();
      HttpEntity<String> entity = new HttpEntity<>(params, headers);
      rt.exchange("https://devhybrid.pochta.uz/api/sendMail/{hybrid_id}", HttpMethod.POST, entity, String.class, hybrid_id);
      // Put "params" data into "resEntity" json object
      JSONObject result = new JSONObject(params);
      // Put "resEntity" into "result" for inserting to database
      result.put("method", "pi.hybridPost.sendMail");
      result.put("params", params);
      // Insert "result" to database
      sApp.post(result.toString(), true);
      resp.put("success", true);
      resp.put("message", "successOk");
    } catch (Exception e) {
      resp.put("success", false);
      resp.put("error", e.getMessage());
      log.error(e.getMessage());
    }
    return resp.toString();
  }
}


