package com.example.asaka.chat.services;

import com.anthropic.client.AnthropicClient;
import com.anthropic.models.messages.CacheControlEphemeral;
import com.anthropic.models.messages.Message;
import com.anthropic.models.messages.MessageCreateParams;
import com.anthropic.models.messages.TextBlockParam;
import com.anthropic.models.messages.ThinkingConfigAdaptive;
import com.example.asaka.util.DB;
import com.zaxxer.hikari.HikariDataSource;
import lombok.extern.slf4j.Slf4j;
import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.util.List;

/**
 * Chat oqimi: savol → SQL → natija → tabiiy tildagi javob.
 *
 * Ikki bosqichli (tool-use loop emas):
 *   1) SQL generatsiya — schema + savol beriladi, SQL matn qaytadi.
 *      Xato bo'lsa xato matni bilan bir marta qayta urinadi.
 *   2) Javob — savol + bajarilgan SQL + natija beriladi, matn javob qaytadi.
 *
 * Har bosqich alohida logga yoziladi (Pi_Chat_Logs).
 */
@Slf4j
@Service
public class SChat {

  @Autowired AnthropicClient claude;
  @Autowired SChatSchema schema;
  @Autowired SChatSqlGuard guard;
  @Autowired SChatQuery query;
  @Autowired HikariDataSource hds;

  @Value("${anthropic.model:claude-opus-5}") String model;
  @Value("${chat.max-rows:200}")             int maxRows;
  @Value("${chat.max-sql-retries:1}")        int maxRetries;

  public JSONObject ask(String question, Long userId, String sessionUuid, String lang) {
    long started = System.currentTimeMillis();
    JSONObject out = new JSONObject();
    String sql = null;
    JSONObject result = null;
    String answer = null;
    String error = null;
    long inTokens = 0, outTokens = 0;

    try {
      // --- 1-bosqich: SQL ---
      String lastError = null;
      for (int attempt = 0; attempt <= maxRetries; attempt++) {
        Message m = callClaude(sqlSystemPrompt(lang), sqlUserPrompt(question, lastError));
        inTokens  += m.usage().inputTokens();
        outTokens += m.usage().outputTokens();

        String raw = textOf(m);
        try {
          sql = guard.validate(raw, schema.allowedViews(), maxRows);
          result = query.run(sql, userId, lang);
          lastError = null;
          break;
        } catch (Exception e) {
          lastError = e.getMessage();
          sql = raw;
          log.warn("Chat SQL urinish #{} muvaffaqiyatsiz: {}", attempt + 1, lastError);
        }
      }

      if (lastError != null) {
        error = lastError;
        answer = errorAnswer(lang, lastError);
      } else {
        // --- 2-bosqich: javob ---
        Message m = callClaude(answerSystemPrompt(lang),
            answerUserPrompt(question, sql, result));
        inTokens  += m.usage().inputTokens();
        outTokens += m.usage().outputTokens();
        answer = textOf(m);
      }

      out.put("success", error == null);
      out.put("answer", answer);
      out.put("sql", sql);
      if (result != null) {
        out.put("columns",   result.get("columns"));
        out.put("rows",      result.get("rows"));
        out.put("row_count", result.getInt("row_count"));
      }
      if (error != null) out.put("error", error);

    } catch (Exception e) {
      log.error("Chat so'rovi xato", e);
      error = e.getMessage();
      out.put("success", false);
      out.put("error", error);
      out.put("answer", errorAnswer(lang, error));
    } finally {
      audit(userId, sessionUuid, question, sql, result, answer, error,
          System.currentTimeMillis() - started, inTokens, outTokens);
    }

    return out;
  }

  // ------------------------------------------------------------------
  // Claude chaqiruvi
  // ------------------------------------------------------------------

  private Message callClaude(String system, String user) {
    MessageCreateParams params = MessageCreateParams.builder()
        .model(model)
        .maxTokens(16000L)
        .thinking(ThinkingConfigAdaptive.builder().build())
        // Schema o'zgarmaydi → cache'lansin (system prompt eng katta qism)
        .systemOfTextBlockParams(List.of(
            TextBlockParam.builder()
                .text(system)
                .cacheControl(CacheControlEphemeral.builder().build())
                .build()))
        .addUserMessage(user)
        .build();

    return claude.messages().create(params);
  }

  private String textOf(Message m) {
    StringBuilder sb = new StringBuilder();
    m.content().forEach(b -> b.text().ifPresent(t -> sb.append(t.text())));
    return sb.toString().trim();
  }

  // ------------------------------------------------------------------
  // Promptlar
  // ------------------------------------------------------------------

  private String sqlSystemPrompt(String lang) {
    return """
        Sen Monello sug'urta tizimining Oracle bazasi uchun SQL yozuvchi yordamchisan.
        Foydalanuvchi savolidan Oracle SELECT so'rovini tuzasan.

        QAT'IY QOIDALAR:
        1. FAQAT bitta SELECT (yoki WITH ... SELECT) so'rovi yoz. Boshqa hech narsa emas.
        2. Faqat quyida berilgan view'lardan foydalan. Boshqa jadval/view YO'Q.
        3. Schema prefiksi yozma (PSBINSURANCE. kabi) — view nomini to'g'ridan-to'g'ri yoz.
        4. Javobingda FAQAT SQL bo'lsin. Izoh, markdown belgisi, ``` yozma.
        5. Nuqtali vergul (;) qo'yma.
        6. Sana ustunlari turiga e'tibor ber: VARCHAR2 bo'lsa TO_DATE(ustun,'dd.mm.yyyy')
           bilan solishtir, DATE bo'lsa to'g'ridan-to'g'ri ishlat.
        7. Qatorlar chegarasini o'zing qo'yma — tizim avtomatik qo'shadi.
        8. Ustun nomlariga tushunarli alias ber (masalan: SUM(paid_amount) AS jami_tolov).

        MAVJUD VIEW'LAR:
        """ + schema.schemaText() + """

        Agar savolga mavjud view'lar bilan javob berib bo'lmasa, SQL o'rniga
        shu matnni qaytaring: NO_DATA_AVAILABLE
        """;
  }

  private String sqlUserPrompt(String question, String previousError) {
    if (previousError == null) return question;
    return question + "\n\n---\nOldingi urinishing xato berdi: " + previousError
        + "\nShu xatoni hisobga olib SQL ni qayta yoz.";
  }

  private String answerSystemPrompt(String lang) {
    String langName = "uz".equalsIgnoreCase(lang) ? "o'zbek" : "rus";
    return """
        Sen Monello sug'urta tizimining hisobot yordamchisisan.
        Foydalanuvchi savol berdi, baza so'rovi bajarildi, natija sen oldingda.

        Vazifang: natijani %s tilida qisqa va aniq tushuntirib berish.

        QOIDALAR:
        - Faqat berilgan natijaga tayan. O'zingdan raqam o'ylab topma.
        - Summalarni o'qishga qulay yoz (masalan: 17 799 839,28 so'm).
        - Natija bo'sh bo'lsa shuni ochiq ayt.
        - Qatorlar ko'p bo'lsa asosiy raqamlarni va xulosani ber, hammasini sanama —
          foydalanuvchi jadvalni o'zi ham ko'radi.
        - SQL kodini javobingga kiritma.
        - 5 jumladan oshirma.
        """.formatted(langName);
  }

  private String answerUserPrompt(String question, String sql, JSONObject result) {
    JSONArray rows = result.getJSONArray("rows");
    int total = result.getInt("row_count");
    // Juda katta natijani promptga to'liq solmaymiz
    JSONArray sample = rows;
    if (rows.length() > 50) {
      sample = new JSONArray();
      for (int i = 0; i < 50; i++) sample.put(rows.get(i));
    }
    return "Savol: " + question
        + "\n\nBajarilgan SQL:\n" + sql
        + "\n\nQatorlar soni: " + total
        + (rows.length() > 50 ? " (quyida birinchi 50 tasi)" : "")
        + "\n\nNatija (JSON):\n" + sample.toString();
  }

  private String errorAnswer(String lang, String error) {
    if ("uz".equalsIgnoreCase(lang)) {
      return "Kechirasiz, savolingizga javob topa olmadim. Sababi: " + error
          + "\nSavolni boshqacha ifodalab ko'ring yoki sana oralig'ini aniqroq yozing.";
    }
    return "Извините, не удалось получить ответ. Причина: " + error
        + "\nПопробуйте переформулировать вопрос или уточнить период.";
  }

  // ------------------------------------------------------------------
  // Audit
  // ------------------------------------------------------------------

  private void audit(Long userId, String sessionUuid, String question, String sql,
                     JSONObject result, String answer, String error,
                     long durationMs, long inTokens, long outTokens) {
    Connection conn = null;
    try {
      conn = DB.con(hds);
      String ins =
          "Insert Into Pi_Chat_Logs (user_id, session_uuid, question, generated_sql, " +
          "  row_count, answer, error_msg, duration_ms, input_tokens, output_tokens) " +
          "Values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
      try (PreparedStatement ps = conn.prepareStatement(ins)) {
        if (userId == null) ps.setNull(1, java.sql.Types.NUMERIC); else ps.setLong(1, userId);
        ps.setString(2, sessionUuid);
        ps.setString(3, cut(question, 4000));
        ps.setString(4, sql);
        ps.setInt(5, result == null ? 0 : result.getInt("row_count"));
        ps.setString(6, answer);
        ps.setString(7, cut(error, 4000));
        ps.setLong(8, durationMs);
        ps.setLong(9, inTokens);
        ps.setLong(10, outTokens);
        ps.executeUpdate();
      }
    } catch (Exception e) {
      log.warn("Chat log yozilmadi: {}", e.getMessage());
    } finally {
      DB.done(conn);
    }
  }

  private String cut(String s, int max) {
    if (s == null) return null;
    return s.length() <= max ? s : s.substring(0, max);
  }
}
