package com.example.asaka.core.controllers;

/*
{
  Author: Saidazim,
  Cr_on: 30.10.2023,
  Purpose: Rest API for working with Hybrid Post
}
*/

import com.example.asaka.core.services.SHybridPost;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/hybrid")
public class CHybridPost {

  @Autowired
  SHybridPost sHybridPost;

  @RequestMapping(value = "/auth", produces = "application/json")
  public String hybridPostAuth() {
    return sHybridPost.auth();
  }

  @RequestMapping(value = "/create-mail", produces = "application/json")
  public String createMail(@RequestBody String params) {
    JSONObject result = new JSONObject(sHybridPost.checkCreatingMail(params));
    if (result.getBoolean("success")) {
      return sHybridPost.createMail(params);
    }
    return result.toString();
  }

  @RequestMapping(value = "/send-mail", produces = "application/json")
  public String sendMail(@RequestBody String params) {
    String result = sHybridPost.checkSendingMail(params);
    if (result != null) {
      return sHybridPost.sendMail(params);
    }
    return null;
  }
}

