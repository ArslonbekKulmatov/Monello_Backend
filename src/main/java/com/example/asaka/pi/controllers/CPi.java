package com.example.asaka.pi.controllers;

import com.example.asaka.pi.services.SPi;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/pi")
public class CPi {
    @Autowired private SPi sPi;
    @RequestMapping(value = "/open_file", produces = "application/json")
    public String getFileBase64(@RequestBody String params) {
        return sPi.getFileBase64(params);
    }

    @RequestMapping(value = "/sendRequest", produces = "application/json")
    public String sendRequest(@RequestBody String params) {
        JSONObject req = new JSONObject(params);
        return sPi.sendRequest(req);
    }
}
