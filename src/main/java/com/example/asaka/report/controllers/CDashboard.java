package com.example.asaka.report.controllers;

import com.example.asaka.core.services.SExternalApi;
import lombok.extern.slf4j.Slf4j;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

//Cr By: Arslonbek Kulmatov
//ABM Store boshqaruv paneli uchun hisobot API.
//
//Faqat o'qish: barcha metodlar select qiladi, hech narsa yozmaydi.
//Qamrovi "report" — katalog tokeni bu yerga kira olmaydi.
@Slf4j
@RestController
@RequestMapping("/api/report")
public class CDashboard {

  @Autowired private SExternalApi api;

  //Cr By: Arslonbek Kulmatov
  //Mijozlar soni, filial kesimida
  @GetMapping(value = "/clients", produces = MediaType.APPLICATION_JSON_VALUE)
  public ResponseEntity<String> clients(
      @RequestHeader(value = "Authorization", required = false) String authorization,
      @RequestParam(name = "date_from", required = false) String dateFrom,
      @RequestParam(name = "date_to", required = false) String dateTo,
      @RequestParam(name = "filial_code", required = false) String filialCode) {

    Long userId = authorize(authorization);
    if (userId == null) {
      return api.unauthorized();
    }

    JSONObject params = new JSONObject();
    putIfPresent(params, "date_from", dateFrom);
    putIfPresent(params, "date_to", dateTo);
    putIfPresent(params, "filial_code", filialCode);
    return api.call("reportClients", params, userId);
  }

  //Cr By: Arslonbek Kulmatov
  //Qarzdorlik, filial va kun kesimida.
  //Davr berilmasa — oxirgi mavjud kun.
  @GetMapping(value = "/debt", produces = MediaType.APPLICATION_JSON_VALUE)
  public ResponseEntity<String> debt(
      @RequestHeader(value = "Authorization", required = false) String authorization,
      @RequestParam(name = "date_from", required = false) String dateFrom,
      @RequestParam(name = "date_to", required = false) String dateTo,
      @RequestParam(name = "filial_code", required = false) String filialCode) {

    Long userId = authorize(authorization);
    if (userId == null) {
      return api.unauthorized();
    }

    JSONObject params = new JSONObject();
    putIfPresent(params, "date_from", dateFrom);
    putIfPresent(params, "date_to", dateTo);
    putIfPresent(params, "filial_code", filialCode);
    return api.call("reportDebt", params, userId);
  }

  //Cr By: Arslonbek Kulmatov
  //Kechikkan sdelkalar ro'yxati
  @GetMapping(value = "/overdue", produces = MediaType.APPLICATION_JSON_VALUE)
  public ResponseEntity<String> overdue(
      @RequestHeader(value = "Authorization", required = false) String authorization,
      @RequestParam(name = "min_days", defaultValue = "1") int minDays,
      @RequestParam(name = "filial_code", required = false) String filialCode,
      @RequestParam(defaultValue = "1") int page,
      @RequestParam(name = "per_page", defaultValue = "200") int perPage) {

    Long userId = authorize(authorization);
    if (userId == null) {
      return api.unauthorized();
    }

    JSONObject params = new JSONObject();
    params.put("min_days", minDays);
    params.put("page", page);
    params.put("per_page", perPage);
    putIfPresent(params, "filial_code", filialCode);
    return api.call("reportOverdue", params, userId);
  }

  //Cr By: Arslonbek Kulmatov
  //Sdelkalar dinamikasi, davr bo'yicha
  @GetMapping(value = "/trades", produces = MediaType.APPLICATION_JSON_VALUE)
  public ResponseEntity<String> trades(
      @RequestHeader(value = "Authorization", required = false) String authorization,
      @RequestParam(name = "date_from", required = false) String dateFrom,
      @RequestParam(name = "date_to", required = false) String dateTo,
      @RequestParam(name = "filial_code", required = false) String filialCode) {

    Long userId = authorize(authorization);
    if (userId == null) {
      return api.unauthorized();
    }

    JSONObject params = new JSONObject();
    putIfPresent(params, "date_from", dateFrom);
    putIfPresent(params, "date_to", dateTo);
    putIfPresent(params, "filial_code", filialCode);
    return api.call("reportTrades", params, userId);
  }

  @ExceptionHandler(MethodArgumentTypeMismatchException.class)
  public ResponseEntity<String> badParam(MethodArgumentTypeMismatchException e) {
    return api.error(HttpStatus.BAD_REQUEST, "Invalid value for parameter '" + e.getName() + "'");
  }

  private Long authorize(String authorization) {
    return api.authenticate(authorization, SExternalApi.SCOPE_REPORT);
  }

  // Bo'sh parametr umuman yuborilmaydi — PL/SQL tomonda "kelmagan" va
  // "bo'sh kelgan" bir xil ishlov olishi uchun
  private void putIfPresent(JSONObject params, String key, String value) {
    if (value != null && !value.isBlank()) {
      params.put(key, value);
    }
  }
}
