package com.example.asaka.catalog.services;

import com.example.asaka.core.services.SApp;
import com.example.asaka.util.DB;
import com.example.asaka.util.JbSql;
import com.zaxxer.hikari.HikariDataSource;
import lombok.extern.slf4j.Slf4j;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Types;
import java.util.HexFormat;

//Cr By: Arslonbek Kulmatov
//ABM Store sayti uchun katalog API
@Slf4j
@Service
public class SCatalog {

  @Autowired private HikariDataSource hds;
  @Autowired private SApp sApp;

  //Cr By: Arslonbek Kulmatov
  //Token tekshirish. Token qaysi foydalanuvchi nomidan ishlashini qaytaradi,
  //token yo'q yoki bekor qilingan bo'lsa null.
  public Long authenticate(String authorizationHeader) {
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
          "select user_id from core_api_tokens where token_hash = ? and condition = 'A'");
      ps.setString(1, sha256Hex(token));
      rs = ps.executeQuery();
      if (rs.next()) {
        return rs.getLong("user_id");
      }
    } catch (Exception e) {
      // Tokenning o'zi hech qachon logga tushmasligi kerak
      log.error("Katalog tokenini tekshirishda xato: {}", e.getMessage());
    } finally {
      DB.done(rs);
      DB.done(ps);
      DB.done(conn);
    }
    return null;
  }

  //Cr By: Arslonbek Kulmatov
  //Metodni Core_App.Set_Method orqali chaqirish
  public String call(JSONObject params, Long userId) throws Exception {
    Connection conn = DB.con(hds);
    try {
      sApp.setDbSessionForUser(conn, userId.toString());
      JbSql sql = new JbSql("Core_App.Set_Method", conn, false);
      sql.addParam(params.toString(), 1);
      sql.addOut(Types.CLOB, 2);
      sql.exec();
      return (String) sql.getOutVal(2);
    } finally {
      DB.done(conn);
    }
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
