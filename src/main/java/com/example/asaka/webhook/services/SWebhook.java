package com.example.asaka.webhook.services;

import com.example.asaka.util.DB;
import com.example.asaka.webhook.interfaces.WebhookService;
import com.example.asaka.webhook.models.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zaxxer.hikari.HikariDataSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.stereotype.Service;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Types;
import java.util.concurrent.CompletableFuture;

@Service
@EnableAsync
public class SWebhook implements WebhookService {
    @Override
    public CompletableFuture<Object> proccessWebhook(WebhookRequest request) {
        try {
            CallResponse call_response = proccess(request);

            if (call_response.getResponse_code() == 0) {
                return CompletableFuture.completedFuture(new SuccessResponse(call_response.getRequest_id(), call_response.getResponse_code(), call_response.getResponse_msg()));
            }
            else {
                return CompletableFuture.completedFuture(new ErrorResponse(call_response.getRequest_id(), call_response.getResponse_code(), call_response.getResponse_msg()));
            }
        } catch (Exception e) {
            return CompletableFuture.completedFuture(new ErrorResponse("0", -500, "Call procedure error: " + e.getMessage()));
        }
    }

    @Autowired
    private HikariDataSource hds;
    @Autowired private ObjectMapper objectMapper;
    public CallResponse proccess(WebhookRequest params) throws Exception {
        Connection conn = DB.con(hds);
        CallableStatement cs = null;
        CallResponse callResponse = new CallResponse();
        try {
            String jsonParams = objectMapper.writeValueAsString(params);
            cs = conn.prepareCall("{call Webhook.Send_Payment(?,?,?,?)}");
            cs.setString(1, jsonParams);
            cs.registerOutParameter(2, Types.INTEGER);
            cs.registerOutParameter(3, Types.NVARCHAR);
            cs.registerOutParameter(4, Types.VARCHAR);
            cs.execute();

            callResponse.setResponse_code(cs.getInt(2));
            callResponse.setResponse_msg(cs.getString(3));
            callResponse.setRequest_id(cs.getString(4));
        } catch (SQLException e) {
            throw new RuntimeException(e);
        } finally {
            DB.done(cs);
            DB.done(conn);
        }
        return callResponse;
    }

    @Override
    public CompletableFuture<Object> proccessWebhookV3(WebhookRequestIncard request) {
        try {
            CallResponse call_response = proccess_incard(request);

            if (call_response.getResponse_code() == 0) {
                return CompletableFuture.completedFuture(new SuccessResponse(call_response.getRequest_id(), call_response.getResponse_code(), call_response.getResponse_msg()));
            }
            else {
                return CompletableFuture.completedFuture(new ErrorResponse(call_response.getRequest_id(), call_response.getResponse_code(), call_response.getResponse_msg()));
            }
        } catch (Exception e) {
            return CompletableFuture.completedFuture(new ErrorResponse("0", -500, "Call procedure error: " + e.getMessage()));
        }
    }

    public CallResponse proccess_incard(WebhookRequestIncard params) throws Exception {
        Connection conn = DB.con(hds);
        CallableStatement cs = null;
        CallResponse callResponse = new CallResponse();
        try {
            String jsonParams = objectMapper.writeValueAsString(params);
            cs = conn.prepareCall("{call Webhook.Send_Payment_Incard(?,?,?,?)}");
            cs.setString(1, jsonParams);
            cs.registerOutParameter(2, Types.INTEGER);
            cs.registerOutParameter(3, Types.NVARCHAR);
            cs.registerOutParameter(4, Types.VARCHAR);
            cs.execute();

            callResponse.setResponse_code(cs.getInt(2));
            callResponse.setResponse_msg(cs.getString(3));
            callResponse.setRequest_id(cs.getString(4));
        } catch (SQLException e) {
            throw new RuntimeException(e);
        } finally {
            DB.done(cs);
            DB.done(conn);
        }
        return callResponse;
    }
}
