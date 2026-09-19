package com.example.asaka.chat.controllers;

import com.example.asaka.chat.services.SChat;
import com.example.asaka.chat.services.SChatSchema;
import com.example.asaka.security.jwt.JwtUtils;
import io.jsonwebtoken.Claims;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Monello chat — xodim tabiiy tilda hisobot so'raydi.
 *
 *   POST /api/app/chat/ask       — savol berish
 *   POST /api/app/chat/reload    — view whitelist cache'ini yangilash (admin)
 *   GET  /api/app/chat/views     — chat qaysi ma'lumotni ko'ra olishini ko'rsatish
 */
@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/app/chat")
@ConditionalOnProperty(name = "chat.enabled", havingValue = "true")
public class CChat {

  @Autowired SChat sChat;
  @Autowired SChatSchema schema;
  @Autowired JwtUtils jwtUtils;

  /**
   * Request:  { "question": "...", "session_uuid": "...", "lang": "uz" }
   * Response: { success, answer, sql, columns, rows, row_count }
   */
  @PostMapping(value = "/ask", produces = "application/json")
  public ResponseEntity<?> ask(@RequestBody String params,
                               @RequestHeader(value = "Authorization", required = false) String auth,
                               @RequestHeader(value = "lang", required = false) String langHeader) {
    try {
      JSONObject req = new JSONObject(params);
      String question = req.optString("question", "").trim();
      if (question.isEmpty()) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
            .body(new JSONObject().put("success", false).put("error", "question bo'sh").toString());
      }

      Long userId = userIdFrom(auth);
      if (userId == null) {
        return ResponseEntity.status(HttpStatus.FORBIDDEN)
            .body(new JSONObject().put("success", false)
                .put("error", "JWT token has been expired").toString());
      }

      String lang = req.optString("lang", langHeader == null ? "ru" : langHeader);
      String sessionUuid = req.optString("session_uuid", null);

      JSONObject result = sChat.ask(question, userId, sessionUuid, lang);
      return ResponseEntity.ok(result.toString());

    } catch (Exception e) {
      return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
          .body(new JSONObject().put("success", false).put("error", e.getMessage()).toString());
    }
  }

  /** Chat qaysi view'larni ko'ra olishini qaytaradi — foydalanuvchiga ko'rsatish uchun. */
  @GetMapping(value = "/views", produces = "application/json")
  public ResponseEntity<?> views() {
    try {
      return ResponseEntity.ok(new JSONObject()
          .put("success", true)
          .put("views", schema.allowedViews())
          .toString());
    } catch (Exception e) {
      return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
          .body(new JSONObject().put("success", false).put("error", e.getMessage()).toString());
    }
  }

  /** Pi_S_Chat_Views o'zgartirilgandan keyin cache'ni tozalash. */
  @PostMapping(value = "/reload", produces = "application/json")
  public ResponseEntity<?> reload() {
    schema.invalidate();
    return ResponseEntity.ok(new JSONObject().put("success", true)
        .put("message", "Schema cache tozalandi").toString());
  }

  private Long userIdFrom(String authHeader) {
    try {
      Claims claims = jwtUtils.getClaimsFromHeaderString(authHeader);
      if (claims == null || claims.get("userId") == null) return null;
      return Long.valueOf(claims.get("userId").toString());
    } catch (Exception e) {
      return null;
    }
  }
}
