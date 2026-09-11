package com.example.asaka.pi.models;

import lombok.Getter;
import lombok.Setter;
import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

@Getter
@Setter
public class ReinsuranceImportResult {

  private String batchId;
  private int totalRows;
  private int insertedRows;
  private int invalidRows;
  private List<RowError> errors = new ArrayList<>();
  private JSONObject sendResult;
  private JSONObject fileResult;

  @Getter
  @Setter
  public static class RowError {
    private int rowNumber;
    private String reinsuranceContractUuid;
    private String message;

    public RowError(int rowNumber, String uuid, String message) {
      this.rowNumber = rowNumber;
      this.reinsuranceContractUuid = uuid;
      this.message = message;
    }
  }

  public void addError(int rowNumber, String uuid, String message) {
    errors.add(new RowError(rowNumber, uuid, message));
    invalidRows++;
  }

  public JSONObject toJson() {
    JSONObject o = new JSONObject();
    o.put("success", true);
    o.put("batchId", batchId);
    o.put("totalRows", totalRows);
    o.put("insertedRows", insertedRows);
    o.put("invalidRows", invalidRows);

    JSONArray errArr = new JSONArray();
    for (RowError e : errors) {
      JSONObject j = new JSONObject();
      j.put("rowNumber", e.rowNumber);
      j.put("reinsuranceContractUuid", e.reinsuranceContractUuid);
      j.put("message", e.message);
      errArr.put(j);
    }
    o.put("invalid", errArr);

    if (sendResult != null) o.put("sendResult", sendResult);
    if (fileResult != null) o.put("fileResult", fileResult);
    return o;
  }
}
