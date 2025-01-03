package com.example.asaka.webhook.models;

import lombok.Data;
import lombok.Getter;
import lombok.Setter;

@Setter
@Getter
@Data
public class CallResponse {
    private String request_id;
    private int response_code;
    private String response_msg;

    public CallResponse() {

    }

}
