package com.example.asaka.webhook.models;

import lombok.Data;
import lombok.Getter;

@Getter
@Data
public class ErrorResponse {
    // Getters for ErrorResponse
    private String jsonrpc = "2.0";
    private String id;
    private ErrorDetails error;

    public ErrorResponse(String id, int code, String message) {
        this.id = id;
        this.error = new ErrorDetails(code, message);
    }

    @Getter
    public static class ErrorDetails {
        private int code;
        private String message;

        public ErrorDetails(int code, String message) {
            this.code = code;
            this.message = message;
        }

    }
}
