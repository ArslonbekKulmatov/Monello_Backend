package com.example.asaka.core.models;

import com.example.asaka.util.DB;
import com.example.asaka.util.JbUtil;
import lombok.Data;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import org.springframework.web.context.annotation.SessionScope;

import javax.servlet.http.HttpServletRequest;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

@SessionScope
@Data
public class Grid_New {
    private Integer grid_id;
    private Integer pageSize = 20;
    private String view;
    private String page_json;
    private String columns_json;
    private String filter_json;
    private boolean hasFilter;
    private boolean filterHasValue;
    private HttpServletRequest httpServletRequest;

    //Cr By: Arslonbek Kulmatov
    public Long setRowCount(JSONObject grid, Connection conn, JSONArray filters, String params) {
        Long rows = 0L;
        PreparedStatement ps = null;
        ResultSet rs = null;
        try {
            ps = conn.prepareStatement("SELECT COUNT(*) FROM " + view + getWhere(grid, filters, params));
            ps.execute();
            rs = ps.getResultSet();
            if (rs.next())
                rows = rs.getLong(1);
        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            DB.done(rs);
            DB.done(ps);
        }
        return rows;
    }

    //Cr By: Arslonbek Kulmatov
    public String getSql(JSONObject grid, JSONArray filters, String params, Long rowCount) throws JSONException {
        JSONObject json = new JSONObject(params);
        Integer page = json.getInt("page");
        Integer pageSize = json.isNull("pageSize") ? grid.getInt("pageSize") : json.getInt("pageSize");
        Integer start = !page.equals(1) ? ((page - 1) * pageSize + 1) : 1;
        Integer end = pageSize + start - 1;
        String view = getView();
        String sql = "Select ";
        JSONArray cols = grid.getJSONArray("cols");
        for (int i = 0; i < cols.length(); i++) {
            JSONObject col = cols.getJSONObject(i);
            String colName = col.getString("name");
            String colNum = col.getString("num");
            sql += colName + " " + colNum + ",";
        }
        return sql.substring(0, sql.length() - 1) + " From (Select a.*, ROWNUM rnum From (Select * From " + view + getWhere(grid, filters, params) + getOrder(grid, params) + ") a Where Rownum <= " + end + ") Where rnum >= " + start;
    }

    //Cr By: Arslonbek Kulmatov
    public String getWhere(JSONObject grid, JSONArray filters, String params) throws JSONException {
        JSONObject json = new JSONObject(params);
        String wh = grid.isNull("wh") ? "" : grid.getString("wh");
        String whPar = json.isNull("wh") ? "" : json.getString("wh");
        String str = !"".equals(wh) ? " Where " + wh : "";
        // Agar fayldan tashqarida global where bo'lsa
        str = !"".equals(whPar) ? (!"".equals(str) ? str + " And " + whPar : " Where " + whPar) : str;
        String fltr = "";
        if (filters != null) {
            for (int i = 0; i < filters.length(); i++) {
                JSONObject col = filters.getJSONObject(i);
                String colName = col.getString("name");
//				boolean hasFilter = col.isNull("hasFilter") ? false : col.getBoolean("hasFilter");
                String filterType = col.getString("type");
                String filterValue = "";
                if(filterType.equals("CHECKBOX")){
                    filterValue = JbUtil.nvl(col.isNull("filterValue") ? "[]" : col.getJSONArray("filterValue").toString(), "[]");
                }
                else {
                    filterValue = JbUtil.nvl(col.isNull("filterValue") ? "" : col.getString("filterValue"), "");
                }
                if (!"".equals(filterValue)) {
                    if (filterType.equals("VC"))
                        fltr += " lower(" + colName + ") Like '%" + filterValue.toLowerCase() + "%' And";
                    if (filterType.equals("SL")) {
                        String fValue = JbUtil.nvl(filterValue, "");
                        String filterName = col.getString("filterName");
                        if (!fValue.equals("") && !fValue.equals("0"))
                            fltr += " to_char(" + filterName + ") = '" + fValue + "' And";
                    }
                }
                if (filterType.equals("DT")) {
                    String fromDate = col.isNull("fromDate") ? null : col.getString("fromDate");
                    String toDate = col.isNull("toDate") ? null : col.getString("toDate");
                    if (((fromDate != null && !"".equals(fromDate)) || (toDate != null && !"".equals(toDate)))) {
                        if (fromDate == null) {
                            if (toDate == null) {
                                fltr += " trunc(to_date(substr(" + colName + ", 1, 10), 'dd.mm.yyyy')) >= to_date('01.01.1900', 'dd.mm.yyyy') And trunc(to_date(" + colName + ", 'dd.mm.yyyy')) <= to_date('31.12.2099', 'dd.mm.yyyy') And";
                            }
                            fltr += " trunc(to_date(substr(" + colName + ", 1, 10), 'dd.mm.yyyy')) >= to_date('01.01.1900', 'dd.mm.yyyy') And trunc(to_date(" + colName + ", 'dd.mm.yyyy')) <= to_date('" + toDate + "', 'dd.mm.yyyy') And";
                        } else if (toDate == null) {
                            fltr += " trunc(to_date(substr(" + colName + ", 1, 10), 'dd.mm.yyyy')) >= to_date('" + fromDate + "', 'dd.mm.yyyy') And trunc(to_date(substr(" + colName + ", 1, 10), 'dd.mm.yyyy')) <= to_date('31.12.2099', 'dd.mm.yyyy') And";
                        } else {
                            fltr += " trunc(to_date(substr(" + colName + ", 1, 10), 'dd.mm.yyyy')) >= to_date('" + fromDate + "', 'dd.mm.yyyy') And trunc(to_date(substr(" + colName + ", 1, 10), 'dd.mm.yyyy')) <= to_date('" + toDate + "', 'dd.mm.yyyy') And";
                        }
                    }
                }
                if (filterType.equals("CHECKBOX")) {
                    if (col.getJSONArray("filterValue").length() != 0){
                        String filterName = col.getString("filterName");
                        if (!filterValue.equals("") && !filterValue.equals("0"))
                            fltr += " to_char(" + filterName + ") in (select value from json_table('"+ filterValue +"', '$[*]' COLUMNS (value PATH '$'))) And";
                    }
                }
            }
        }

        if (!"".equals(fltr)) {
            str += "".equals(str) ? " Where (" : " And (";
            str += (fltr.substring(0, fltr.length() - 4) + ")");
        }
        String search = JbUtil.nvl(json.isNull("search") ? "" : json.getString("search"));
        JSONArray cols = grid.getJSONArray("cols");
        if (!"".equals(search)) {
            str += "".equals(str) ? " Where (" : " And (";
            for (int i = 0; i < cols.length(); i++) {
                JSONObject col = cols.getJSONObject(i);
                if (col.isNull("grid") ? false : col.getBoolean("grid")) {
                    String colName = col.getString("name");
                    str += " lower(" + colName + ") Like '%" + search.toLowerCase() + "%' Or";
                }
            }
            str = str.substring(0, str.length() - 3) + ")";
        }
        return str;
    }

    //Cr By: Arslonbek Kulmatov
    public String getOrder(JSONObject grid, String params) throws JSONException {
        // Default order
        String ord = JbUtil.nvl(grid.isNull("ord") ? "" : grid.getString("ord"));
        String str = "".equals(ord) ? "" : " Order By " + ord;
        // Set order by cols
        JSONObject json = new JSONObject(params);
        JSONArray cols = json.isNull("cols") ? grid.getJSONArray("cols") : json.getJSONArray("cols");
        for (int i = 0; i < cols.length(); i++) {
            JSONObject col = cols.getJSONObject(i);
            String ordType = col.isNull("ordType") ? null : JbUtil.nvl(col.getString("ordType"), "");
            if (ordType != null && !ordType.equals("") && !ordType.equals("no")) {
                String colType = JbUtil.nvl(col.isNull("colType") ? "" : col.getString("colType"), "");
                String colName = col.getString("name");
                colName = JbUtil.nvl(colType).equals("DT") ? " To_Date(" + colName + ", 'dd.mm.yyyy') " : colName;
                str += "".equals(str) ? " Order By " + colName + " " + ordType : ", " + colName + " " + ordType;
            }
        }
        return str;
    }
}
