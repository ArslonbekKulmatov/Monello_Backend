package com.example.asaka.pi.controllers;

import com.example.asaka.pi.services.SPiReport;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.io.IOException;
import java.io.InputStream;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/pi/report")
public class CPiReport {
    @Autowired private SPiReport sPiReport;

    @RequestMapping(value = "/accounting", produces = "application/json")
    public String accountingReport(@RequestBody String params) {
        return sPiReport.accountingReport(params);
    }
}
