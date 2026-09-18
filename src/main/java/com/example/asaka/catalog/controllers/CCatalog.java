package com.example.asaka.catalog.controllers;

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
//ABM Store sayti uchun katalog API.
//Avtorizatsiya doimiy token bilan, JWT emas — qamrovi "catalog".
@Slf4j
@RestController
@RequestMapping("/api/catalog")
public class CCatalog {

  @Autowired private SExternalApi api;

  //Cr By: Arslonbek Kulmatov
  //To'liq katalog, sahifalab
  @GetMapping(value = "/products", produces = MediaType.APPLICATION_JSON_VALUE)
  public ResponseEntity<String> products(
      @RequestHeader(value = "Authorization", required = false) String authorization,
      @RequestParam(defaultValue = "1") int page,
      @RequestParam(name = "per_page", defaultValue = "200") int perPage,
      @RequestParam(name = "updated_since", required = false) String updatedSince) {

    Long userId = api.authenticate(authorization, SExternalApi.SCOPE_CATALOG);
    if (userId == null) {
      return api.unauthorized();
    }

    JSONObject params = new JSONObject();
    params.put("page", page);
    params.put("per_page", perPage);
    if (updatedSince != null && !updatedSince.isBlank()) {
      params.put("updated_since", updatedSince);
    }
    return api.call("catalogProducts", params, userId);
  }

  //Cr By: Arslonbek Kulmatov
  //Faqat narx va qoldiq
  @GetMapping(value = "/stock", produces = MediaType.APPLICATION_JSON_VALUE)
  public ResponseEntity<String> stock(
      @RequestHeader(value = "Authorization", required = false) String authorization) {

    Long userId = api.authenticate(authorization, SExternalApi.SCOPE_CATALOG);
    if (userId == null) {
      return api.unauthorized();
    }
    return api.call("catalogStock", new JSONObject(), userId);
  }

  // page=abc kabi noto'g'ri parametrlar 500 emas, 400 qaytarishi kerak
  @ExceptionHandler(MethodArgumentTypeMismatchException.class)
  public ResponseEntity<String> badParam(MethodArgumentTypeMismatchException e) {
    return api.error(HttpStatus.BAD_REQUEST, "Invalid value for parameter '" + e.getName() + "'");
  }
}
