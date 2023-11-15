package com.example.asaka.telegram.services;

import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

@Service
public class STelegram {
    public String sendMessage(String message, String chat_id) {
        String token = "6526772524:AAGhbcXjpJtv-bUW46FyGw2L4jSJQtDyeMY";
        String url = String.format("https://api.telegram.org/bot%s/sendMessage", token);

        HttpHeaders headers = new HttpHeaders();
        headers.add("Content-Type", "application/json");

        String jsonBody = String.format("{\"chat_id\":\"%s\",\"text\":\"%s\",\"parse_mode\":\"HTML\"}", chat_id, message);

        HttpEntity<String> requestEntity = new HttpEntity<>(jsonBody, headers);

        RestTemplate restTemplate = new RestTemplate();
        ResponseEntity<String> response = restTemplate.exchange(url, HttpMethod.POST, requestEntity, String.class);

        return response.getBody();
    }
}
