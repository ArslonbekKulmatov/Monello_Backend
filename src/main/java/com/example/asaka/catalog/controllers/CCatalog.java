package com.example.asaka.catalog.controllers;

import com.example.asaka.catalog.services.SCatalog;
import lombok.extern.slf4j.Slf4j;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

import java.sql.SQLException;

//Cr By: Arslonbek Kulmatov
//ABM Store sayti uchun katalog API.
//Bu yagona tashqi endpoint — avtorizatsiya doimiy token bilan, JWT emas.
@Slf4j
@RestController
@RequestMapping("/api/catalog")
public class CCatalog {

  @Autowired private SCatalog sCatalog;

  //Cr By: Arslonbek Kulmatov
  //To'liq katalog, sahifalab
  @GetMapping(value = "/products", produces = MediaType.APPLICATION_JSON_VALUE)
  public ResponseEntity<String> products(
      @RequestHeader(value = "Authorization", required = false) String authorization,
      @RequestParam(defaultValue = "1") int page,
      @RequestParam(name = "per_page", defaultValue = "200") int perPage,
      @RequestParam(name = "updated_since", required = false) String updatedSince) {

    Long userId = sCatalog.authenticate(authorization);
    if (userId == null) {
      return error(HttpStatus.UNAUTHORIZED, "Invalid or missing API token");
    }

    JSONObject params = new JSONObject();
    params.put("page", page);
    params.put("per_page", perPage);
    if (updatedSince != null && !updatedSince.isBlank()) {
      params.put("updated_since", updatedSince);
    }
    return call("catalogProducts", params, userId);
  }

  //Cr By: Arslonbek Kulmatov
  //Faqat narx va qoldiq
  @GetMapping(value = "/stock", produces = MediaType.APPLICATION_JSON_VALUE)
  public ResponseEntity<String> stock(
      @RequestHeader(value = "Authorization", required = false) String authorization) {

    Long userId = sCatalog.authenticate(authorization);
    if (userId == null) {
      return error(HttpStatus.UNAUTHORIZED, "Invalid or missing API token");
    }

    return call("catalogStock", new JSONObject(), userId);
  }

  // page=abc kabi noto'g'ri parametrlar 500 emas, 400 qaytarishi kerak
  @ExceptionHandler(MethodArgumentTypeMismatchException.class)
  public ResponseEntity<String> badParam(MethodArgumentTypeMismatchException e) {
    return error(HttpStatus.BAD_REQUEST, "Invalid value for parameter '" + e.getName() + "'");
  }

  private ResponseEntity<String> call(String method, JSONObject params, Long userId) {
    try {
      String body = sCatalog.call(method, params, userId);
      if (body == null) {
        log.error("Katalog metodi bo'sh javob qaytardi: {}", method);
        return error(HttpStatus.INTERNAL_SERVER_ERROR, "Internal error");
      }
      return ResponseEntity.ok().contentType(MediaType.APPLICATION_JSON).body(body);
    } catch (SQLException e) {
      // Core_App.Set_Method validatsiya xatolarini ORA-20000 bilan chiqaradi —
      // ular mijozning aybi, qolgan hamma narsa bizniki.
      if (e.getErrorCode() == 20000) {
        return error(HttpStatus.BAD_REQUEST, cleanOraMessage(e.getMessage()));
      }
      log.error("Katalog metodida baza xatosi: {}", e.getMessage());
      return error(HttpStatus.INTERNAL_SERVER_ERROR, "Internal error");
    } catch (Exception e) {
      log.error("Katalog metodida xato: {}", e.getMessage());
      return error(HttpStatus.INTERNAL_SERVER_ERROR, "Internal error");
    }
  }

  private String cleanOraMessage(String message) {
    if (message == null) {
      return "Bad request";
    }
    String cleaned = message.replaceAll("ORA-\\d{5}:\\s*", "").trim();
    int lineEnd = cleaned.indexOf('\n');
    if (lineEnd > 0) {
      cleaned = cleaned.substring(0, lineEnd).trim();
    }
    return cleaned.isEmpty() ? "Bad request" : cleaned;
  }

  private ResponseEntity<String> error(HttpStatus status, String message) {
    JSONObject body = new JSONObject();
    body.put("error", new JSONObject().put("code", status.value()).put("message", message));
    return ResponseEntity.status(status).contentType(MediaType.APPLICATION_JSON).body(body.toString());
  }
}
