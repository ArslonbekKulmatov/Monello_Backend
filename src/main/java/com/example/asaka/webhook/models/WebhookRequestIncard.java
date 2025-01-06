package com.example.asaka.webhook.models;

import lombok.Data;

@Data
public class WebhookRequestIncard {
    private String jsonrpc;
    private String method;
    private String id;
    private Params params;

    @Data
    public static class Params {
        private String id;
        private Integer amount;
        private String autopayment_id;
        private String card;
        private String card_owner;
        private String contract;
        private String contract_id;
        private Integer status;
        private String payment_at;
        private String reversal_at;
        private boolean reversal;
    }
}
