package com.example.asaka.pi.services;

import com.example.asaka.core.services.SApp;
import com.example.asaka.pi.models.ReinsuranceImportResult;
import com.example.asaka.util.DB;
import com.example.asaka.util.ExcMsg;
import com.example.asaka.util.JbSql;
import com.zaxxer.hikari.HikariDataSource;
import lombok.extern.slf4j.Slf4j;
import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.Types;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * Bulk Fond import: claim → decision → payout.
 * Front-end parses each Excel and posts rows as JSON.
 * PL/SQL keeps building the Fond payload from the row itself; this service
 * only stages the row into the right table with a batch_id, then calls the
 * matching Send_*_Batch procedure. Errors per row are captured in error_msg.
 */
@Slf4j
@Service
public class SFondBatch {

  @Autowired HikariDataSource hds;
  @Autowired SApp sApp;

  // ------------------------------------------------------------------
  // Column whitelists (exact table column names, lower_snake_case)
  // ------------------------------------------------------------------

  private static final Set<String> CLAIM_COLS = new HashSet<>(Arrays.asList(
      "polisuuid", "regionid", "areatypeid", "inheritancedocsinformation",
      "claimnumber", "claimdate", "cashorvoluntaryinsurancesum", "insurancecompensationsum",
      "applicant_person_passportdata_pinfl", "applicant_person_passportdata_seria",
      "applicant_person_passportdata_number", "applicant_person_fullname_firstname",
      "applicant_person_fullname_lastname", "applicant_person_fullname_middlename",
      "applicant_person_regionid", "applicant_person_driverlicenseseria",
      "applicant_person_driverlicensenumber", "applicant_person_gender",
      "applicant_person_birthdate", "applicant_person_address",
      "applicant_person_residenttype", "applicant_person_countryid",
      "applicant_person_phone", "applicant_person_email",
      "applicant_organization_regionid", "applicant_organization_inn",
      "applicant_organization_name", "applicant_organization_representativename",
      "applicant_organization_address", "applicant_organization_oked",
      "applicant_organization_position", "applicant_organization_phone",
      "applicant_organization_email", "applicant_organization_checkingaccount",
      "applicant_organization_ownershipformid",
      "responsiblefordamage_person_passportdata_pinfl",
      "responsiblefordamage_person_passportdata_seria",
      "responsiblefordamage_person_passportdata_number",
      "responsiblefordamage_person_fullname_firstname",
      "responsiblefordamage_person_fullname_lastname",
      "responsiblefordamage_person_fullname_middlename",
      "responsiblefordamage_person_regionid",
      "responsiblefordamage_person_driverlicenseseria",
      "responsiblefordamage_person_driverlicensenumber",
      "responsiblefordamage_person_gender", "responsiblefordamage_person_birthdate",
      "responsiblefordamage_person_address", "responsiblefordamage_person_residenttype",
      "responsiblefordamage_person_countryid", "responsiblefordamage_person_phone",
      "responsiblefordamage_person_email", "responsiblefordamage_organization_regionid",
      "responsiblefordamage_organization_inn", "responsiblefordamage_organization_name",
      "responsiblefordamage_organization_representativename",
      "responsiblefordamage_organization_address",
      "responsiblefordamage_organization_oked",
      "responsiblefordamage_organization_position",
      "responsiblefordamage_organization_phone",
      "responsiblefordamage_organization_email",
      "responsiblefordamage_organization_checkingaccount",
      "responsiblefordamage_organization_ownershipformid",
      "responsiblefordamage_regionid", "responsiblefordamage_declaredtoorganization",
      "responsiblefordamage_supervisoryauthorityconclusion_date",
      "responsiblefordamage_supervisoryauthorityconclusion_number",
      "responsiblefordamage_supervisoryauthorityconclusion_comment",
      "responsiblevehicleinfo_isforeign", "responsiblevehicleinfo_govnumber",
      "responsiblevehicleinfo_regionid", "responsiblevehicleinfo_modelcustomname",
      "responsiblevehicleinfo_vehicletypeid", "responsiblevehicleinfo_issueyear",
      "responsiblevehicleinfo_bodynumber", "responsiblevehicleinfo_liftingcapacity",
      "responsiblevehicleinfo_numberofseats", "responsiblevehicleinfo_enginenumber",
      "responsiblevehicleinfo_techpassport_seria", "responsiblevehicleinfo_techpassport_number",
      "responsiblevehicleinfo_ownerorganization_regionid",
      "responsiblevehicleinfo_ownerorganization_inn",
      "responsiblevehicleinfo_ownerorganization_name",
      "responsiblevehicleinfo_ownerorganization_representativename",
      "responsiblevehicleinfo_ownerorganization_address",
      "responsiblevehicleinfo_ownerorganization_oked",
      "responsiblevehicleinfo_ownerorganization_position",
      "responsiblevehicleinfo_ownerorganization_phone",
      "responsiblevehicleinfo_ownerorganization_checkingaccount",
      "responsiblevehicleinfo_ownerperson_passportdata_pinfl",
      "responsiblevehicleinfo_ownerperson_passportdata_seria",
      "responsiblevehicleinfo_ownerperson_passportdata_number",
      "responsiblevehicleinfo_ownerperson_fullname_firstname",
      "responsiblevehicleinfo_ownerperson_fullname_lastname",
      "responsiblevehicleinfo_ownerperson_fullname_middlename",
      "responsiblevehicleinfo_ownerperson_regionid",
      "responsiblevehicleinfo_ownerperson_driverlicenseseria",
      "responsiblevehicleinfo_ownerperson_driverlicensenumber",
      "responsiblevehicleinfo_ownerperson_gender",
      "responsiblevehicleinfo_ownerperson_birthdate",
      "responsiblevehicleinfo_ownerperson_address",
      "responsiblevehicleinfo_ownerperson_residenttype",
      "responsiblevehicleinfo_ownerperson_countryid",
      "responsiblevehicleinfo_ownerperson_phone",
      "eventcircumstances_eventdatetime", "eventcircumstances_countryid",
      "eventcircumstances_regionid", "eventcircumstances_districtid",
      "eventcircumstances_place", "eventcircumstances_eventinfo",
      "eventcircumstances_courtdecision_court",
      "eventcircumstances_courtdecision_courtdecisiondate",
      "damage_type", "damage_claimeddamage",
      "damage_person_passportdata_pinfl", "damage_person_passportdata_seria",
      "damage_person_passportdata_number", "damage_person_fullname_firstname",
      "damage_person_fullname_lastname", "damage_person_fullname_middlename",
      "damage_person_regionid", "damage_person_driverlicenseseria",
      "damage_person_driverlicensenumber", "damage_person_gender",
      "damage_person_birthdate", "damage_person_address", "damage_person_residenttype",
      "damage_person_countryid", "damage_person_phone", "damage_person_email",
      "damage_organization_regionid", "damage_organization_inn",
      "damage_organization_name", "damage_organization_representativename",
      "damage_organization_address", "damage_organization_oked",
      "damage_organization_position", "damage_organization_phone",
      "damage_organization_checkingaccount", "damage_deathcertificate",
      "damage_medicalconclusion_medicalinstitution", "damage_medicalconclusion_documentname",
      "damage_medicalconclusion_documentnumber", "damage_medicalconclusion_documentdate",
      "damage_vehicle_isforeign", "damage_vehicle_govnumber", "damage_vehicle_regionid",
      "damage_vehicle_modelcustomname", "damage_vehicle_vehicletypeid",
      "damage_vehicle_issueyear", "damage_vehicle_bodynumber",
      "damage_vehicle_liftingcapacity", "damage_vehicle_numberofseats",
      "damage_vehicle_enginenumber", "damage_vehicle_techpassport_seria",
      "damage_vehicle_techpassport_number", "damage_property",
      "damage_appraiserinn", "damage_appraiserreportnumber", "damage_appraiserreportdate",
      "insuranceorgid"
  ));

  private static final Set<String> DECISION_COLS = new HashSet<>(Arrays.asList(
      "claim_uuid", "decision_id", "rejection_reason", "payment_reason", "decision_date"
  ));

  private static final Set<String> PAYOUT_COLS = new HashSet<>(Arrays.asList(
      "decision_uuid", "type", "payment_sum", "payment_date",
      "payment_order_number", "recipient", "inheritance_document_number"
  ));

  // ------------------------------------------------------------------
  // Public entry points
  // ------------------------------------------------------------------

  public JSONObject importClaim(String jsonData) throws Exception {
    // damage_type ham majburiy: Generate_Damage() butunlay shu ustunga qarab
    // shoxlanadi, u bo'sh bo'lsa 'null' qaytarib JSON'ni buzadi.
    return runImport(jsonData, "PI_FOND_CLAIMS",
        CLAIM_COLS, Arrays.asList("polisuuid", "damage_type"),
        "Pi_Insurance_Service.Send_Claim_Batch");
  }

  public JSONObject importDecision(String jsonData) throws Exception {
    return runImport(jsonData, "PI_FOND_DECISIONS",
        DECISION_COLS, Arrays.asList("claim_uuid"),
        "Pi_Insurance_Service.Send_Decision_Batch");
  }

  public JSONObject importPayout(String jsonData) throws Exception {
    return runImport(jsonData, "PI_FOND_PAYOUTS",
        PAYOUT_COLS, Arrays.asList("decision_uuid"),
        "Pi_Insurance_Service.Send_Payout_Batch");
  }

  // ------------------------------------------------------------------
  // Core pipeline
  // ------------------------------------------------------------------

  private JSONObject runImport(String jsonData, String table, Set<String> cols,
                               List<String> requiredCols, String batchProc) throws Exception {
    if (jsonData == null || jsonData.isBlank()) {
      throw new IllegalArgumentException("data (JSON) is required.");
    }

    ReinsuranceImportResult result = new ReinsuranceImportResult();
    result.setBatchId(UUID.randomUUID().toString());

    List<Map<String, String>> rows = parseRows(jsonData, cols);
    result.setTotalRows(rows.size());

    Connection conn = DB.con(hds);
    JSONObject res = new JSONObject();
    res.put("success", true);
    try {
      sApp.setDbSession(conn);
      Long userId = getCurrentUserId(conn);

      for (int i = 0; i < rows.size(); i++) {
        Map<String, String> row = rows.get(i);
        int rowNumber = i + 1;
        String err = null;
        for (String req : requiredCols) {
          if (!row.containsKey(req) || row.get(req) == null) {
            err = req + " is empty";
            break;
          }
        }
        insertRow(conn, table, result.getBatchId(), userId, row, err);
        result.setInsertedRows(result.getInsertedRows() + 1);
        if (err != null) {
          result.addError(rowNumber, row.get(requiredCols.get(0)), err);
        }
      }

      if (result.getInsertedRows() > 0) {
        result.setSendResult(callBatchProc(conn, batchProc, result.getBatchId()));
      }

      return result.toJson();
    } catch (Exception e) {
      log.error("{} import failed", table, e);
      ExcMsg.call(res, e, conn);
      return res;
    } finally {
      DB.done(conn);
    }
  }

  // ------------------------------------------------------------------
  // JSON parsing
  // ------------------------------------------------------------------

  private List<Map<String, String>> parseRows(String jsonData, Set<String> cols) {
    JSONObject root = new JSONObject(jsonData);
    JSONArray arr;
    if (root.has("rows")) arr = root.getJSONArray("rows");
    else if (jsonData.trim().startsWith("[")) arr = new JSONArray(jsonData);
    else throw new IllegalArgumentException("JSON must contain a 'rows' array.");

    List<Map<String, String>> out = new ArrayList<>();
    for (int i = 0; i < arr.length(); i++) {
      JSONObject o = arr.getJSONObject(i);
      Map<String, String> m = new LinkedHashMap<>();
      for (String key : o.keySet()) {
        if (o.isNull(key)) continue;
        String normalized = normalizeKey(key, cols);
        if (!cols.contains(normalized)) {
          // Aks holda noto'g'ri sarlavha jimgina yo'qoladi va jadvalda bo'sh
          // ustun qoladi — shuning uchun logga yozamiz.
          log.warn("Fond batch: '{}' ustuni tanilmadi (normalized='{}'), qator #{} da tashlab yuborildi",
              key, normalized, i + 1);
          continue;
        }
        String v = String.valueOf(o.get(key)).trim();
        if (v.isEmpty()) continue;
        m.put(normalized, v);
      }
      if (!m.isEmpty()) out.add(m);
    }
    return out;
  }

  /**
   * Excel sarlavhasini jadval ustuni nomiga o'giradi.
   *
   * Asosiy qoida: nuqta -> pastki chiziq, "[]" va probel olib tashlanadi,
   * hammasi kichik harfga o'tadi. camelCase so'zlari AJRATILMAYDI
   * ("applicant.person.passportData.pinfl" -> "applicant_person_passportdata_pinfl",
   * "polisUuid" -> "polisuuid"), chunki Ariza jadvalining ustunlari aynan
   * shunday nomlangan.
   *
   * Agar natija jadvalda topilmasa, {@link #KEY_ALIASES} bo'yicha qaraladi.
   * Aniq mos kelgan ustun har doim aliasdan ustun turadi.
   */
  private String normalizeKey(String k, Set<String> cols) {
    String n = k.toLowerCase(Locale.ROOT)
        .replace(".", "_")
        .replace("[]", "")
        .replace(" ", "");
    if (cols.contains(n)) return n;
    return KEY_ALIASES.getOrDefault(n, n);
  }

  /**
   * Shablon sarlavhasi jadval ustuni nomiga mos kelmaydigan holatlar.
   *
   * Ariza shablonida deyarli hamma sarlavha ustun nomi bilan bir xil (160 tadan
   * faqat damageType farq qiladi), lekin Qaror va To'lov shablonlari butunlay
   * boshqa nomlashdan foydalanadi — ular Fond API maydonlari nomi bilan
   * yozilgan, jadval ustunlari esa lower_snake_case.
   */
  private static final Map<String, String> KEY_ALIASES = Map.ofEntries(
      // --- Ariza (PI_FOND_CLAIMS) ---
      Map.entry("damagetype",                       "damage_type"),
      // --- Qaror (PI_FOND_DECISIONS) ---
      Map.entry("claimuuid",                        "claim_uuid"),
      Map.entry("decision_decisionid",              "decision_id"),
      Map.entry("decision_rejectionreason",         "rejection_reason"),
      Map.entry("decision_reasonforpayment",        "payment_reason"),
      Map.entry("decisiondate",                     "decision_date"),
      // --- To'lov (PI_FOND_PAYOUTS) ---
      Map.entry("decisionuuid",                     "decision_uuid"),
      Map.entry("payoutsum",                        "payment_sum"),
      Map.entry("payoutdate",                       "payment_date"),
      Map.entry("paymentordernumber",               "payment_order_number"),
      Map.entry("inheritancedocumentnumberanddate", "inheritance_document_number"));

  // ------------------------------------------------------------------
  // Dynamic INSERT
  // ------------------------------------------------------------------

  private void insertRow(Connection conn, String table, String batchId, Long userId,
                         Map<String, String> row, String errorMsg) throws Exception {
    List<String> colNames = new ArrayList<>();
    List<String> placeholders = new ArrayList<>();
    List<Object> values = new ArrayList<>();

    colNames.add("batch_id");         placeholders.add("?"); values.add(batchId);
    colNames.add("cr_by");            placeholders.add("?"); values.add(userId);
    colNames.add("cr_on");            placeholders.add("sysdate");
    if (errorMsg != null) {
      colNames.add("error_msg");      placeholders.add("?"); values.add(truncate(errorMsg, 4000));
    }
    for (Map.Entry<String, String> e : row.entrySet()) {
      colNames.add(e.getKey());
      placeholders.add("?");
      values.add(e.getValue());
    }

    String sql = "Insert Into " + table + " (" + String.join(", ", colNames) + ") " +
                 "Values (" + String.join(", ", placeholders) + ")";

    try (PreparedStatement ps = conn.prepareStatement(sql)) {
      int idx = 1;
      for (Object v : values) {
        if (v == null) ps.setNull(idx++, Types.VARCHAR);
        else if (v instanceof Long) ps.setLong(idx++, (Long) v);
        else ps.setString(idx++, String.valueOf(v));
      }
      ps.executeUpdate();
    }
  }

  private String truncate(String s, int max) {
    return s == null || s.length() <= max ? s : s.substring(0, max);
  }

  // ------------------------------------------------------------------
  // Batch procedure call
  // ------------------------------------------------------------------

  private JSONObject callBatchProc(Connection conn, String proc, String batchId) {
    try {
      JbSql sql = new JbSql(proc, conn, false);
      sql.addParam(batchId, 1);
      sql.addOut(Types.CLOB, 2);
      sql.exec();
      String out = (String) sql.getOutVal(2);
      return out == null ? new JSONObject().put("batchId", batchId).put("sent", 0)
                         : new JSONObject(out);
    } catch (Exception e) {
      log.error("{} failed", proc, e);
      JSONObject o = new JSONObject();
      o.put("batchId", batchId);
      o.put("error", e.getMessage());
      return o;
    }
  }

  private Long getCurrentUserId(Connection conn) {
    try (PreparedStatement ps = conn.prepareStatement(
        "Select Core_Session.Get_User_Id From Dual");
         java.sql.ResultSet rs = ps.executeQuery()) {
      if (rs.next()) {
        String v = rs.getString(1);
        return v == null ? null : Long.parseLong(v);
      }
    } catch (Exception e) {
      log.warn("cannot read Core_Session.Get_User_Id: {}", e.getMessage());
    }
    return null;
  }
}
