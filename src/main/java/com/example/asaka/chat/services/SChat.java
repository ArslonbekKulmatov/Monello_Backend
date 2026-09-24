package com.example.asaka.chat.services;

import com.anthropic.client.AnthropicClient;
import com.anthropic.client.okhttp.AnthropicOkHttpClient;
import com.anthropic.helpers.BetaToolRunner;
import com.anthropic.models.beta.messages.BetaMessage;
import com.anthropic.models.beta.messages.MessageCreateParams;
import com.example.asaka.chat.ChatToolCatalog;
import com.example.asaka.chat.ChatTools;
import lombok.extern.slf4j.Slf4j;
import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.annotation.PostConstruct;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

//Cr By: Arslonbek Kulmatov
//Chat: savolni modelga berib, u so'ragan tool'larni bajarib, javobni qaytaradi.
//
//Loop'ni SDK ning Tool Runner'i boshqaradi. Qo'lda yozilgan loop'da assistant
//javobini keyingi so'rovga qaytarib qo'yish kerak bo'ladi va o'ylash bloklari
//aynan saqlanishi shart — Tool Runner shuni o'zi qiladi.
@Slf4j
@Service
public class SChat {

  // Maksimal tarix. Chat savol-javob uchun, tergov uchun emas: uzun tarix
  // har so'rovni qimmatlashtiradi, foydasi esa kam.
  private static final int MAX_HISTORY = 12;

  @Value("${anthropic.api-key:}")
  private String apiKey;

  @Value("${anthropic.model:claude-opus-5}")
  private String model;

  @Autowired private ChatToolCatalog catalog;

  private AnthropicClient client;

  @PostConstruct
  void init() {
    if (apiKey == null || apiKey.trim().isEmpty()) {
      log.warn("anthropic.api-key berilmagan — chat o'chirilgan holatda ishga tushdi");
      return;
    }
    client = AnthropicOkHttpClient.builder().apiKey(apiKey.trim()).build();
    install(catalog);
  }

  public boolean isEnabled() {
    return client != null;
  }

  //Cr By: Arslonbek Kulmatov
  //Ko'prikni to'ldirish. ChatToolBridge.install paket darajasida ko'rinadi,
  //shuning uchun refleksiya orqali chaqiriladi — bridge'ni ochiq qilib
  //qo'ymaslik uchun.
  private void install(ChatToolCatalog value) {
    try {
      Class<?> bridge = Class.forName("com.example.asaka.chat.ChatToolBridge");
      Method m = bridge.getDeclaredMethod("install", ChatToolCatalog.class);
      m.setAccessible(true);
      m.invoke(null, value);
    } catch (Exception e) {
      log.error("Chat ko'prigini o'rnatib bo'lmadi: {}", e.getMessage());
    }
  }

  //Cr By: Arslonbek Kulmatov
  //Modelga beriladigan qoidalar.
  //
  //Eng muhimi ikkinchi qoida: model raqamni o'zi o'ylab topmasligi kerak.
  //Qarzdorlik ma'lumotida taxmin qilingan raqam xato javobdan yomonroq —
  //unga ishoniladi.
  private String systemPrompt() {
    return String.join("\n",
        "Sen Monello ichki tizimining yordamchisisan. Monello — nasiya savdo "
            + "(rassrochka) tizimi: telefon, moshina va boshqa tovarlarni bo'lib to'lashga beradi.",
        "",
        "QOIDALAR",
        "1. Javobni foydalanuvchi qaysi tilda so'rasa, o'sha tilda ber. Sukut bo'yicha o'zbekcha.",
        "2. Raqamlarni FAQAT tool javoblaridan ol. Hech qachon o'zingdan raqam "
            + "to'qima va taxmin qilma. Ma'lumot yetmasa — shuni ayt.",
        "3. Barcha summalar DOLLARDA. Javobda ham dollarda ber va valyutani yoz.",
        "4. Tool bo'sh ro'yxat qaytarsa, bu \"ma'lumot yo'q\" degani — \"xato\" degani emas.",
        "5. Tool javobida \"note\" maydoni bo'lsa, uni foydalanuvchiga ham aytib o't: "
            + "u odatda ro'yxat qisqartirilganini bildiradi.",
        "6. Javob qisqa bo'lsin. Ro'yxat so'ralsa jadval yoki punktlar bilan ber, "
            + "umumiy savolga bir-ikki jumla bilan javob ber.",
        "7. Sen faqat O'QIY olasan. Kimdir biror narsani o'zgartirishni, o'chirishni "
            + "yoki to'lov kiritishni so'rasa — buni qila olmasligingni ayt.",
        "",
        "QAMROV",
        "Ko'rsatilgan ma'lumot foydalanuvchining filiali bilan cheklangan. Tool "
            + "javobidagi \"scope\" maydoni buni aytadi. Agar foydalanuvchi boshqa "
            + "filial haqida so'rasa va javobda u yo'q bo'lsa — uning huquqi "
            + "faqat o'z filialiga yetishini tushuntir.",
        "",
        "SHAXSIY MA'LUMOT",
        "Mijozning telefon raqami, PINFL va manzili senga umuman berilmaydi. "
            + "Ular so'ralsa — bu ma'lumot chatda mavjud emasligini ayt.");
  }

  //Cr By: Arslonbek Kulmatov
  //Savolga javob berish.
  //
  //iHistory: [{"role":"user"|"assistant","text":"..."}] — oldingi navbatlar.
  //Faqat MATN saqlanadi: har savol o'z tool loop'ini boshidan boshlaydi,
  //shuning uchun oldingi tool chaqiruvlarini qaytarib yuborish shart emas.
  public JSONObject ask(String question, JSONArray history) {
    JSONObject out = new JSONObject();

    if (!isEnabled()) {
      return out.put("ok", false)
                .put("error", "Chat sozlanmagan: anthropic.api-key berilmagan.");
    }
    if (question == null || question.trim().isEmpty()) {
      return out.put("ok", false).put("error", "Savol bo'sh.");
    }

    try {
      MessageCreateParams.Builder params = MessageCreateParams.builder()
          .model(model)
          .maxTokens(8000L)
          .system(systemPrompt())
          // Tool Runner beta helper'i shu sarlavhani talab qiladi
          .putAdditionalHeader("anthropic-beta", "structured-outputs-2025-11-13")
          .addTool(ChatTools.Filials.class)
          .addTool(ChatTools.Sales.class)
          .addTool(ChatTools.Installments.class)
          .addTool(ChatTools.Debtors.class)
          .addTool(ChatTools.Trade.class);

      appendHistory(params, history);
      params.addUserMessage(question.trim());

      BetaToolRunner runner = client.beta().messages().toolRunner(params.build());

      Set<String> toolsUsed = new LinkedHashSet<>();
      List<String> answer = new ArrayList<>();

      for (BetaMessage message : runner) {
        answer.clear();
        message.content().forEach(block -> {
          block.text().ifPresent(t -> answer.add(t.text()));
          block.toolUse().ifPresent(t -> toolsUsed.add(t.name()));
        });
      }

      out.put("ok", true);
      out.put("answer", String.join("\n", answer).trim());
      out.put("tools_used", new JSONArray(toolsUsed));
      return out;

    } catch (Exception e) {
      // Model xatosining tafsiloti foydalanuvchiga kerak emas, logda qoladi
      log.error("Chat xatosi: {}", e.getMessage(), e);
      return out.put("ok", false)
                .put("error", "Javob olishda xato yuz berdi. Keyinroq urinib ko'ring.");
    }
  }

  //Cr By: Arslonbek Kulmatov
  //Tarixni so'rovga qo'shish. Oxirgi MAX_HISTORY ta navbat olinadi.
  private void appendHistory(MessageCreateParams.Builder params, JSONArray history) {
    if (history == null || history.length() == 0) {
      return;
    }
    int from = Math.max(0, history.length() - MAX_HISTORY);
    for (int i = from; i < history.length(); i++) {
      JSONObject turn = history.optJSONObject(i);
      if (turn == null) {
        continue;
      }
      String text = turn.optString("text", "").trim();
      if (text.isEmpty()) {
        continue;
      }
      if ("assistant".equalsIgnoreCase(turn.optString("role"))) {
        params.addAssistantMessage(text);
      } else {
        params.addUserMessage(text);
      }
    }
  }
}
