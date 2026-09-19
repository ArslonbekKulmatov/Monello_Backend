package com.example.asaka.chat.services;

import com.example.asaka.util.DB;
import com.zaxxer.hikari.HikariDataSource;
import lombok.extern.slf4j.Slf4j;
import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.Types;

/**
 * Tekshiruvdan o'tgan SQL ni read-only pool orqali bajaradi.
 *
 * Har so'rovdan oldin Core_Session o'rnatiladi — shu bilan view'lardagi
 * filial/rol bo'yicha satr filtrlari xodimning o'z huquqiga mos ishlaydi.
 */
@Slf4j
@Service
public class SChatQuery {

  @Autowired @Qualifier("chatReadOnlyDataSource") HikariDataSource chatDs;

  @Value("${chat.query-timeout-seconds:30}") int queryTimeout;

  /** Natija: ustunlar + qatorlar + qator soni. */
  public JSONObject run(String sql, Long userId, String lang) throws Exception {
    long started = System.currentTimeMillis();
    Connection conn = null;
    try {
      conn = chatDs.getConnection();
      setSession(conn, userId, lang);

      JSONArray rows = new JSONArray();
      JSONArray columns = new JSONArray();

      try (PreparedStatement ps = conn.prepareStatement(sql)) {
        ps.setQueryTimeout(queryTimeout);
        try (ResultSet rs = ps.executeQuery()) {
          ResultSetMetaData md = rs.getMetaData();
          int n = md.getColumnCount();
          for (int i = 1; i <= n; i++) {
            columns.put(md.getColumnLabel(i).toLowerCase());
          }
          while (rs.next()) {
            JSONObject row = new JSONObject();
            for (int i = 1; i <= n; i++) {
              row.put(md.getColumnLabel(i).toLowerCase(), readCell(rs, md, i));
            }
            rows.put(row);
          }
        }
      }

      JSONObject out = new JSONObject();
      out.put("columns", columns);
      out.put("rows", rows);
      out.put("row_count", rows.length());
      out.put("duration_ms", System.currentTimeMillis() - started);
      return out;

    } finally {
      DB.done(conn);
    }
  }

  private Object readCell(ResultSet rs, ResultSetMetaData md, int i) throws Exception {
    switch (md.getColumnType(i)) {
      case Types.NUMERIC:
      case Types.DECIMAL:
      case Types.BIGINT:
        java.math.BigDecimal bd = rs.getBigDecimal(i);
        return bd == null ? JSONObject.NULL : bd;
      case Types.INTEGER:
      case Types.SMALLINT:
      case Types.TINYINT:
        int iv = rs.getInt(i);
        return rs.wasNull() ? JSONObject.NULL : iv;
      case Types.DOUBLE:
      case Types.FLOAT:
        double dv = rs.getDouble(i);
        return rs.wasNull() ? JSONObject.NULL : dv;
      case Types.DATE:
      case Types.TIMESTAMP:
        java.sql.Timestamp ts = rs.getTimestamp(i);
        return ts == null ? JSONObject.NULL : new java.text.SimpleDateFormat("dd.MM.yyyy").format(ts);
      default:
        String s = rs.getString(i);
        return s == null ? JSONObject.NULL : s;
    }
  }

  /** Satr darajasidagi filtrlar ishlashi uchun DB sessiyasini o'rnatadi. */
  private void setSession(Connection conn, Long userId, String lang) {
    if (userId == null) return;
    try (PreparedStatement ps = conn.prepareStatement(
        "Begin Core_Session.Set_User_Session(?, null, ?); End;")) {
      ps.setString(1, String.valueOf(userId));
      ps.setString(2, lang == null || lang.isBlank() ? "ru" : lang);
      ps.execute();
    } catch (Exception e) {
      // Sessiya o'rnatilmasa so'rov baribir ketadi, lekin filial filtri ishlamaydi
      log.warn("Chat uchun Core_Session o'rnatilmadi (user_id={}): {}", userId, e.getMessage());
    }
  }
}
