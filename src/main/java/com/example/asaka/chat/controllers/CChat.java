package com.example.asaka.chat.controllers;

import com.example.asaka.chat.services.SChat;
import lombok.extern.slf4j.Slf4j;
import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

//Cr By: Arslonbek Kulmatov
//Monello web'dagi chat formasi.
//
//Odatdagi ichki endpoint: JWT bilan ishlaydi va sessiya filialini hisobga
//oladi — tool'lar shu sababli foydalanuvchining o'z filialini ko'rsatadi.
@Slf4j
@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/chat")
public class CChat {

  @Autowired private SChat sChat;

  //Cr By: Arslonbek Kulmatov
  //Savol berish.
  //
  //  { "question": "Kim eng ko'p kechikkan?",
  //    "history": [ {"role":"user","text":"..."}, {"role":"assistant","text":"..."} ] }
  @PostMapping(produces = MediaType.APPLICATION_JSON_VALUE)
  public ResponseEntity<String> ask(@RequestBody String body) {
    JSONObject in;
    try {
      in = new JSONObject(body);
    } catch (Exception e) {
      return ResponseEntity.badRequest()
          .body(new JSONObject().put("ok", false).put("error", "JSON noto'g'ri.").toString());
    }
    JSONArray history = in.optJSONArray("history");
    JSONObject result = sChat.ask(in.optString("question", ""), history);
    return ResponseEntity.ok(result.toString());
  }

  //Cr By: Arslonbek Kulmatov
  //Chat sozlanganmi — forma buni ochilishda so'raydi va sozlanmagan bo'lsa
  //kirish maydonini o'chiradi
  @GetMapping(value = "/status", produces = MediaType.APPLICATION_JSON_VALUE)
  public ResponseEntity<String> status() {
    return ResponseEntity.ok(
        new JSONObject().put("enabled", sChat.isEnabled()).toString());
  }
}
