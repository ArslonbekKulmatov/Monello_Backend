package com.example.asaka.core.services;

import com.example.asaka.security.jwt.JwtUtils;
import com.example.asaka.security.services.UserDetailsServiceImpl;
import com.example.asaka.util.DB;
import com.example.asaka.util.ExcMsg;
import com.example.asaka.util.JbSql;
import com.example.asaka.util.Req;
import com.zaxxer.hikari.HikariDataSource;
import io.jsonwebtoken.Claims;
import lombok.extern.slf4j.Slf4j;
import oracle.jdbc.OracleConnection;
import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.client.HttpStatusCodeException;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.util.UriComponentsBuilder;

import java.nio.file.Path;
import java.nio.file.Paths;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Types;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;

import static com.example.asaka.util.JbUtil.*;

@Slf4j
@Service
@EnableAsync
public class SApp {

  @Autowired HikariDataSource hds;
  @Autowired PasswordEncoder encoder;
  @Autowired JwtUtils jwtUtils;
  @Autowired Req req;
  @Autowired UserDetailsServiceImpl userDetailsService;
  @Autowired AuthenticationManager authenticationManager;
  @Value("${jwt.expirationMs}") Integer jwtExpirationMs;
  @Autowired private FilesStorageService storageService;

  public String post(String params, Boolean use_session) throws Exception {
    Connection conn = DB.con(hds);
    JSONObject pars = new JSONObject(params);
    String method = pars.getString("method");
    JbSql sql;
    JSONObject res = new JSONObject();
    res.put("success", true);
    try {
      if (use_session) {
        setDbSession(conn);
      }
      sql = new JbSql("Core_App.Set_Method", conn, false);
      sql.addParam(params, 1);
      sql.addOut(Types.CLOB, 2);
      sql.exec();
      boolean isOper;
      String outAddStr = (String) sql.getOutVal(2);
      if (outAddStr != null) {
        JSONObject outObj = new JSONObject(outAddStr);
        isOper = outObj.has("oper") && !outObj.isNull("oper") && outObj.getBoolean("oper");
        String message = outObj.has("message") && !outObj.isNull("message") ? outObj.getString("message") : "";
        if (outObj.has("message") && !outObj.isNull("message")) {
          res.put("message", message);
        }
        // Agar operatsiyaligini bildiruvchi qiymati bo'lmasa
        if (outObj.has("oper") && !outObj.isNull("oper")) {
          res.put("oper", isOper);
        }
        outObj.remove("oper");
        outObj.remove("message");
        res.put("data", outObj);
      }

    } catch (Exception e) {
      ExcMsg.call(res, e, conn);
    } finally {
      DB.done(conn);
    }
    return res.toString();
  }

  public String wtpost(String params) throws Exception {
    Connection conn = DB.con(hds);
    JbSql sql;
    JSONObject res = new JSONObject();
    res.put("success", true);
    try {
      sql = new JbSql("Core_App.Set_Method", conn, false);
      sql.addParam(params, 1);
      sql.addOut(Types.CLOB, 2);
      sql.exec();
      boolean isOper;
      String outAddStr = (String) sql.getOutVal(2);
      if (outAddStr != null) {
        JSONObject outObj = new JSONObject(outAddStr);
        isOper = outObj.has("oper") && !outObj.isNull("oper") && outObj.getBoolean("oper");
        String message = outObj.has("message") && !outObj.isNull("message") ? outObj.getString("message") : "";
        if (outObj.has("message") && !outObj.isNull("message")) {
          res.put("message", message);
        }
        // Agar operatsiyaligini bildiruvchi qiymati bo'lmasa
        if (outObj.has("oper") && !outObj.isNull("oper")) {
          res.put("oper", isOper);
        }
        outObj.remove("oper");
        outObj.remove("message");
        res.put("data", outObj);
      }

    } catch (Exception e) {
      ExcMsg.call(res, e, conn);
    } finally {
      DB.done(conn);
    }
    return res.toString();
  }

  public String postFile(String params, MultipartFile multipartFile) throws Exception {
    JSONObject pars = new JSONObject(params);
    String method = pars.getString("method");
    JSONObject upload_params = null;
    Path root = Paths.get("");
    Connection conn = DB.con(hds);
    JbSql sql;
    JSONObject res = new JSONObject();
    String outAddStr;
    res.put("success", true);
    res.put("message", "");
    if (multipartFile != null) {
      upload_params = getMethodParamValue(method, "file_upload_type");
      pars.put("fileName", multipartFile.getOriginalFilename());
      pars.put("fileType", multipartFile.getContentType());
      String file_extension = storageService.getExtensionByStringHandling(multipartFile.getOriginalFilename()).get();
      if (upload_params.has("root")) {
        root = Paths.get(upload_params.getString("root"));
        pars.put("root", root);
      }
      pars.put("fileExtension", file_extension);
    }
    params = pars.toString();
    try {
      setDbSession(conn, pars);
      if (multipartFile != null) {
        sql = new JbSql("Core_App.Set_Method_File", conn, false);
      } else {
        sql = new JbSql("Core_App.Set_Method", conn, false);
      }
      sql.addParam(params, 1);
      if (multipartFile != null) {
        sql.addParam(multipartFile.getInputStream(), 2);
        sql.addOut(Types.VARCHAR, 3);
      } else {
        sql.addOut(Types.VARCHAR, 2);
      }

      sql.exec();
      if (multipartFile != null) {
        outAddStr = (String) sql.getOutVal(3);
      } else {
        outAddStr = (String) sql.getOutVal(2);
      }

      JSONObject outObj = new JSONObject(outAddStr);
      boolean isOper = outObj.getBoolean("oper");
      String message;
      message = isOper ? outObj.getString("message") : "";

      if (multipartFile != null) {
        if (upload_params.has("type")) {
          String type = upload_params.getString("type");

          if (type.equals("SERVER_INSERT") && isOper) {
            String file_name = outObj.getString("file_name");
            storageService.save(multipartFile, file_name, root);
          } else if (type.equals("SERVER_UPDATE") && isOper) {
            String file_name = outObj.getString("file_name");
            Path path = root.resolve(file_name);
            storageService.delete(path.toString());
            storageService.save(multipartFile, file_name, root);
          }
        }
      }

      outObj.remove("oper");
      outObj.remove("message");
      res.put("data", outObj);
      res.put("message", message);
      res.put("oper", isOper);
    } catch (Exception e) {
      ExcMsg.call(res, e, conn);
    } finally {
      DB.done(conn);
    }
    return res.toString();
  }

  public String execSelect(String params) throws Exception {
    Connection conn = DB.con(hds);
    JSONObject res = new JSONObject();
    try {
      setDbSession(conn);
      JSONObject json = new JSONObject(params);
      // json.getString("wh")
      JSONArray rows = JbSql.rsToJson("Select * From " + json.getString("view")
          + (json.isNull("wh") ? "" : " Where " + json.getString("wh")), conn);
      res.put("rows", rows);
      res.put("success", true);
    } catch (Exception e) {
      ExcMsg.call(res, e, conn);
    } finally {
      DB.done(conn);
    }
    return res.toString();
  }

  public String signUp(String params) throws Exception {
    JSONObject jo = new JSONObject(params);
    JSONObject res = new JSONObject();
    Connection conn = DB.con(hds);
    JbSql sql;
    String method = jo.getString("method");
    res.put("success", true);
    try {
      if (method.equals("userReg")) {
        sql = new JbSql("Core_User.User_Reg", conn, true);
        sql.addParam(params, 2);
        sql.addParam(encoder.encode(jo.getString("password").replace("\"", "")), 3);
        sql.exec();
        //
        JSONObject obj = new JSONObject(params);
        Authentication authentication = authenticationManager.authenticate(
            new UsernamePasswordAuthenticationToken(obj.getString("login"), obj.getString("password")));
        SecurityContextHolder.getContext().setAuthentication(authentication);
        String jwt = jwtUtils.generateJwtToken(authentication);
        res.put("userId", sql.getResult());
        res.put("jwt", jwt);
        res.put("expiresIn", jwtExpirationMs.toString());
        res.put("firstName", obj.getString("firstName"));
        res.put("lastName", obj.getString("lastName"));
        res.put("patronymicName", obj.getString("patronymicName"));
      } else {
        sql = new JbSql("Core_App.Set_Method", conn, false);
        sql.addParam(params, 1);
        sql.addOut(Types.VARCHAR, 2);
        sql.exec();
      }
    } catch (Exception e) {
      ExcMsg.call(res, e, conn);
    } finally {
      DB.done(conn);
    }
    return res.toString();
  }

  public String addEditUser(String params) throws Exception {
    JSONObject jo = new JSONObject(params);
    JSONObject res = new JSONObject();
    res.put("success", true);
    Connection conn = DB.con(hds);
    JbSql sql;
    setDbSession(conn);
    try {
      sql = new JbSql("Core_User.Add_Edit_User", conn, false);
      sql.addParam(params, 1);
      sql.addParam(encoder.encode(jo.getString("password")), 2);
      //sql.addParam(jo.getString("phoneNum"), 3);
      //sql.addParam("forgotPassword", 4);
      sql.exec();
      res.put("message", "successSave");
    } catch (Exception e) {
      ExcMsg.call(res, e, conn);
    } finally {
      DB.done(conn);
    }
    return res.toString();
  }

  public String updatePassword(String params) throws Exception {
    JSONObject jo = new JSONObject(params);
    JSONObject res = new JSONObject();
    res.put("success", true);
    Connection conn = DB.con(hds);
    JbSql sql;
    setDbSession(conn);
    try {
      sql = new JbSql("Core_User.Edit_User_Password", conn, false);
      sql.addParam(params, 1);
      sql.addParam(encoder.encode(jo.getString("password")), 2);
      sql.addParam(jo.getString("phoneNum"), 3);
      sql.addParam("forgotPassword", 4);
      sql.exec();
      res.put("message", "successSave");
    } catch (Exception e) {
      ExcMsg.call(res, e, conn);
    } finally {
      DB.done(conn);
    }
    return res.toString();
  }

  public String confirmCode(String params) throws Exception {
    JSONObject jo = new JSONObject(params);
    JSONObject res = new JSONObject();
    Connection conn = DB.con(hds);
    JbSql sql;
    String method = jo.getString("method");
    res.put("success", true);
    try {
      if (method.equals("sendConfirmCode")) {
        sql = new JbSql("Core_User.Send_Conf_Code", conn, false);
        sql.addParam(params, 1);
        sql.exec();
      } else if (method.equals("checkConfirmCode")) {
        sql = new JbSql("Core_User.Check_Confirm_Code", conn, false);
        sql.addParam(params, 1);
        sql.addOut(Types.CLOB, 2);
        sql.exec();
        boolean isOper;
        String outAddStr = (String) sql.getOutVal(2);
        if (outAddStr != null) {
          JSONObject outObj = new JSONObject(outAddStr);
          isOper = outObj.has("oper") && !outObj.isNull("oper") && outObj.getBoolean("oper");
          String message = outObj.has("message") && !outObj.isNull("message") ? outObj.getString("message") : "";
          if (outObj.has("message") && !outObj.isNull("message")) {
            res.put("message", message);
          }
          if (outObj.has("oper") && !outObj.isNull("oper")) {
            res.put("oper", isOper);
          }
          outObj.remove("oper");
          outObj.remove("message");
          res.put("data", outObj);
        }
      }
    } catch (Exception e) {
      ExcMsg.call(res, e, conn);
    } finally {
      DB.done(conn);
    }
    return res.toString();
  }

  public void setDbSession(Connection connection) throws Exception {
    String headerAuth = req.getHeader("Authorization");
    if (StringUtils.hasText(headerAuth) && headerAuth.startsWith("Bearer ")) {
      headerAuth = headerAuth.substring(7);
    }
    Claims claims = jwtUtils.getAllClaimsFromToken(headerAuth);
    if (claims == null) {
      throw new HttpStatusCodeException(HttpStatus.FORBIDDEN) {
        @Override
        public HttpStatus getStatusCode() {
          return super.getStatusCode();
        }
      };
    }
    OracleConnection conn = connection.unwrap(OracleConnection.class);
    JbSql form = new JbSql("Core_Session.Set_User_Session", conn, false);
    String userId = claims.get("userId").toString();
    String lang = nvl(req.getHeader("lang"), "ru");
    String filialCode = claims.get("filialCode") != null ? claims.get("filialCode").toString() : null;
    try {
      form.addParam(userId, 1);
      form.addParam(filialCode, 2);

      form.addParam(lang, 3);
      form.exec();
    } catch (Exception e) {
      e.printStackTrace();
    }
  }

  public void setDbSession(Connection connection, JSONObject json) throws Exception {
    String headerAuth = req.getHeader("Authorization");
    if (StringUtils.hasText(headerAuth) && headerAuth.startsWith("Bearer ")) {
      headerAuth = headerAuth.substring(7);
    }
    Claims claims = jwtUtils.getAllClaimsFromToken(headerAuth);
    if (claims == null) {
      throw new HttpStatusCodeException(HttpStatus.FORBIDDEN) {
        @Override
        public HttpStatus getStatusCode() {
          return super.getStatusCode();
        }
      };
    }
    OracleConnection conn = connection.unwrap(OracleConnection.class);
    JbSql form = new JbSql("Core_Session.Set_User_Session", conn, false);
    String userId = claims.get("userId").toString();
    String filialCode = json.isNull("filialCode") ? null : json.getString("filialCode");
    String lang = nvl(req.getHeader("lang"), "");
    try {
      boolean hasFilial = false;
      form.addParam(userId, 1);
      if (filialCode != null && !"".equals(filialCode)) {
        form.addParam(filialCode, 2);
        hasFilial = true;
      }
      if (!lang.equals(""))
        form.addParam(lang, hasFilial ? 3 : 2);
      form.exec();
    } catch (Exception e) {
      e.printStackTrace();
    }
  }

  public void setCustomDbSession(Connection connection, JSONObject json) throws Exception {
    OracleConnection conn = connection.unwrap(OracleConnection.class);
    JSONArray customSessions = json.isNull("c") ? null : json.getJSONArray("cSns"); // customSessions
    if (customSessions != null) {
      try {
        for (int n = 0; n < customSessions.length(); n++) {
          JSONObject obj = customSessions.getJSONObject(n);
          String contextName = obj.getString("contextName");
          String value = obj.getString("value");
          DB.ps(conn, "Begin Core_Session.Set_Context('" + contextName + "', '" + value + "'); End;");
        }
      } catch (Exception e) {
        e.printStackTrace();
      }
    }
  }

  public void loginLog(Long iuserId) throws Exception {
    Connection conn = DB.con(hds);
    JbSql form = new JbSql("Core_user.create_login", conn, false);
    String userId = iuserId.toString();
    try {
      form.addParam(userId, 1);
      form.exec();
    } catch (Exception e) {
      e.printStackTrace();
    } finally {
      DB.done(conn);
    }
  }

  public void logOutLog() {
    String headerAuth = req.getHeader("Authorization");
    if (StringUtils.hasText(headerAuth) && headerAuth.startsWith("Bearer ")) {
      headerAuth = headerAuth.substring(7);
    }
    Claims claims = jwtUtils.getAllClaimsFromToken(headerAuth);
    Authentication authentication = authenticationManager.authenticate(
        new UsernamePasswordAuthenticationToken(claims.get("login").toString(), claims.get("password").toString()));
    SecurityContextHolder.getContext().setAuthentication(authentication);
  }

  //Cr By: Arslonbek Kulmatov
  //Get method param values
  public JSONObject getMethodParamValue(String method_name, String column_name) {
    Connection conn = null;
    PreparedStatement ps = null;
    ResultSet res = null;
    String result = "{}";
    JSONObject response;
    try {
      conn = DB.con(hds);
      setDbSession(conn);
      ps = conn.prepareStatement("select " + column_name + " from core_methods where upper(method) =  upper('" + method_name + "')");
      res = ps.executeQuery();
      if (res.next()) {
        result = nvl(res.getString(column_name), "{}");
      }
    } catch (Exception e) {
      e.printStackTrace();
      result = "{}";
    } finally {
      DB.done(ps);
      DB.done(res);
      DB.done(conn);
    }

    response = new JSONObject(result);
    return response;
  }

  //Cr By: Arslonbek Kulmatov
  //Updating login and password
  public String updateLoginPassword(String params) throws Exception {
    JSONObject req_param = new JSONObject(params);
    JSONObject res = new JSONObject();
    Connection conn = DB.con(hds);
    JbSql sql;
    setDbSession(conn);
    try {
      sql = new JbSql("Core_User.Edit_Login_Password", conn, false);
      sql.addParam(req_param.getInt("user_id"), 1);
      sql.addParam(req_param.getString("login"), 2);
      sql.addParam(encoder.encode(req_param.getString("password")), 3);
      sql.exec();
      res.put("success", true);
      res.put("message", "Successfully updated.");
    } catch (Exception e) {
      ExcMsg.call(res, e, conn);
      res.put("success", false);
    } finally {
      DB.done(conn);
    }
    return res.toString();
  }

  public String getHttpToken(String params) {
    try {
      JSONObject payload = new JSONObject(params);
      String endpoint = payload.getString("url");
      String request = payload.getString("body");
      boolean isProxy = payload.optBoolean("is_proxy");
      String proxyIp = payload.getString("proxy_ip");
      int proxyPort = payload.getInt("proxy_port");
      RestTemplate rt = getRestTemplate(isProxy, proxyIp, proxyPort);
      HttpHeaders headers = new HttpHeaders();
      headers.add("Content-type", payload.getString("content_type"));
      HttpEntity<String> entity = new HttpEntity<>(request, headers);
      ResponseEntity<String> response = rt.exchange(endpoint, HttpMethod.POST, entity, String.class);
      return response.getBody();
    } catch (Exception e) {
      log.error(e.getMessage());
      return e.getMessage();
    }
  }

  public String sendHttpRequest(String params) {
    JSONObject response = new JSONObject();
    try {
      JSONObject payload = new JSONObject(params);
      String endpoint = payload.getString("url");
      String body = payload.getString("body");
      String authToken = payload.getString("token");
      String methodType = payload.getString("method_type"); // POST, PUT, GET, DELETE,
      boolean isProxy = payload.optBoolean("is_proxy");
      String proxyIp = payload.getString("proxy_ip");
      int proxyPort = payload.getInt("proxy_port");
      HttpHeaders headers = new HttpHeaders();
      headers.add("Content-type", "application/json");
      headers.add("Authorization", authToken);
      RestTemplate rt = getRestTemplate(isProxy, proxyIp, proxyPort);
      HttpEntity<String> entity = new HttpEntity<>(body, headers);
      ResponseEntity<String> resp = rt.exchange(endpoint, getMethodType(methodType), entity, String.class);
      response.put("success", true);
      response.put("data", new JSONObject(resp.getBody()));
    } catch (Exception e) {
      e.printStackTrace();
      log.error(e.getMessage());
      response.put("success", false);
      response.put("error", e.getMessage());
    }
    return response.toString();
  }

  public String getHttpRequest(String params) {
    JSONObject response = new JSONObject();
    try {
      JSONObject payload = new JSONObject(params);
      Map<String, Object> paramMap = new HashMap<>();
      String endpoint = payload.getString("url");
      JSONObject body = payload.getJSONObject("body");
      String authToken = payload.getString("token");
      boolean isProxy = payload.optBoolean("is_proxy");
      String proxyIp = payload.getString("proxy_ip");
      int proxyPort = payload.getInt("proxy_port");
      HttpHeaders headers = new HttpHeaders();
      headers.add("Content-type", "application/json");
      headers.add("Authorization", authToken);
      RestTemplate rt = getRestTemplate(isProxy, proxyIp, proxyPort);
      HttpEntity<String> entity = new HttpEntity<>(headers);
      UriComponentsBuilder builder = UriComponentsBuilder.fromHttpUrl(endpoint);
      for (int i = 0; i < body.names().length(); ++i) {
        String key = body.names().getString(i);
        String value = body.getString(key);
        builder.queryParam(key, value);
        paramMap.put(key, value);
      }
      if (payload.optBoolean("is_file")) {
        ResponseEntity<byte[]> resp = rt.exchange(builder.toUriString(), HttpMethod.GET, entity, byte[].class, paramMap);
        byte[] encoded = Base64.getEncoder().encode(resp.getBody());
        response.put("data", new String(encoded));
      } else {
        ResponseEntity<String> resp = rt.exchange(builder.toUriString(), HttpMethod.GET, entity, String.class, paramMap);
        if (isValidJson(resp.getBody())) {
          response.put("data", new JSONObject(resp.getBody()));
        } else {
          response.put("data", removeDoubleQuote(resp.getBody()));
        }
      }
      response.put("success", true);
    } catch (Exception e) {
      e.printStackTrace();
      log.error(e.getMessage());
      response.put("success", false);
      response.put("error", e.getMessage());
    }
    return response.toString();
  }
}


