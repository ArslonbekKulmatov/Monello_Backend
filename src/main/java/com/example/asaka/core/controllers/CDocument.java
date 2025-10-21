package com.example.asaka.core.controllers;

import com.example.asaka.core.services.SDocument;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/document")
@EnableAsync
public class CDocument {
  @Autowired
  private SDocument sDocument;

  @RequestMapping(value = "/generate-document", produces = "application/json")
  public String generateDocument(@RequestBody String params) {
    return sDocument.generateDocument(params);
  }
}
