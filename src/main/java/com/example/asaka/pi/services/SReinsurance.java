package com.example.asaka.pi.services;

import com.example.asaka.core.services.SApp;
import com.example.asaka.pi.models.ReinsuranceImportResult;
import com.example.asaka.util.DB;
import com.example.asaka.util.ExcMsg;
import com.example.asaka.util.JbSql;
import com.zaxxer.hikari.HikariDataSource;
import lombok.extern.slf4j.Slf4j;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.CellType;
import org.apache.poi.ss.usermodel.DateUtil;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.Types;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import java.util.regex.Pattern;

/**
 * Bulk import for reinsurance rows submitted through the web.
 * Excel + PDF documents in, batch inserted into PI_FOND_REINSURANCES,
 * then PI_INSURANCE_SERVICE.Send_Reinsurance_Batch and
 * Send_Reinsurance_File_Batch are called for that batch only.
 */
@Slf4j
@Service
public class SReinsurance {

  private static final Path FILES_DIR = Paths.get("/opt/monello71/files/").toAbsolutePath().normalize();

  private static final Pattern UUID_RE =
      Pattern.compile("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$");

  private static final String[] COLUMNS = {
      "reinsuranceContractUuid",
      "currencyId",
      "exchangeRate",
      "totalDamageSum",
      "totalDamageInForeignCurrency",
      "totalSharePaymentSum",
      "totalSharePaymentInForeignCurrency",
      "claimUuid",
      "contractNumber",
      "claimNumber",
      "claimDate",
      "decisionDate",
      "paymentDate",
      "paymentAmountSum",
      "paymentAmountInForeignCurrency",
      "insuranceCompensationSum",
      "insuranceCompensationInForeignCurrency",
      "sharePaymentSum",
      "sharePaymentInForeignCurrency",
      "eventDateTime",
      "regionId",
      "countryId",
      "districtId",
      "place",
      "eventInfo"
  };

  private static final String INSERT_SQL =
      "Insert Into Pi_Fond_Reinsurances (" +
          "batch_id, cr_by, cr_on, error_msg, " +
          "reinsurance_contract_uuid, currency_id, exchange_rate, " +
          "total_damages_sum, total_damage_in_foreign_currency, " +
          "total_share_payment_sum, total_share_payment_in_foreign_currency, " +
          "claim_uuid, contract_number, claim_number, " +
          "claim_date, decision_date, payment_date, " +
          "payment_amount_sum, payment_amount_in_foreign_currency, " +
          "insurance_compensation_sum, insurance_compensation_in_foreign_currency, " +
          "share_payment_sum, share_payment_in_foreign_currency, " +
          "event_date_time, region_id, country_id, district_id, place" +
          ") Values (" +
          "?, ?, sysdate, ?, " +
          "?, ?, ?, " +
          "?, ?, " +
          "?, ?, " +
          "?, ?, ?, " +
          "?, ?, ?, " +
          "?, ?, " +
          "?, ?, " +
          "?, ?, " +
          "?, ?, ?, ?, ?" +
          ")";

  @Autowired HikariDataSource hds;
  @Autowired SApp sApp;

  public JSONObject importBatch(MultipartFile excel, MultipartFile[] documents) throws Exception {
    if (excel == null || excel.isEmpty()) {
      throw new IllegalArgumentException("Excel file is required.");
    }

    ReinsuranceImportResult result = new ReinsuranceImportResult();
    result.setBatchId(UUID.randomUUID().toString());

    List<Map<String, String>> rows = parseExcel(excel);
    result.setTotalRows(rows.size());

    Map<String, MultipartFile> docsByUuid = indexDocumentsByUuid(documents);

    Connection conn = DB.con(hds);
    JSONObject res = new JSONObject();
    res.put("success", true);
    try {
      sApp.setDbSession(conn);
      Long userId = getCurrentUserId(conn);

      List<Map<String, String>> validRows = new ArrayList<>();
      List<Integer> validIndexes = new ArrayList<>();

      for (int i = 0; i < rows.size(); i++) {
        Map<String, String> row = rows.get(i);
        int excelRow = i + 2;
        String uuid = row.get("reinsuranceContractUuid");
        String err = validateRow(row, docsByUuid);
        if (err == null) {
          validRows.add(row);
          validIndexes.add(excelRow);
        } else {
          insertInvalidRow(conn, result.getBatchId(), userId, row, err);
          result.addError(excelRow, uuid, err);
          result.setInsertedRows(result.getInsertedRows() + 1);
        }
      }

      for (int k = 0; k < validRows.size(); k++) {
        Map<String, String> row = validRows.get(k);
        insertValidRow(conn, result.getBatchId(), userId, row);
        result.setInsertedRows(result.getInsertedRows() + 1);
      }

      saveFiles(validRows, docsByUuid);

      if (!validRows.isEmpty()) {
        result.setSendResult(callBatchProc(conn, "Pi_Insurance_Service.Send_Reinsurance_Batch",
            result.getBatchId()));
        result.setFileResult(callBatchProc(conn, "Pi_Insurance_Service.Send_Reinsurance_File_Batch",
            result.getBatchId()));
      }

      return result.toJson();
    } catch (Exception e) {
      log.error("importBatch failed", e);
      ExcMsg.call(res, e, conn);
      return res;
    } finally {
      DB.done(conn);
    }
  }

  // --- Excel parsing --------------------------------------------------------

  private List<Map<String, String>> parseExcel(MultipartFile excel) throws Exception {
    List<Map<String, String>> out = new ArrayList<>();
    try (InputStream is = excel.getInputStream();
         XSSFWorkbook wb = new XSSFWorkbook(is)) {

      Sheet sheet = wb.getSheetAt(0);
      if (sheet == null) return out;

      int lastRow = sheet.getLastRowNum();
      for (int r = 1; r <= lastRow; r++) {
        Row row = sheet.getRow(r);
        if (row == null) continue;

        boolean allBlank = true;
        Map<String, String> m = new HashMap<>();
        for (int c = 0; c < COLUMNS.length; c++) {
          String val = cellString(row.getCell(c));
          if (val != null && !val.isEmpty()) allBlank = false;
          m.put(COLUMNS[c], val);
        }
        if (allBlank) continue;
        out.add(m);
      }
    }
    return out;
  }

  private String cellString(Cell cell) {
    if (cell == null) return null;
    CellType type = cell.getCellTypeEnum();
    if (type == CellType.STRING) {
      return safeTrim(cell.getStringCellValue());
    }
    if (type == CellType.NUMERIC) {
      if (DateUtil.isCellDateFormatted(cell)) {
        return DateUtil.getJavaDate(cell.getNumericCellValue()).toString();
      }
      double d = cell.getNumericCellValue();
      if (d == Math.floor(d) && !Double.isInfinite(d)) {
        return String.format(Locale.US, "%.0f", d);
      }
      return String.format(Locale.US, "%s", d);
    }
    if (type == CellType.BOOLEAN) {
      return Boolean.toString(cell.getBooleanCellValue());
    }
    if (type == CellType.FORMULA) {
      try {
        return safeTrim(cell.getStringCellValue());
      } catch (Exception e) {
        return String.valueOf(cell.getNumericCellValue());
      }
    }
    return null;
  }

  private String safeTrim(String s) {
    if (s == null) return null;
    String t = s.trim();
    return t.isEmpty() ? null : t;
  }

  // --- Validation -----------------------------------------------------------

  private String validateRow(Map<String, String> row, Map<String, MultipartFile> docsByUuid) {
    String uuid = row.get("reinsuranceContractUuid");
    if (uuid == null) {
      return "reinsuranceContractUuid is empty";
    }
    if (!UUID_RE.matcher(uuid).matches()) {
      return "reinsuranceContractUuid is not a valid UUID";
    }
    if (!docsByUuid.containsKey(uuid.toLowerCase(Locale.ROOT))) {
      return "PDF document '" + uuid + ".pdf' was not uploaded";
    }
    if (row.get("totalDamageSum") == null) {
      return "totalDamageSum is empty";
    }
    if (row.get("totalSharePaymentSum") == null) {
      return "totalSharePaymentSum is empty";
    }
    return null;
  }

  private Map<String, MultipartFile> indexDocumentsByUuid(MultipartFile[] docs) {
    Map<String, MultipartFile> out = new HashMap<>();
    if (docs == null) return out;
    for (MultipartFile f : docs) {
      if (f == null || f.isEmpty()) continue;
      String name = f.getOriginalFilename();
      if (name == null) continue;
      String base = name.toLowerCase(Locale.ROOT);
      int slash = Math.max(base.lastIndexOf('/'), base.lastIndexOf('\\'));
      if (slash >= 0) base = base.substring(slash + 1);
      if (base.endsWith(".pdf")) {
        base = base.substring(0, base.length() - 4);
      }
      if (UUID_RE.matcher(base).matches()) {
        out.put(base, f);
      }
    }
    return out;
  }

  // --- File saving ----------------------------------------------------------

  private void saveFiles(List<Map<String, String>> validRows,
                         Map<String, MultipartFile> docsByUuid) throws Exception {
    Files.createDirectories(FILES_DIR);
    for (Map<String, String> row : validRows) {
      String uuid = row.get("reinsuranceContractUuid");
      MultipartFile f = docsByUuid.get(uuid.toLowerCase(Locale.ROOT));
      Path target = FILES_DIR.resolve(uuid + ".pdf").normalize();
      if (!target.startsWith(FILES_DIR)) {
        throw new SecurityException("Invalid target path");
      }
      try (InputStream is = f.getInputStream()) {
        Files.copy(is, target, StandardCopyOption.REPLACE_EXISTING);
      }
    }
  }

  // --- Insert ---------------------------------------------------------------

  private void insertValidRow(Connection conn, String batchId, Long userId,
                              Map<String, String> row) throws Exception {
    insertRow(conn, batchId, userId, row, null);
  }

  private void insertInvalidRow(Connection conn, String batchId, Long userId,
                                Map<String, String> row, String errorMsg) throws Exception {
    insertRow(conn, batchId, userId, row, errorMsg);
  }

  private void insertRow(Connection conn, String batchId, Long userId,
                         Map<String, String> row, String errorMsg) throws Exception {
    try (PreparedStatement ps = conn.prepareStatement(INSERT_SQL)) {
      int i = 1;
      ps.setString(i++, batchId);
      if (userId == null) ps.setNull(i++, Types.NUMERIC);
      else ps.setLong(i++, userId);
      if (errorMsg == null) ps.setNull(i++, Types.VARCHAR);
      else ps.setString(i++, truncate(errorMsg, 4000));

      ps.setString(i++, row.get("reinsuranceContractUuid"));
      ps.setString(i++, row.get("currencyId"));
      ps.setString(i++, row.get("exchangeRate"));

      ps.setString(i++, row.get("totalDamageSum"));
      ps.setString(i++, row.get("totalDamageInForeignCurrency"));

      ps.setString(i++, row.get("totalSharePaymentSum"));
      ps.setString(i++, row.get("totalSharePaymentInForeignCurrency"));

      ps.setString(i++, row.get("claimUuid"));
      ps.setString(i++, row.get("contractNumber"));
      ps.setString(i++, row.get("claimNumber"));

      ps.setString(i++, row.get("claimDate"));
      ps.setString(i++, row.get("decisionDate"));
      ps.setString(i++, row.get("paymentDate"));

      ps.setString(i++, row.get("paymentAmountSum"));
      ps.setString(i++, row.get("paymentAmountInForeignCurrency"));

      ps.setString(i++, row.get("insuranceCompensationSum"));
      ps.setString(i++, row.get("insuranceCompensationInForeignCurrency"));

      ps.setString(i++, row.get("sharePaymentSum"));
      ps.setString(i++, row.get("sharePaymentInForeignCurrency"));

      ps.setString(i++, row.get("eventDateTime"));
      ps.setString(i++, row.get("regionId"));
      ps.setString(i++, row.get("countryId"));
      ps.setString(i++, row.get("districtId"));
      ps.setString(i, row.get("place"));

      ps.executeUpdate();
      conn.commit();
    }
  }

  private String truncate(String s, int max) {
    if (s == null) return null;
    return s.length() <= max ? s : s.substring(0, max);
  }

  // --- Batch procedure calls ------------------------------------------------

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

  // --- Current user (from JWT session already set on connection) -----------

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
