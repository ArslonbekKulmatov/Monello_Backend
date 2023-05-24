package com.example.asaka.pi.controllers;

import com.example.asaka.pi.services.SPiReport;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.InputStreamResource;
import org.springframework.http.ResponseEntity;
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

    //Cr By: Arslonbek Kulmatov
    //accounting report in excel
    @RequestMapping("/excel/accounting_report")
    public ResponseEntity<InputStreamResource> accountingReportExcel(@RequestBody String params) {
        return sPiReport.accountingReportExcel(params);
    }
}
