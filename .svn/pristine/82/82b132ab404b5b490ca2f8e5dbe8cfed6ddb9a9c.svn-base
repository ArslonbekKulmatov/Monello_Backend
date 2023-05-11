package com.example.asaka.core.controllers;

import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.example.asaka.core.services.SEkey;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/ekey")
public class CEkey {

    @Autowired
    SEkey sEkey;

    //Cr By: Uzoqov Abror
    //Метод возвращает список идентификаторов всех пользователей документа PKCS#7
    @RequestMapping(value = "/signature/CBRUGetCmsUserIdList", produces = "application/json")
    private String CBRUGetCmsUserIdList(@RequestBody String payload) throws Exception {
        String response;
        JSONObject object = new JSONObject(payload);
        response = sEkey.CBRUGetCmsUserIdListStr(object);
        return response;
    }

    //Cr By: Uzoqov Abror
    //Метод проверяет контейнер PKCS#7
    @RequestMapping(value = "/signature/verifyCms", produces = "application/json")
    private String verifyCms(@RequestBody String payload) throws Exception {
        String response;
        JSONObject object = new JSONObject(payload);
        response = sEkey.verifyCms(object);
        return response;
    }

    //Cr By: Uzoqov Abror
    //Метод возвращает исходное содержимое PKCS#7 документа
    @RequestMapping(value = "/signature/GetCmsContent", produces = "application/json")
    private String GetCmsContent(@RequestBody String payload) throws Exception {
        String response;
        JSONObject object = new JSONObject(payload);
        response = sEkey.GetCmsContent(object);
        return response;
    }
}

