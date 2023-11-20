package com.example.asaka.util;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.json.JSONException;
import org.json.JSONObject;
import org.springframework.core.io.ClassPathResource;
import org.springframework.http.HttpMethod;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.util.FileCopyUtils;
import org.springframework.web.client.RestTemplate;

import java.io.FileNotFoundException;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.Proxy;
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

  public static String jsonStringMapper(String jsonString) throws JsonProcessingException {
    ObjectMapper objectMapper = new ObjectMapper();
    JsonNode jsonNode = objectMapper.readTree(jsonString);
    ObjectNode object = (ObjectNode) jsonNode;
    return objectMapper.writeValueAsString(object);
  }

  public static HttpMethod getMethodType(String methodType) {
    return switch (methodType) {
      case "PUT" -> HttpMethod.PUT;
      case "GET" -> HttpMethod.GET;
      case "DELETE" -> HttpMethod.DELETE;
      default -> HttpMethod.POST;
    };
  }

  public static boolean isValidJson(String json) {
    try {
      new JSONObject(json);
    } catch (JSONException e) {
      return false;
    }
    return true;
  }

  public static String removeDoubleQuote(String text) {
    if (text != null) {
      return text.replace("\"", "");
    } else {
      return null;
    }
  }

  public static RestTemplate getRestTemplate(boolean isProxy, String ip, int port) {
    RestTemplate restTemplate;
    if (isProxy) {
      Proxy proxy = new Proxy(Proxy.Type.HTTP, new InetSocketAddress(ip, port));
      SimpleClientHttpRequestFactory requestFactory = new SimpleClientHttpRequestFactory();
      requestFactory.setProxy(proxy);
      restTemplate = new RestTemplate(requestFactory);
    } else {
      restTemplate = new RestTemplate();
    }
    return restTemplate;
  }
}