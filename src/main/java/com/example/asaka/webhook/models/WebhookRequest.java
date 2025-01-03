package com.example.asaka.webhook.models;

import lombok.Data;

@Data
public class WebhookRequest {
    private int merchant_id;
    private String pinfl;
    private String loan_id;
    private String ext;
    private String rrn;
    private Card card;
    private String status;
    private String processing;
    private String date;
    private long amount;
    private String terminal;
    private String merchant;
    private boolean is_synced;
    private String push_id;
    private String created_at;

    @Data
    public static class Card {
        private String pan;
        private String owner;
        private String phone;
        private String token;
    }

}
