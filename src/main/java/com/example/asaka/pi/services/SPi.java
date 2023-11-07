package com.example.asaka.pi.services;

import com.example.asaka.util.DB;
import com.zaxxer.hikari.HikariDataSource;
import org.apache.http.HttpException;
import org.apache.http.HttpHost;
import org.apache.http.HttpRequest;
import org.apache.http.conn.ssl.NoopHostnameVerifier;
import org.apache.http.conn.ssl.SSLConnectionSocketFactory;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClients;
import org.apache.http.impl.conn.DefaultProxyRoutePlanner;
import org.apache.http.protocol.HttpContext;
import org.apache.http.ssl.SSLContexts;
import org.apache.tomcat.util.codec.binary.Base64;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.http.client.HttpComponentsClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.HttpStatusCodeException;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import javax.net.ssl.SSLContext;
import java.io.UnsupportedEncodingException;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.HashMap;
import java.util.Map;

import static com.example.asaka.util.JbUtil.nvl;

@Service
public class SPi {
    @Autowired HikariDataSource hds;

    //Cr By: Arslonbek Kulmatov
    public String getFileBase64(String params) throws JSONException {
        JSONObject json_params = new JSONObject(params);
        JSONObject response = new JSONObject();
        String encodedString;
        String file_name;

        Connection conn = null;
        PreparedStatement ps = null;
        ResultSet res = null;
        try {
            conn = DB.con(hds);
            int cover_id = json_params.getInt("cover_id");
            ps = conn.prepareStatement("select file_name, file_url from PI_COURT_REGRESSES where cover_id = " + cover_id);
            res = ps.executeQuery();
            if (res.next()) {
                String url = nvl(res.getString("file_url"), "");
                file_name = res.getString("file_name");
                Path file = Paths.get(url);
                Resource resource = new UrlResource(file.toUri());
                byte[] fileContent = resource.getInputStream().readAllBytes();
                encodedString= Base64.encodeBase64String(fileContent);
                response.put("success", true);
                response.put("encoded_file", encodedString);
                response.put("file_name", file_name);
                response.put("file_url", url);
                return  response.toString();
            }
            else {
                response.put("success", false);
                response.put("error", "No file entered.");
            }
        } catch (Exception e) {
            response.put("success", false);
            response.put("error", e.getMessage());
            e.printStackTrace();
        } finally {
            DB.done(ps);
            DB.done(res);
            DB.done(conn);
        }
        return  response.toString();
    }

    //Cr By: Arslonbek Kulmatov
    public String sendRequest(JSONObject req) throws JSONException {
        JSONObject response = new JSONObject();
        ResponseEntity<String> resEntity;
        HttpEntity<String> entity;
        try {
            String request_type = req.getString("request_type");
            String url = req.getString("url");
            String set_proxy = req.getString("set_proxy");
            String type = req.getString("type");
            String proxy_ip = req.getString("proxy_ip");
            Integer proxy_port = req.getInt("proxy_port");
            JSONObject params = req.getJSONObject("params");
            String resp_type = req.getString("response_type");
            Map<String, Object> paramMap = new HashMap<>();
            if (request_type.equals("GET")){
                paramMap.put(params.getString("name"), params.getString("value"));
            }
            else if(request_type.equals("DELETE")){
                paramMap.put(params.getString("name"), params.getString("value"));
            }

            RestTemplate rt;
            String token;
            HttpHeaders headers = new HttpHeaders();
            headers.add("Content-type", "application/json; charset=utf-8");

            if (set_proxy.equals("Y") && type.equals("https")){
                HttpHost proxy = new HttpHost(proxy_ip, proxy_port);
                HttpComponentsClientHttpRequestFactory requestFactory = new HttpComponentsClientHttpRequestFactory();
                SSLContext sslcontext = SSLContexts.custom() .loadTrustMaterial(null, (chain, authType) -> true).build();
                SSLConnectionSocketFactory sslsf = new SSLConnectionSocketFactory(sslcontext, new String[]{"TLSv1", "TLSv1.2", "TLSv1.3"}, null, new NoopHostnameVerifier());
                CloseableHttpClient httpClient = HttpClients.custom()
                        .setSSLSocketFactory(sslsf)
                        .setRoutePlanner(new DefaultProxyRoutePlanner(proxy) {
                            @Override
                            public HttpHost determineProxy(HttpHost target, HttpRequest request, HttpContext context) throws HttpException {
                                return super.determineProxy(target, request, context);
                            }
                        })
                        .build();
                requestFactory.setHttpClient(httpClient);
                rt = new RestTemplate(requestFactory);
            }
            else if (set_proxy.equals("Y") && type.equals("http")){
                HttpHost proxy = new HttpHost(proxy_ip, proxy_port);
                HttpComponentsClientHttpRequestFactory requestFactory = new HttpComponentsClientHttpRequestFactory();
                CloseableHttpClient httpClient = HttpClients.custom()
                        .setRoutePlanner(new DefaultProxyRoutePlanner(proxy) {
                            @Override
                            public HttpHost determineProxy(HttpHost target, HttpRequest request, HttpContext context) throws HttpException {
                                return super.determineProxy(target, request, context);
                            }
                        })
                        .build();
                requestFactory.setHttpClient(httpClient);
                rt = new RestTemplate(requestFactory);
            }
            else {
                rt = new RestTemplate();
            }


            if (request_type.equals("DELETE")){
                entity = new HttpEntity<>(null, headers);
                resEntity = rt.exchange(url, HttpMethod.DELETE, entity, String.class, paramMap);
            }
            else if(request_type.equals("GET")){
                entity = new HttpEntity<>(null, headers);
                paramMap.clear();
                UriComponentsBuilder builder = UriComponentsBuilder.fromHttpUrl(url);
                for (int i=0; i<params.names().length(); ++i){
                    String key = params.names().getString(i);
                    String value = params.getString(key);
                    builder.queryParam(key, value);
                    paramMap.put(key, value);
                }
                resEntity = rt.exchange(builder.toUriString(), HttpMethod.GET, entity, String.class, paramMap);
            }
            else if(request_type.equals("PUT")){
                entity = new HttpEntity<>(params.toString(), headers);
                resEntity = rt.exchange(url, HttpMethod.PUT, entity, String.class);
            }
            else {
                entity = new HttpEntity<>(params.toString(), headers);
                resEntity = rt.exchange(url, HttpMethod.POST, entity, String.class);
            }
            if (resp_type.equals("array")){
                JSONArray jsonArray = new JSONArray(resEntity.getBody());
                response.put("responseArray", jsonArray);
            }
            else{
                response = new JSONObject(resEntity.getBody());
            }

            response.put("success", true);
        } catch (HttpStatusCodeException ex) {
            ex.printStackTrace();
            response.put("success", false);
            response.put("error", ex.getMessage());
        } catch (Exception e) {
            e.printStackTrace();
            response.put("success", false);
            response.put("error",  e.getMessage());
        }

        return response.toString();
    }
}
