package com.example.asaka.lnm.controllers;

import com.example.asaka.core.services.FilesStorageService;
import com.example.asaka.lnm.services.SLnm;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
public class CLnm {
    @Autowired private SLnm sLnm;
    @Autowired private FilesStorageService storageService;
    @RequestMapping(value = "/getFile", produces = "application/json")
    public String getFileBase64(@RequestBody String params) {
        return sLnm.getFileBase64(params);
    }

    @RequestMapping(value = "/gibridMail", produces = "application/json")
    public String gibridMail(@RequestBody String params) {
        return sLnm.sendAndInsertData(params);
    }

    //Cr By: Arslonbek Kulmatov
    //uploading files
    @RequestMapping(value = "/uploadFile", produces = "application/json")
    public String uploadFiles(@RequestParam("file") MultipartFile multipartFile) throws Exception {
        JSONObject response = new JSONObject();
        try {
//            storageService.save(multipartFile, "asaka");
            response.put("success", true);
        }
        catch (Exception e){
            response.put("success", false);
            response.put("error", e.getMessage());
        }
        return response.toString();
    }

    //Cr By: Arslonbek Kulmatov
    //delete files
    @RequestMapping(value = "/deleteFile", produces = "application/json")
    public String uploadFiles(@RequestBody String payload) throws Exception {
        JSONObject response = new JSONObject();
        JSONObject params = new JSONObject(payload);
        try {
            String file_name = params.getString("file_name");
            storageService.delete(file_name);
            response.put("success", true);
        }
        catch (Exception e){
            response.put("success", false);
            response.put("error", e.getMessage());
        }
        return response.toString();
    }
}
