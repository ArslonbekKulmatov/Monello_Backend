package com.example.asaka.telegram.controllers;

import com.example.asaka.telegram.services.STelegram;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/telegram/api")
public class CTelegram {
    @Autowired private STelegram telegramMessage;

    @RequestMapping(value = "/send-message", produces = "application/json")
    public String sendHtmlMessageToTelegramGroup(@RequestBody String params) {
        JSONObject json = new JSONObject(params);
        String chat_id = json.getString("chat_id");
        String message = json.getString("message");
        return telegramMessage.sendMessage(message, chat_id);
    }
}
