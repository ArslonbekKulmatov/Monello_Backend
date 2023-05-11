package com.example.asaka.core.controllers;

import org.json.JSONException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import com.example.asaka.core.models.Grid;
import com.example.asaka.core.services.SGrid;

import java.sql.SQLException;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/user")
public class CUser {

    @Autowired
    SGrid sGrid;

    @GetMapping("/list")
    @PreAuthorize("hasRole('ROLE_USER')")
    public ResponseEntity<?> userList(@RequestBody String params) throws JSONException, SQLException {
        return ResponseEntity.ok(new Grid(sGrid.grid(params).toString(), null));
    }

    @PostMapping("/saveRoles")
    @PreAuthorize("hasRole('ROLE_USER')")
    public ResponseEntity<?> saveRoles(@RequestBody String params) throws JSONException, SQLException {
        return ResponseEntity.ok(new Grid(sGrid.grid(params).toString(), null));
    }

}


