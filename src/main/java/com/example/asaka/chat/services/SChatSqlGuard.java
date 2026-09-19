package com.example.asaka.chat.services;

import org.springframework.stereotype.Service;

import java.util.LinkedHashSet;
import java.util.Locale;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Claude yozgan SQL ni bajarishdan oldin tekshiradi.
 *
 * Bu read-only DB user'dan KEYINGI ikkinchi himoya qatlami — user grant'lari
 * allaqachon DML/DDL ni to'sadi, bu klass esa noto'g'ri yoki qimmat so'rovni
 * DB ga umuman yubormaydi va xato xabarini Claude'ga tushunarli qaytaradi.
 */
@Service
public class SChatSqlGuard {

  public static class SqlRejected extends RuntimeException {
    public SqlRejected(String message) { super(message); }
  }

  /** Bitta statement'da uchrashi taqiqlangan so'zlar. */
  private static final Set<String> FORBIDDEN = Set.of(
      "INSERT", "UPDATE", "DELETE", "MERGE", "TRUNCATE", "DROP", "ALTER",
      "CREATE", "GRANT", "REVOKE", "COMMIT", "ROLLBACK", "SAVEPOINT",
      "EXECUTE", "EXEC", "CALL", "BEGIN", "DECLARE", "LOCK", "FLASHBACK",
      "PURGE", "RENAME", "COMMENT", "AUDIT", "ANALYZE", "EXPLAIN"
  );

  /** FROM / JOIN dan keyingi obyekt nomini oladi. */
  private static final Pattern OBJECT_REF = Pattern.compile(
      "(?i)\\b(?:from|join)\\s+([a-z_][a-z0-9_$#]*)\\s*(?:\\.\\s*([a-z_][a-z0-9_$#]*))?");

  /** `--` va `/* *\/` izohlarini olib tashlash (tekshirishni chalg'itmasin). */
  private static final Pattern LINE_COMMENT  = Pattern.compile("--[^\\n]*");
  private static final Pattern BLOCK_COMMENT = Pattern.compile("(?s)/\\*.*?\\*/");

  /**
   * SQL ni tekshiradi va bajarishga tayyor holatda qaytaradi
   * (row limit qo'shilgan, oxiridagi `;` olib tashlangan).
   *
   * @param rawSql        Claude yozgan SQL
   * @param allowedViews  ruxsat berilgan view nomlari (UPPER CASE)
   * @param maxRows       qatorlar chegarasi
   * @throws SqlRejected  tekshiruvdan o'tmasa
   */
  public String validate(String rawSql, Set<String> allowedViews, int maxRows) {
    if (rawSql == null || rawSql.isBlank()) {
      throw new SqlRejected("SQL bo'sh");
    }

    String sql = rawSql.trim();
    // Markdown code fence bo'lsa tozalaymiz
    sql = sql.replaceAll("(?s)^```(?:sql)?\\s*", "").replaceAll("(?s)\\s*```$", "").trim();
    // Oxiridagi `;`
    while (sql.endsWith(";")) {
      sql = sql.substring(0, sql.length() - 1).trim();
    }

    // Izohlarsiz nusxa — kalit so'z va obyekt tekshiruvi shu ustida ketadi
    String stripped = BLOCK_COMMENT.matcher(sql).replaceAll(" ");
    stripped = LINE_COMMENT.matcher(stripped).replaceAll(" ");

    // 1) Bitta statement bo'lishi shart
    if (stripped.contains(";")) {
      throw new SqlRejected("Faqat bitta SQL statement ruxsat etiladi (';' topildi)");
    }

    // 2) SELECT yoki WITH bilan boshlanishi shart
    String upper = stripped.toUpperCase(Locale.ROOT).trim();
    if (!upper.startsWith("SELECT") && !upper.startsWith("WITH")) {
      throw new SqlRejected("Faqat SELECT yoki WITH so'rovi ruxsat etiladi");
    }

    // 3) Taqiqlangan kalit so'zlar (satr literallari ichidagisi hisobga olinmasin)
    String withoutLiterals = stripped.replaceAll("'(?:[^']|'')*'", "''");
    for (String kw : FORBIDDEN) {
      if (Pattern.compile("(?i)\\b" + kw + "\\b").matcher(withoutLiterals).find()) {
        throw new SqlRejected("Taqiqlangan kalit so'z: " + kw);
      }
    }

    // 4) FROM/JOIN dagi har bir obyekt whitelist'da bo'lishi shart
    Set<String> referenced = extractObjects(withoutLiterals);
    Set<String> notAllowed = new LinkedHashSet<>();
    for (String obj : referenced) {
      if (!allowedViews.contains(obj)) {
        notAllowed.add(obj);
      }
    }
    if (!notAllowed.isEmpty()) {
      throw new SqlRejected("Ruxsat berilmagan jadval/view: " + String.join(", ", notAllowed)
          + ". Faqat quyidagilar mumkin: " + String.join(", ", allowedViews));
    }

    // 5) Qatorlar chegarasi
    if (!upper.contains("FETCH FIRST") && !upper.contains("ROWNUM")) {
      sql = sql + "\nFETCH FIRST " + maxRows + " ROWS ONLY";
    }

    return sql;
  }

  /**
   * FROM/JOIN dagi obyekt nomlarini yig'adi. CTE (WITH alias AS ...) nomlari
   * whitelist'ga qo'shiladi — ular haqiqiy obyekt emas, so'rov ichidagi alias.
   */
  private Set<String> extractObjects(String sql) {
    Set<String> cteNames = new LinkedHashSet<>();
    Matcher cte = Pattern.compile("(?i)\\b([a-z_][a-z0-9_$#]*)\\s+as\\s*\\(").matcher(sql);
    while (cte.find()) {
      cteNames.add(cte.group(1).toUpperCase(Locale.ROOT));
    }

    Set<String> objects = new LinkedHashSet<>();
    Matcher m = OBJECT_REF.matcher(sql);
    while (m.find()) {
      // `schema.object` bo'lsa ikkinchi guruh to'ladi
      String name = m.group(2) != null ? m.group(2) : m.group(1);
      String up = name.toUpperCase(Locale.ROOT);
      // `FROM (` — subquery, obyekt emas
      if (up.equals("DUAL") || cteNames.contains(up)) continue;
      // Schema prefiksi ishlatilgan bo'lsa ham rad etamiz (synonym orqali ketsin)
      if (m.group(2) != null) {
        throw new SqlRejected("Schema prefiksi ruxsat etilmaydi: " + m.group(1) + "." + m.group(2));
      }
      objects.add(up);
    }
    return objects;
  }
}
