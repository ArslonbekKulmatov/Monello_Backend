package com.example.asaka.webhook.interfaces;

import com.example.asaka.webhook.models.WebhookRequest;
import com.example.asaka.webhook.models.WebhookRequestIncard;

import java.util.concurrent.CompletableFuture;

public interface WebhookService {
    CompletableFuture<Object> proccessWebhook(WebhookRequest request);
    CompletableFuture<Object> proccessWebhookV3(WebhookRequestIncard request);
}
