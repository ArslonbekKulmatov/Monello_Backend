package com.example.asaka.al.controllers;

import com.example.asaka.al.services.SAl;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/al")
public class CAl {
    //Cr By: Arslonbek Kulmatov
    //Getting images by id
    @Autowired private SAl sAl;

    @RequestMapping(value = "/getImage", produces = "application/json")
    public String getImageBase64(@RequestBody String params) {
        return sAl.getImageBase64(params);
    }

    //Cr By: Arslonbek Kulmatov
    //Getting user projects
    @RequestMapping(value = "/getUserProjects", produces = "application/json")
    public String getUserProjectsWithImage(@RequestBody String params) throws Exception {
        return sAl.getUserProjectsWithImage(params);
    }

    //Cr By: Arslonbek Kulmatov
    //Getting project buildings
    @RequestMapping(value = "/getProjectBuildings", produces = "application/json")
    public String getProjectBuildings(@RequestBody String params) {
        return sAl.getProjectBuildings(params);
    }

    //Cr By: Arslonbek Kulmatov
    //Getting building floors
    @RequestMapping(value = "/getBuildingFloors", produces = "application/json")
    public String getBuildingFloors(@RequestBody String params) {
        return sAl.getBuildingFloors(params);
    }

    //Cr By: Arslonbek Kulmatov
    //Getting building rooms
    @RequestMapping(value = "/getBuildingRooms", produces = "application/json")
    public String getBuildingRooms(@RequestBody String params) {
        return sAl.getBuildingRooms(params);
    }

}
