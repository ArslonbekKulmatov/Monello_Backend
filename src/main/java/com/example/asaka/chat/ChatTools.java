package com.example.asaka.chat;

import com.fasterxml.jackson.annotation.JsonClassDescription;
import com.fasterxml.jackson.annotation.JsonPropertyDescription;

import java.util.function.Supplier;

//Cr By: Arslonbek Kulmatov
//Anthropic SDK uchun tool klasslari.
//
//SDK sxemani shu klasslarning maydonlaridan yasaydi, shuning uchun maydon
//nomlari Ipt_Chat kutadigan parametr nomlari bilan AYNAN bir xil bo'lishi
//kerak.
//
//Ta'riflar ChatToolCatalog dagi bilan bir xil ma'noda: u yerdagisi MCP
//mijozlari uchun, bu yerdagisi SDK uchun.
public final class ChatTools {

  private ChatTools() {
  }

  @JsonClassDescription(
      "Filiallar ro'yxati va ularning joriy holati: har filialda nechta faol "
      + "sdelka, nechta mijoz va omborda nechta tovar bor.")
  public static class Filials implements Supplier<String> {
    @Override
    public String get() {
      return ChatToolBridge.call("chatFilials");
    }
  }

  @JsonClassDescription(
      "Savdolar: davr bo'yicha sdelkalar soni va summasi, filial kesimida. "
      + "Bekor qilingan va qaytarilgan sdelkalar soni ham qaytadi.")
  public static class Sales implements Supplier<String> {
    @JsonPropertyDescription("Davr boshi, YYYY-MM-DD. Berilmasa joriy oy boshi.")
    public String date_from;

    @JsonPropertyDescription("Davr oxiri, YYYY-MM-DD. Berilmasa bugun.")
    public String date_to;

    @Override
    public String get() {
      return ChatToolBridge.call("chatSales", "date_from", date_from, "date_to", date_to);
    }
  }

  @JsonClassDescription(
      "Faol rassrochkalar ro'yxati: mijoz, tovar, oylik to'lov, qolgan qarz va "
      + "kechikish kuni. client_name berilsa faqat o'sha mijozning sdelkalari qaytadi.")
  public static class Installments implements Supplier<String> {
    @JsonPropertyDescription("Mijoz ismining bir qismi. Registr muhim emas.")
    public String client_name;

    @Override
    public String get() {
      return ChatToolBridge.call("chatInstallments", "client_name", client_name);
    }
  }

  @JsonClassDescription(
      "Qarzdorlar: kechikkan sdelkalar ro'yxati, eng uzoq kechikkanidan boshlab. "
      + "Jami qarzdorlar soni va umumiy kechikkan summa ham qaytadi.")
  public static class Debtors implements Supplier<String> {
    @JsonPropertyDescription("Eng kam kechikish kuni. Sukut bo'yicha 1.")
    public Integer min_days;

    @Override
    public String get() {
      return ChatToolBridge.call("chatDebtors", "min_days", min_days);
    }
  }

  @JsonClassDescription(
      "Bitta sdelkaning shartlari va to'lov grafigi: har oyning summasi, "
      + "to'langan-to'lanmagani va muddati. Sdelka raqamini avval "
      + "chatInstallments yoki chatDebtors dan oling.")
  public static class Trade implements Supplier<String> {
    @JsonPropertyDescription("Sdelka raqami. Majburiy.")
    public Long trade_id;

    @Override
    public String get() {
      return ChatToolBridge.call("chatTrade", "trade_id", trade_id);
    }
  }
}
