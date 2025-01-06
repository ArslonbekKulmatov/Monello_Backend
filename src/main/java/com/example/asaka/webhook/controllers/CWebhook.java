package com.example.asaka.webhook.controllers;

import com.example.asaka.webhook.interfaces.WebhookService;
import com.example.asaka.webhook.models.ErrorResponse;
import com.example.asaka.webhook.models.SuccessResponse;
import com.example.asaka.webhook.models.WebhookRequest;
import com.example.asaka.webhook.models.WebhookRequestIncard;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.concurrent.CompletableFuture;

@RequestMapping("/api/send-payment")
@RestController
public class CWebhook {
    private final WebhookService webhookService;

    public CWebhook(WebhookService webhookService) {
        this.webhookService = webhookService;
    }

    @RequestMapping(value = "/v2", produces = "application/json")
    public CompletableFuture<ResponseEntity<?>> proccessWebhookV2(@RequestBody WebhookRequest request) {
        return webhookService.proccessWebhook(request)
                .thenApply(ResponseEntity::ok);
    }

    @RequestMapping(value = "/v1", produces = "application/json")
    public CompletableFuture<ResponseEntity<?>> proccessWebhook(@RequestBody WebhookRequest request) {
        return webhookService.proccessWebhook(request)
                .thenApply(response -> {
                    if (response instanceof SuccessResponse) {
                        return new ResponseEntity<>(response, HttpStatus.OK);
                    } else {
                        return new ResponseEntity<>(new ErrorResponse("0", -500, "Unknown error"), HttpStatus.INTERNAL_SERVER_ERROR);
                    }
                });
    }

    @RequestMapping(value = "/v3", produces = "application/json")
    public CompletableFuture<ResponseEntity<?>> proccessWebhookV3(@RequestBody WebhookRequestIncard request) {
        return webhookService.proccessWebhookV3(request)
                .thenApply(response -> {
                    if (response instanceof SuccessResponse) {
                        return new ResponseEntity<>(response, HttpStatus.OK);
                    } else {
                        return new ResponseEntity<>(new ErrorResponse("0", -500, "Unknown error"), HttpStatus.INTERNAL_SERVER_ERROR);
                    }
                });
    }
}
