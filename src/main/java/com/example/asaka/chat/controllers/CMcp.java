package com.example.asaka.chat.controllers;

import com.example.asaka.chat.ChatToolCatalog;
import com.example.asaka.core.services.SExternalApi;
import lombok.extern.slf4j.Slf4j;
import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

//Cr By: Arslonbek Kulmatov
//MCP server: Monello tool'larini tashqi MCP mijozlariga beradi.
//
//NIMA UCHUN KERAK
//  Ichki chat bu endpointdan foydalanmaydi — u ChatToolCatalog ni
//  to'g'ridan-to'g'ri chaqiradi. Bu endpoint boshqa mijozlar uchun:
//  masalan Claude Desktop yoki Claude Code Monello ma'lumotiga ulanishi
//  uchun.
//
//QAMROV — DIQQAT
//  Bu yerda JWT yo'q, ya'ni sessiya filiali ham yo'q: tool'lar BARCHA
//  filiallarni ko'rsatadi. Shuning uchun "chat" qamrovli token faqat
//  boshqaruvga beriladi. Sotuvchiga bermang — u web orqali o'z filialini
//  ko'radi, bu esa hammasini ochadi.
//
//PROTOKOL
//  JSON-RPC 2.0. Qo'llab-quvvatlanadi: initialize, tools/list, tools/call,
//  ping. Bildirishnomalar (id siz) javobsiz qoladi.
@Slf4j
@RestController
@RequestMapping("/api/mcp")
public class CMcp {

  // Mijoz o'z versiyasini yubormasa shu ishlatiladi. MCP spetsifikatsiyasi
  // yangilanganda bu qator ham yangilanishi kerak.
  private static final String PROTOCOL_VERSION = "2025-06-18";

  @Autowired private ChatToolCatalog catalog;
  @Autowired private SExternalApi api;

  @PostMapping(produces = MediaType.APPLICATION_JSON_VALUE)
  public ResponseEntity<String> rpc(
      @RequestHeader(value = "Authorization", required = false) String authorization,
      @RequestBody String body) {

    Long userId = api.authenticate(authorization, SExternalApi.SCOPE_CHAT);
    if (userId == null) {
      return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
          .contentType(MediaType.APPLICATION_JSON)
          .body(new JSONObject().put("error", "Invalid or missing API token").toString());
    }

    JSONObject req;
    try {
      req = new JSONObject(body);
    } catch (Exception e) {
      return ok(rpcError(null, -32700, "Parse error"));
    }

    Object id = req.opt("id");
    String method = req.optString("method", "");

    // Bildirishnoma: id yo'q, javob ham bo'lmaydi
    if (req.isNull("id") && method.startsWith("notifications/")) {
      return ResponseEntity.noContent().build();
    }

    try {
      switch (method) {
        case "initialize":
          return ok(rpcResult(id, initialize(req)));

        case "tools/list":
          return ok(rpcResult(id, new JSONObject().put("tools", catalog.asMcpTools())));

        case "tools/call":
          return ok(rpcResult(id, callTool(req, userId)));

        case "ping":
          return ok(rpcResult(id, new JSONObject()));

        default:
          return ok(rpcError(id, -32601, "Method not found: " + method));
      }
    } catch (Exception e) {
      log.error("MCP xatosi [{}]: {}", method, e.getMessage());
      return ok(rpcError(id, -32603, "Internal error"));
    }
  }

  // --- metodlar ------------------------------------------------------------

  private JSONObject initialize(JSONObject req) {
    // Mijoz so'ragan versiyani qaytaramiz — kelishuv shunday ishlaydi
    String version = req.optJSONObject("params") != null
        ? req.getJSONObject("params").optString("protocolVersion", PROTOCOL_VERSION)
        : PROTOCOL_VERSION;

    return new JSONObject()
        .put("protocolVersion", version)
        .put("capabilities", new JSONObject().put("tools", new JSONObject()))
        .put("serverInfo", new JSONObject()
            .put("name", "monello")
            .put("version", "1"));
  }

  //Cr By: Arslonbek Kulmatov
  //Tool chaqiruvi.
  //
  //Xato MCP da HTTP xatosi emas: javob 200 bo'ladi, ichida isError = true.
  //Shunda mijoz xatoni modelga ko'rsatib, boshqacha urinib ko'ra oladi.
  private JSONObject callTool(JSONObject req, Long userId) {
    JSONObject params = req.optJSONObject("params");
    if (params == null) {
      return toolError("params berilmagan.");
    }
    String name = params.optString("name", "");
    if (catalog.get(name) == null) {
      return toolError("Bunday tool yo'q: " + name);
    }
    JSONObject args = params.optJSONObject("arguments");
    String result = catalog.executeAsToken(name, args, userId);

    boolean isError = new JSONObject(result).has("error");

    return new JSONObject()
        .put("content", new JSONArray().put(
            new JSONObject().put("type", "text").put("text", result)))
        .put("isError", isError);
  }

  private JSONObject toolError(String message) {
    return new JSONObject()
        .put("content", new JSONArray().put(
            new JSONObject().put("type", "text")
                .put("text", new JSONObject().put("error", message).toString())))
        .put("isError", true);
  }

  // --- JSON-RPC konverti ---------------------------------------------------

  private JSONObject rpcResult(Object id, JSONObject result) {
    return new JSONObject().put("jsonrpc", "2.0").put("id", id).put("result", result);
  }

  private JSONObject rpcError(Object id, int code, String message) {
    return new JSONObject().put("jsonrpc", "2.0").put("id", id)
        .put("error", new JSONObject().put("code", code).put("message", message));
  }

  private ResponseEntity<String> ok(JSONObject payload) {
    return ResponseEntity.ok().contentType(MediaType.APPLICATION_JSON).body(payload.toString());
  }
}
