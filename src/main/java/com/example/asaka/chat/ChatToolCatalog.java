package com.example.asaka.chat;

import com.example.asaka.core.services.SApp;
import com.example.asaka.core.services.SExternalApi;
import lombok.extern.slf4j.Slf4j;
import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import javax.annotation.PostConstruct;
import java.util.LinkedHashMap;
import java.util.Map;

//Cr By: Arslonbek Kulmatov
//Chat tool'lari ro'yxati va ularni bajarish.
//
//Bitta manba: shu ro'yxat ham chatga, ham /api/mcp ga xizmat qiladi. Tool
//ikki joyda ta'riflansa, biri o'zgartirilib ikkinchisi unutiladi.
//
//Tool'ning o'zi SQL yozmaydi — har biri Monello'ning ro'yxatdan o'tgan
//metodiga (Ipt_Chat paketi) tegishli. Model faqat shu metodlarni chaqira
//oladi va ularning hammasi faqat o'qiydi.
@Slf4j
@Service
public class ChatToolCatalog {

  @Autowired private SApp sApp;
  @Autowired private SExternalApi externalApi;

  public static class ToolDef {
    public final String name;
    public final String description;
    public final JSONObject schema;

    ToolDef(String name, String description, JSONObject schema) {
      this.name = name;
      this.description = description;
      this.schema = schema;
    }
  }

  private final Map<String, ToolDef> tools = new LinkedHashMap<>();

  @PostConstruct
  void build() {
    add("chatFilials",
        "Filiallar ro'yxati va ularning joriy holati: har filialda nechta faol "
        + "sdelka, nechta mijoz va omborda nechta tovar bor. Parametrlari yo'q. "
        + "\"Qaysi filiallar bor\", \"Mirobodda nechta sdelka bor\" kabi savollar uchun.",
        props());

    add("chatSales",
        "Savdolar: davr bo'yicha sdelkalar soni va summasi, filial kesimida. "
        + "Bekor qilingan va qaytarilgan sdelkalar soni ham qaytadi. "
        + "Davr berilmasa joriy oy boshidan bugungacha olinadi.",
        props()
            .put("date_from", str("Davr boshi, YYYY-MM-DD. Berilmasa joriy oy boshi."))
            .put("date_to",   str("Davr oxiri, YYYY-MM-DD. Berilmasa bugun.")));

    add("chatInstallments",
        "Faol rassrochkalar ro'yxati: mijoz, tovar, oylik to'lov, qolgan qarz va "
        + "kechikish kuni. client_name berilsa faqat o'sha mijozning sdelkalari "
        + "qaytadi. \"Azizovning rassrochkasi bormi\" kabi savollar uchun.",
        props()
            .put("client_name", str("Mijoz ismining bir qismi. Registr muhim emas.")));

    add("chatDebtors",
        "Qarzdorlar: kechikkan sdelkalar ro'yxati, eng uzoq kechikkanidan "
        + "boshlab. Jami qarzdorlar soni va umumiy kechikkan summa ham qaytadi. "
        + "\"Kim qarzdor\", \"30 kundan ortiq kechikkanlar\" kabi savollar uchun.",
        props()
            .put("min_days", num("Eng kam kechikish kuni. Sukut bo'yicha 1.")));

    add("chatTrade",
        "Bitta sdelkaning shartlari va to'lov grafigi: har oyning summasi, "
        + "to'langan-to'lanmagani va muddati. Sdelka raqami ma'lum bo'lganda "
        + "ishlatiladi — raqamni avval chatInstallments yoki chatDebtors dan oling.",
        props()
            .put("trade_id", num("Sdelka raqami. Majburiy.")),
        "trade_id");

    log.info("Chat tool'lari tayyor: {}", tools.keySet());
  }

  // --- ro'yxat -------------------------------------------------------------

  public Map<String, ToolDef> all() {
    return tools;
  }

  public ToolDef get(String name) {
    return tools.get(name);
  }

  //Cr By: Arslonbek Kulmatov
  //MCP protokoli kutadigan ko'rinish: tools/list javobidagi massiv
  public JSONArray asMcpTools() {
    JSONArray arr = new JSONArray();
    for (ToolDef t : tools.values()) {
      arr.put(new JSONObject()
          .put("name", t.name)
          .put("description", t.description)
          .put("inputSchema", t.schema));
    }
    return arr;
  }

  // --- bajarish ------------------------------------------------------------

  //Cr By: Arslonbek Kulmatov
  //Tool'ni bajarish. Chaqiruv odatdagi yo'ldan ketadi — SApp.post sessiyani
  //JWT dan o'rnatadi, ya'ni filial bo'yicha cheklov o'z-o'zidan ishlaydi va
  //so'rov core_api_log ga tushadi.
  //
  //Xato yuzaga kelsa u MATN sifatida qaytadi, istisno tashlanmaydi: model
  //xatoni o'qib boshqacha urinib ko'rishi kerak, butun suhbat yiqilmasligi
  //kerak.
  public String execute(String toolName, JSONObject args) {
    if (!tools.containsKey(toolName)) {
      return error("Bunday tool yo'q: " + toolName);
    }
    try {
      JSONObject request = new JSONObject()
          .put("method", toolName)
          .put("params", args == null ? new JSONObject() : args);

      String raw = sApp.post(request.toString(), true);
      JSONObject resp = new JSONObject(raw);

      if (!resp.optBoolean("success", false)) {
        String msg = resp.optString("message", "");
        return error(msg.isEmpty() ? "So'rov bajarilmadi." : msg);
      }
      JSONObject data = resp.optJSONObject("data");
      return data == null ? "{}" : data.toString();

    } catch (Exception e) {
      // Baza xatosining tafsiloti modelga ham, foydalanuvchiga ham kerak emas
      log.error("Chat tool xatosi [{}]: {}", toolName, e.getMessage());
      return error("Ma'lumotni olishda xato yuz berdi.");
    }
  }

  //Cr By: Arslonbek Kulmatov
  //Tool'ni TOKEN nomidan bajarish — MCP uchun.
  //
  //Farqi sessiyada: bu yerda JWT yo'q, shuning uchun sessiya filiali ham
  //yo'q va Filial_Scope NULL qaytaradi, ya'ni BARCHA filiallar ko'rinadi.
  //Shuning uchun MCP tokeni faqat boshqaruvga beriladi.
  public String executeAsToken(String toolName, JSONObject args, Long userId) {
    if (!tools.containsKey(toolName)) {
      return error("Bunday tool yo'q: " + toolName);
    }
    try {
      String body = externalApi
          .call(toolName, args == null ? new JSONObject() : args, userId)
          .getBody();

      if (body == null) {
        return error("Bo'sh javob.");
      }
      JSONObject resp = new JSONObject(body);
      if (resp.has("error")) {
        return error(resp.getJSONObject("error").optString("message", "So'rov bajarilmadi."));
      }
      return body;

    } catch (Exception e) {
      log.error("MCP tool xatosi [{}]: {}", toolName, e.getMessage());
      return error("Ma'lumotni olishda xato yuz berdi.");
    }
  }

  private String error(String message) {
    return new JSONObject().put("error", message).toString();
  }

  // --- sxema yozishni qisqartiradigan yordamchilar --------------------------

  private void add(String name, String description, JSONObject properties, String... required) {
    JSONObject schema = new JSONObject()
        .put("type", "object")
        .put("properties", properties);
    if (required.length > 0) {
      schema.put("required", new JSONArray(required));
    }
    tools.put(name, new ToolDef(name, description, schema));
  }

  private JSONObject props() {
    return new JSONObject();
  }

  private JSONObject str(String description) {
    return new JSONObject().put("type", "string").put("description", description);
  }

  private JSONObject num(String description) {
    return new JSONObject().put("type", "integer").put("description", description);
  }
}
