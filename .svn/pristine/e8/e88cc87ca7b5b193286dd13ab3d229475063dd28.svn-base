package com.example.asaka.core.services;

import com.zaxxer.hikari.HikariDataSource;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.example.asaka.security.jwt.JwtUtils;
import com.example.asaka.util.DB;
import com.example.asaka.util.JbUtil;
import com.example.asaka.util.Req;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

@Service
public class SGrid {

    @Autowired HikariDataSource hds;
    @Autowired JwtUtils jwtUtils;
    @Autowired Req req;
    @Autowired SApp sApp;

    public JSONObject grid(String params) throws JSONException {
        JSONObject grid = new JSONObject();
        JSONObject json = new JSONObject(params);
        String viewUrl = json.getString("viewUrl");
        boolean firstReq = json.isNull("filters");
        JSONObject gridParams = JbUtil.getJson("views/" + viewUrl);
        JSONArray filters = !json.has("filters") && json.isNull("filters") ? gridParams.getJSONArray("filters") : json.getJSONArray("filters");
        Connection conn = null;
        JSONArray rows = new JSONArray();
        PreparedStatement ps = null;
        ResultSet rs = null;
        PreparedStatement psCol = null;
        ResultSet rsCol = null;
        Long rowCount = 0L;
        JSONArray cols = gridParams.getJSONArray("cols");
        try {
            conn = hds.getConnection();
            sApp.setDbSession(conn);
            sApp.setCustomDbSession(conn, json);
            rowCount = setRowCount(gridParams, conn, filters, params);
            ps = conn.prepareStatement(getSql(gridParams, filters, params, rowCount));
            ps.execute();
            rs = ps.getResultSet();
            while (rs.next()) {
                JSONObject row = new JSONObject();
                for (int i = 0; i < cols.length(); i++) {
                    JSONObject col = cols.getJSONObject(i);
                    String colNum = col.getString("num");
                    row.put(colNum, JbUtil.nvl(rs.getString(colNum)));
                }
                rows.put(row);
            }
            //
            if (firstReq) {
                for (int n = 0; n < filters.length(); n++) {
                    JSONObject obj = filters.getJSONObject(n);
                    if (obj.getString("type").equals("SL")) {
                        JSONArray dicts = new JSONArray();
                        String view = obj.isNull("view") ? null : obj.getString("view");
                        if (view != null) {
                            psCol = conn.prepareStatement(obj.getString("view"));
                            psCol.execute();
                            rsCol = psCol.getResultSet();
                            while (rsCol.next()) {
                                JSONObject dict = new JSONObject();
                                dict.put("label", rsCol.getString(1));
                                dict.put("value", rsCol.getString(2));
                                dicts.put(dict);
                            }
                        }
                        JSONArray values = obj.isNull("values") ? null : obj.getJSONArray("values");
                        if (values != null) {
                            for (int i = 0; i < values.length(); i++) {
                                JSONObject val = values.getJSONObject(i);
                                JSONObject dict = new JSONObject();
                                dict.put("label", val.getString("label"));
                                dict.put("value", val.getString("value"));
                                dicts.put(dict);
                            }
                        }
                        obj.put("rows", dicts);
                    }
                    filters.put(n, obj);
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            DB.done(rs);
            DB.done(ps);
            DB.done(psCol);
            DB.done(rsCol);
            DB.done(conn);
        }
        //
        Long pageSize = json.isNull("pageSize") ? gridParams.getLong("pageSize") : json.getLong("pageSize");
        Long tail = rowCount % pageSize;
        Integer maxPage = tail == 0 ? Math.round(rowCount / pageSize) : Math.round(rowCount / pageSize) + 1;
        //
        grid.put("pageSize", pageSize);
        grid.put("maxPage", maxPage);
        grid.put("rowCount", rowCount);
        grid.put("numbering", !gridParams.isNull("numbering") ? gridParams.getBoolean("numbering") : false);
        grid.put("checkbox", !gridParams.isNull("checkbox") ? gridParams.getBoolean("checkbox") : false);
        if (json.isNull("cols")) {
            grid.put("cols", cols);
        }
        grid.put("rows", rows);
        if (firstReq) {
            grid.put("filters", filters);
        }
        return grid;
    }

    //
    private Long setRowCount(JSONObject grid, Connection conn, JSONArray filters, String params) {
        Long rows = 0L;
        PreparedStatement ps = null;
        ResultSet rs = null;
        try {
            ps = conn.prepareStatement("SELECT COUNT(*) FROM " + grid.getString("view") + getWhere(grid, filters, params));
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

    //
    public String getSql(JSONObject grid, JSONArray filters, String params, Long rowCount) throws JSONException {
        JSONObject json = new JSONObject(params);
        Integer page = json.getInt("page");
        Integer pageSize = json.isNull("pageSize") ? grid.getInt("pageSize") : json.getInt("pageSize");
        Integer start = !page.equals(1) ? ((page - 1) * pageSize + 1) : 1;
        Integer end = pageSize + start - 1;
        String view = grid.getString("view");
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

    //
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
                String filterValue = JbUtil.nvl(col.isNull("filterValue") ? "" : col.getString("filterValue"), "");
                String filterType = col.getString("type");
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

    //
    private String getOrder(JSONObject grid, String params) throws JSONException {
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


