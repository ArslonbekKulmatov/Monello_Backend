package com.example.asaka.core.services;

import com.zaxxer.hikari.HikariDataSource;
import org.json.JSONException;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Service;
import com.example.asaka.security.services.UserDetailsImpl;
import com.example.asaka.util.DB;
import com.example.asaka.util.JbSql;

import java.sql.Connection;
import java.sql.Types;
import java.util.Calendar;

@Service
public class SUser {
    @Autowired HikariDataSource hds;

    public ResponseEntity notActive() {
        JSONObject res = new JSONObject();
        try {
            res.put("timestamp", Calendar.getInstance().getTime());
            res.put("message", "User is not active");
            res.put("error", "Unauthorized");
            res.put("status", "401");
            return new ResponseEntity<>(
                    res.toString(), HttpStatus.UNAUTHORIZED);
        } catch (JSONException e) {
            return new ResponseEntity<>(
                    res.toString(), HttpStatus.UNAUTHORIZED);
        }
    }

    public ResponseEntity getMsgEror(String message) {
        JSONObject res = new JSONObject();
        try {
            res.put("timestamp", Calendar.getInstance().getTime());
            res.put("message", message);
            res.put("error", "Unauthorized");
            res.put("status", "401");
            return new ResponseEntity<>(
                    res.toString(), HttpStatus.UNAUTHORIZED);
        } catch (JSONException e) {
            return new ResponseEntity<>(
                    res.toString(), HttpStatus.UNAUTHORIZED);
        }
    }

    public ResponseEntity jwtExpired(String message) {
        JSONObject res = new JSONObject();
        try {
            res.put("timestamp", Calendar.getInstance().getTime());
            res.put("message", message);
            res.put("error", "Forbidden");
            res.put("status", "403");
            return new ResponseEntity<>(
                    res.toString(), HttpStatus.FORBIDDEN);
        } catch (JSONException e) {
            return new ResponseEntity<>(
                    res.toString(), HttpStatus.FORBIDDEN);
        }
    }

}

