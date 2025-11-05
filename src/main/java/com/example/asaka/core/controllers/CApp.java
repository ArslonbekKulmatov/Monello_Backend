package com.example.asaka.core.controllers;

import com.example.asaka.core.services.SApp;
import com.example.asaka.core.services.SGrid;
import com.example.asaka.core.services.SGrid_New;
import com.example.asaka.core.services.SUser;
import com.example.asaka.lnm.services.SLnm;
import org.json.JSONException;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.InputStreamResource;
import org.springframework.core.io.Resource;
import org.springframework.http.ResponseEntity;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import javax.servlet.http.HttpServletRequest;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/app")
@EnableAsync
public class CApp {
  @Autowired private SApp sApp;
  @Autowired private SGrid sGrid;

  @Autowired private SGrid_New sGrid_new;

  @Autowired private SLnm sLnm;

  private @Autowired SUser sUser;

  @RequestMapping(value = "/request", produces = "application/json")
  public ResponseEntity<?> setMethod(@RequestBody String params) throws Exception {
    JSONObject resp = new JSONObject(sApp.post(params, true));
    if (!resp.getBoolean("success")) {
      if (resp.getString("message").contains("403 FORBIDDEN")) {
        return sUser.jwtExpired("JWT token has been expired");
      }
    }
    return ResponseEntity.ok(resp.toString());
  }

  @RequestMapping(value = "/grid", produces = "application/json")
  public ResponseEntity<?> userStr(@RequestBody String params) throws JSONException {
    JSONObject rows = sGrid.grid(params);
    if (!rows.getBoolean("success")) {
      if (rows.getString("message").contains("403 FORBIDDEN")) {
        return sUser.jwtExpired("JWT token has been expired");
      }
    }
    return ResponseEntity.ok(rows.toString());
  }

  @RequestMapping(value = "/execSelect", produces = "application/json")
  public ResponseEntity<?> execSelect(@RequestBody String params) throws Exception {
    JSONObject object = new JSONObject(params);
    String view = object.getString("view");
    if (view.equalsIgnoreCase("lnm_judical_history_v")) {
      String wh = object.getString("wh");
      String loan_id = wh.replaceAll("[^0-9]", "");
      JSONObject req = new JSONObject();
      req.put("loan_id", loan_id);
      sLnm.sendAndInsertData(req.toString());
    }
    JSONObject resp = new JSONObject(sApp.execSelect(params));
    if (!resp.getBoolean("success")) {
      if (resp.getString("message").contains("403 FORBIDDEN")) {
        return sUser.jwtExpired("JWT token has been expired");
      }
    }
    return ResponseEntity.ok(resp.toString());
  }

  @RequestMapping(value = "/requestFile")
  public ResponseEntity<?> setMethodWithFile(@RequestParam("params") String params, @RequestParam(value = "file", required = false) MultipartFile multipartFile) throws Exception {
    JSONObject resp = new JSONObject(sApp.postFile(params, multipartFile));
    if (!resp.getBoolean("success")) {
      if (resp.getString("message").contains("403 FORBIDDEN")) {
        return sUser.jwtExpired("JWT token has been expired");
      }
    }
    return ResponseEntity.ok(resp.toString());
  }

  @RequestMapping(value = "/wtrequest", produces = "application/json")
  public ResponseEntity<?> setMethod2(@RequestBody String params) throws Exception {
    return ResponseEntity.ok(sApp.wtpost(params));
  }

  //Cr By: Arslonbek Kulmatov
  //Grid working with session scope
  @RequestMapping(value = "/grid/new", produces = "application/json")
  public ResponseEntity<?> grid(@RequestBody String params) throws JSONException {
    JSONObject rows = sGrid_new.grid(params);
    if (!rows.getBoolean("success")) {
      if (rows.getString("message").contains("403 FORBIDDEN")) {
        return sUser.jwtExpired("JWT token has been expired");
      }
    }
    return ResponseEntity.ok(rows.toString());
  }

  //Cr By: Arslonbek Kulmatov
  //Grid filter working with session scope
  @RequestMapping(value = "/grid/get_filter", produces = "application/json")
  public ResponseEntity<?> getFilter(@RequestBody String params, HttpServletRequest request) throws JSONException {
    JSONObject resp = sGrid_new.getFilter(params, request);
    return ResponseEntity.ok(resp.toString());
  }

  //Cr By: Arslonbek Kulmatov
  //Grid filter working with session scope
  @RequestMapping(value = "/grid/remove_session", produces = "application/json")
  public String removeSession(@RequestBody String params) throws JSONException {
    return sGrid_new.removeGridSession(params).toString();
  }

  //Cr By: Arslonbek Kulmatov
  //getting grid data into excel
  @RequestMapping("/grid/to_excel")
  public ResponseEntity<InputStreamResource> toExcel(@RequestBody String params) {
    return sGrid_new.toExcel(params);
  }

  //Cr By: Saidazim,
  @RequestMapping(value = "/get-http-token", produces = "application/json")
  public String getHttpAuthToken(@RequestBody String params) {
    return sApp.getHttpToken(params);
  }

  @RequestMapping(value = "/send-http-request", produces = "application/json")
  public String sendHttpRequest(@RequestBody String params) {
    return sApp.sendHttpRequest(params);
  }

  @RequestMapping(value = "/get-http-request", produces = "application/json")
  public String getHttpRequest(@RequestBody String params) {
    return sApp.getHttpRequest(params);
  }

  // Saidazim
  @RequestMapping(value = "/send-form-data-request", produces = "application/json")
  public String sendFormDataRequest(@RequestBody String params) {
    return sApp.getHttpRequest(params);
  }

  // Saidazim
  @GetMapping("/get-file")
  public ResponseEntity<Resource> getFile(@RequestParam("file") String file) {
    return sApp.getFile(file);
  }
}
