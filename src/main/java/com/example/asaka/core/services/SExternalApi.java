package com.example.asaka.core.services;

import com.example.asaka.util.DB;
import com.example.asaka.util.JbSql;
import com.zaxxer.hikari.HikariDataSource;
import lombok.extern.slf4j.Slf4j;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.util.HexFormat;

//Cr By: Arslonbek Kulmatov
//Tashqi tizimlar uchun umumiy kirish nuqtasi: token tekshirish, metod chaqirish
//va xatolarni HTTP kodlariga o'girish.
//
//Katalog ham, boshqaruv paneli ham shu orqali ishlaydi. Xavfsizlik kodi bitta
//joyda turishi kerak: ikki nusxaning biri tuzatilib ikkinchisi unutilishi —
//eng oson yo'l qo'yiladigan xato.
@Slf4j
@Service
public class SExternalApi {

  public static final String SCOPE_CATALOG = "catalog";
  public static final String SCOPE_REPORT  = "report";
  // MCP mijozlari uchun. Bu qamrovda sessiya filiali yo'q, ya'ni barcha
  // filiallar ko'rinadi — token faqat boshqaruvga beriladi.
  public static final String SCOPE_CHAT    = "chat";

  @Autowired private HikariDataSource hds;
  @Autowired private SApp sApp;

  //Cr By: Arslonbek Kulmatov
  //Token tekshirish. Token qaysi foydalanuvchi nomidan ishlashini qaytaradi,
  //token yo'q, bekor qilingan yoki BOSHQA qamrovga tegishli bo'lsa null.
  //
  //Qamrov muhim: sayt katalogi uchun berilgan token qarzdorlik va mijoz
  //ismlarini o'qiy olmasligi kerak.
  public Long authenticate(String authorizationHeader, String requiredScope) {
    if (authorizationHeader == null || !authorizationHeader.regionMatches(true, 0, "Bearer ", 0, 7)) {
      return null;
    }
    String token = authorizationHeader.substring(7).trim();
    if (token.isEmpty()) {
      return null;
    }

    Connection conn = null;
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
      conn = DB.con(hds);
      ps = conn.prepareStatement(
          "select user_id from core_api_tokens" +
          " where token_hash = ? and scope = ? and condition = 'A'");
      ps.setString(1, sha256Hex(token));
      ps.setString(2, requiredScope);
      rs = ps.executeQuery();
      if (rs.next()) {
        return rs.getLong("user_id");
      }
    } catch (Exception e) {
      // Tokenning o'zi hech qachon logga tushmasligi kerak
      log.error("API tokenini tekshirishda xato: {}", e.getMessage());
    } finally {
      DB.done(rs);
      DB.done(ps);
      DB.done(conn);
    }
    return null;
  }

  //Cr By: Arslonbek Kulmatov
  //Metodni Core_App.Set_Method orqali chaqirib, javobni HTTP ga o'girish.
  public ResponseEntity<String> call(String method, JSONObject params, Long userId) {
    try {
      String body = exec(method, params, userId);
      if (body == null) {
        log.error("Metod bo'sh javob qaytardi: {}", method);
        return error(HttpStatus.INTERNAL_SERVER_ERROR, "Internal error");
      }
      return ResponseEntity.ok().contentType(MediaType.APPLICATION_JSON).body(body);
    } catch (SQLException e) {
      // Core_App.Set_Method validatsiya xatolarini ORA-20000 bilan chiqaradi —
      // ular mijozning aybi, qolgan hamma narsa bizniki.
      if (e.getErrorCode() == 20000) {
        return error(HttpStatus.BAD_REQUEST, cleanOraMessage(e.getMessage()));
      }
      log.error("Metodda baza xatosi [{}]: {}", method, e.getMessage());
      return error(HttpStatus.INTERNAL_SERVER_ERROR, "Internal error");
    } catch (Exception e) {
      log.error("Metodda xato [{}]: {}", method, e.getMessage());
      return error(HttpStatus.INTERNAL_SERVER_ERROR, "Internal error");
    }
  }

  //Cr By: Arslonbek Kulmatov
  //Xato javobi. Tashqi tizimga baza xatolari CHIQMAYDI — ular logda qoladi.
  public ResponseEntity<String> error(HttpStatus status, String message) {
    JSONObject body = new JSONObject();
    body.put("error", new JSONObject().put("code", status.value()).put("message", message));
    return ResponseEntity.status(status).contentType(MediaType.APPLICATION_JSON).body(body.toString());
  }

  public ResponseEntity<String> unauthorized() {
    return error(HttpStatus.UNAUTHORIZED, "Invalid or missing API token");
  }

  // So'rov tizimdagi barcha metodlar kabi {"method":.., "params":{..}} ko'rinishida
  private String exec(String method, JSONObject params, Long userId) throws Exception {
    JSONObject request = new JSONObject();
    request.put("method", method);
    request.put("params", params);

    Connection conn = DB.con(hds);
    try {
      sApp.setDbSessionForUser(conn, userId.toString());
      JbSql sql = new JbSql("Core_App.Set_Method", conn, false);
      sql.addParam(request.toString(), 1);
      sql.addOut(Types.CLOB, 2);
      sql.exec();
      return (String) sql.getOutVal(2);
    } finally {
      DB.done(conn);
    }
  }

  private String cleanOraMessage(String message) {
    if (message == null) {
      return "Bad request";
    }
    String cleaned = message.replaceAll("ORA-\\d{5}:\\s*", "").trim();
    int lineEnd = cleaned.indexOf('\n');
    if (lineEnd > 0) {
      cleaned = cleaned.substring(0, lineEnd).trim();
    }
    return cleaned.isEmpty() ? "Bad request" : cleaned;
  }

  // Bazadagi core_api_tokens.token_hash bilan bir xil ko'rinish:
  // kichik harfli hex, standard_hash(..., 'SHA256') natijasi.
  private String sha256Hex(String value) {
    try {
      MessageDigest digest = MessageDigest.getInstance("SHA-256");
      return HexFormat.of().formatHex(digest.digest(value.getBytes(StandardCharsets.UTF_8)));
    } catch (Exception e) {
      throw new IllegalStateException("SHA-256 mavjud emas", e);
    }
  }
}
