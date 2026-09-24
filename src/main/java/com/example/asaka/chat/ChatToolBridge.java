package com.example.asaka.chat;

import org.json.JSONObject;

//Cr By: Arslonbek Kulmatov
//Anthropic SDK tool klasslarini O'ZI yaratadi (Jackson orqali), shuning uchun
//ularga Spring bean'ini inject qilib bo'lmaydi. Ko'prik shu bo'shliqni
//to'ldiradi: SChat ishga tushganda katalogni shu yerga qo'yadi, tool klasslar
//esa shu yerdan oladi.
//
//Boshqa yo'li yo'q emas — tool'larni ro'yxat asosida dinamik yasash mumkin
//edi, lekin SDK tool'ni klass sifatida kutadi.
public final class ChatToolBridge {

  private static volatile ChatToolCatalog catalog;

  private ChatToolBridge() {
  }

  static void install(ChatToolCatalog value) {
    catalog = value;
  }

  //Cr By: Arslonbek Kulmatov
  //Tool'ni bajarish. Bo'sh parametrlar yuborilmaydi — PL/SQL tomonda
  //"kelmagan" va "bo'sh kelgan" bir xil ishlov olishi uchun.
  static String call(String toolName, Object... keyValues) {
    ChatToolCatalog c = catalog;
    if (c == null) {
      return new JSONObject().put("error", "Chat katalogi hali tayyor emas.").toString();
    }
    JSONObject args = new JSONObject();
    for (int i = 0; i + 1 < keyValues.length; i += 2) {
      Object v = keyValues[i + 1];
      if (v == null) {
        continue;
      }
      if (v instanceof String && ((String) v).trim().isEmpty()) {
        continue;
      }
      args.put(String.valueOf(keyValues[i]), v);
    }
    return c.execute(toolName, args);
  }
}
