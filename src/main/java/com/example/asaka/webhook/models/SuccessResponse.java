package com.example.asaka.webhook.models;

import lombok.Data;
import lombok.Getter;

@Getter
@Data
public class SuccessResponse {
    // Getters for SuccessResponse
    private String jsonrpc = "2.0";
    private String id;
    private Result result;

    public SuccessResponse(String id, int code, String message) {
        this.id = id;
        this.result = new Result(code, message);
    }

    // Getters and Setters

    @Getter
    public static class Result {
        // Getters and Setters
        private int code;
        private String message;

        public Result(int code, String message) {
            this.code = code;
            this.message = message;
        }

    }

}
