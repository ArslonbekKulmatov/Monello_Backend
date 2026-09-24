package com.example.asaka.chat.services;

import com.example.asaka.util.DB;
import com.zaxxer.hikari.HikariDataSource;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Service;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

/**
 * Claude'ga beriladigan schema tavsifini quradi.
 *
 * Ustunlar ALL_TAB_COLUMNS dan runtime'da olinadi — view o'zgarsa prompt ham
 * o'z-o'zidan yangilanadi. Har view uchun PI_S_CHAT_VIEWS.hint qo'shiladi
 * (sana formati, birliklar kabi konvensiyalar).
 *
 * Natija cache'lanadi; view ro'yxati o'zgarsa {@link #invalidate()} chaqiring.
 */
@Slf4j
@Service
public class SChatSchema {

  @Autowired HikariDataSource hds;                       // asosiy pool — metadata o'qish uchun
  @Autowired @Qualifier("chatReadOnlyDataSource") HikariDataSource chatDs;

  private volatile String cachedSchema;
  private volatile Set<String> cachedViews;

  /** Whitelist'dagi view nomlari (UPPER CASE). */
  public Set<String> allowedViews() {
    if (cachedViews == null) loadAll();
    return cachedViews;
  }

  /** Claude system prompt'iga tushadigan schema matni. */
  public String schemaText() {
    if (cachedSchema == null) loadAll();
    return cachedSchema;
  }

  public synchronized void invalidate() {
    cachedSchema = null;
    cachedViews = null;
  }

  private synchronized void loadAll() {
    if (cachedSchema != null) return;

    Map<String, String[]> views = new LinkedHashMap<>();   // view -> {title, hint}
    Connection conn = null;
    try {
      conn = DB.con(hds);
      try (PreparedStatement ps = conn.prepareStatement(
               "Select view_name, title_uz, hint From Pi_S_Chat_Views_V");
           ResultSet rs = ps.executeQuery()) {
        while (rs.next()) {
          views.put(rs.getString("view_name").toUpperCase(Locale.ROOT),
              new String[]{ rs.getString("title_uz"), rs.getString("hint") });
        }
      }
    } catch (Exception e) {
      log.error("Chat view whitelist o'qib bo'lmadi", e);
      throw new IllegalStateException("Chat sozlamalari o'qilmadi: " + e.getMessage(), e);
    } finally {
      DB.done(conn);
    }

    if (views.isEmpty()) {
      throw new IllegalStateException("Pi_S_Chat_Views bo'sh — chat uchun view ochilmagan");
    }

    // Ustunlarni read-only user nomidan o'qiymiz: u ko'ra olmaydigan view
    // schema'ga ham tushmasin (grant va whitelist bir-biriga mos bo'lsin).
    StringBuilder sb = new StringBuilder();
    Set<String> visible = new LinkedHashSet<>();
    Connection roConn = null;
    try {
      roConn = chatDs.getConnection();
      for (Map.Entry<String, String[]> e : views.entrySet()) {
        String viewName = e.getKey();
        List<String> cols = columnsOf(roConn, viewName);
        if (cols.isEmpty()) {
          log.warn("Chat view '{}' whitelist'da bor, lekin MONELLO_CHAT_RO uni ko'rmayapti "
              + "— GRANT SELECT va SYNONYM tekshiring", viewName);
          continue;
        }
        visible.add(viewName);
        sb.append("\n### ").append(viewName).append(" — ").append(e.getValue()[0]).append('\n');
        if (e.getValue()[1] != null && !e.getValue()[1].isBlank()) {
          sb.append(e.getValue()[1]).append('\n');
        }
        sb.append("Ustunlar:\n");
        for (String c : cols) {
          sb.append("  - ").append(c).append('\n');
        }
      }
    } catch (Exception e) {
      log.error("Chat schema qurib bo'lmadi", e);
      throw new IllegalStateException("Schema o'qilmadi: " + e.getMessage(), e);
    } finally {
      DB.done(roConn);
    }

    if (visible.isEmpty()) {
      throw new IllegalStateException(
          "MONELLO_CHAT_RO birorta ham whitelist view'ni ko'rmayapti — GRANT/SYNONYM yo'q");
    }

    cachedViews = visible;
    cachedSchema = sb.toString();
    log.info("Chat schema tayyor: {} ta view", visible.size());
  }

  /** `NAME TYPE(len)` ko'rinishidagi ustun ro'yxati. */
  private List<String> columnsOf(Connection conn, String viewName) throws Exception {
    List<String> out = new ArrayList<>();
    String sql =
        "Select column_name, data_type, data_length, data_precision, data_scale " +
        "  From all_tab_columns " +
        " Where table_name = ? " +
        " Order By column_id";
    try (PreparedStatement ps = conn.prepareStatement(sql)) {
      ps.setString(1, viewName);
      try (ResultSet rs = ps.executeQuery()) {
        while (rs.next()) {
          String type = rs.getString("data_type");
          String rendered;
          if ("NUMBER".equals(type)) {
            int p = rs.getInt("data_precision");
            int s = rs.getInt("data_scale");
            rendered = rs.wasNull() || p == 0 ? "NUMBER" : "NUMBER(" + p + "," + s + ")";
          } else if (type != null && type.startsWith("VARCHAR")) {
            rendered = type + "(" + rs.getInt("data_length") + ")";
          } else {
            rendered = type;
          }
          out.add(rs.getString("column_name") + " " + rendered);
        }
      }
    }
    return out;
  }
}
