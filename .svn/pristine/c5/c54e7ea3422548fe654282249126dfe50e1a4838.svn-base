package com.example.asaka.util;

import org.json.JSONException;
import org.json.JSONObject;
import org.springframework.core.io.ClassPathResource;
import org.springframework.util.FileCopyUtils;
//import org.springframework.util.ResourceUtils;

//import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
//import java.nio.file.Files;

public class JbUtil {

    public static String nvl(String str) {
        return str == null ? "" : str;
    }

    public static String nvl(String str, String defaultValue) {
        String returnStr = defaultValue;
        if (str != null && !str.equals(""))
            returnStr = str;
        return returnStr;
    }

    public static String getSeparatorForCurrentOS() {
        return isWindows() ? "\\" : "//";
    }

    public static boolean isWindows() {
        String os = System.getProperty("os.name").toLowerCase();
        //windows
        return (os.indexOf("win") >= 0);
    }

    public static JSONObject getJson(String path) {
//		File file = null;
        ClassPathResource cpr = new ClassPathResource(path + ".json");
        String data = "";
        try {
//			file = ResourceUtils.getFile(path + ".json");
            byte[] bdata = FileCopyUtils.copyToByteArray(cpr.getInputStream());
            data = new String(bdata, StandardCharsets.UTF_8);
//			String content = new String(Files.readAllBytes(file.toPath()));
            JSONObject json = new JSONObject(data);
            return json;
        } catch (FileNotFoundException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        } catch (JSONException e) {
            e.printStackTrace();
        }
        return null;
    }
}