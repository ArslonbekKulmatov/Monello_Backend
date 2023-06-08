package com.example.asaka.core.services;

import com.example.asaka.config.Session;
import com.example.asaka.core.models.Grid_New;
import com.example.asaka.security.jwt.JwtUtils;
import com.example.asaka.util.DB;
import com.example.asaka.util.ExcMsg;
import com.example.asaka.util.JbUtil;
import com.example.asaka.util.Req;
import com.zaxxer.hikari.HikariDataSource;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.ss.util.CellRangeAddress;
import org.apache.poi.xssf.usermodel.*;
import org.apache.tomcat.util.codec.binary.Base64;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.InputStreamResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;

import javax.servlet.http.HttpServletRequest;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

@Service
public class SGrid_New {
    @Autowired HikariDataSource hds;
    @Autowired JwtUtils jwtUtils;
    @Autowired Req req;
    @Autowired SApp sApp;
    @Autowired Session session;

    //Cr By: Arslonbek Kulmatov
    public Grid_New get(int grid_id,  boolean check_session) {
        Connection conn = null;
        Grid_New grid = new Grid_New();
        try {
            conn = hds.getConnection();
            grid = get(grid_id, conn, check_session);
        } catch (Exception e){
            e.printStackTrace();
        } finally {
            DB.done(conn);
        }
        return grid;
    }

    //Cr By: Arslonbek Kulmatov
    public Grid_New get(int grid_id, Connection conn, boolean check_session) {
        Grid_New grid;

        if (check_session){
            grid = session.getGrid(grid_id);
            if (grid != null) return grid;
        }
        grid = new Grid_New();
        PreparedStatement ps = null;
        ResultSet rs = null;
        PreparedStatement psCol = null;
        ResultSet rsCol = null;
        try{
            ps = conn.prepareStatement("SELECT * FROM CORE_GRIDS WHERE GRID_ID = ?");
            ps.setInt(1, grid_id);
            ps.execute();
            rs = ps.getResultSet();
            if (rs.next()) {
                grid.setHasFilter(false);
                grid.setGrid_id(grid_id);
                grid.setView(DB.get(rs, "view_name"));
                grid.setPage_json(DB.get(rs, "page_json"));
                grid.setColumns_json(DB.get(rs, "columns_json"));
                grid.setFilter_json(DB.get(rs, "filter_json"));
            }
        }catch (Exception e){
            e.printStackTrace();
        }finally {
            DB.done(rsCol);
            DB.done(psCol);
            DB.done(rs);
            DB.done(ps);
        }
        return grid;
    }

    //Cr By: Arslonbek Kulmatov
    public JSONObject grid(String params) throws JSONException {

        JSONObject grid = new JSONObject();
        JSONObject gridParams = new JSONObject();
        JSONObject json = new JSONObject(params);
        JSONArray filters;
        Grid_New grid_object;
        Integer grid_id = json.getInt("grid_id");
        boolean has_filter = json.isNull("filters");
        Connection conn = null;
        JSONArray rows = new JSONArray();
        JSONArray cols = new JSONArray();
        JSONArray col_sums_arr = new JSONArray();
        JSONObject col_sums;
        PreparedStatement ps = null;
        ResultSet rs = null;
        PreparedStatement psCol = null;
        ResultSet rsCol = null;
        Long rowCount = 0L;
        try {
            conn = hds.getConnection();
            sApp.setDbSession(conn);
            sApp.setCustomDbSession(conn, json);
            grid_object = get(grid_id, conn, true);
            session.addSession("gridId", grid_id.toString());
            session.setGrid(grid_object);
            gridParams = new JSONObject(grid_object.getPage_json());
            gridParams.put("cols", new JSONArray(grid_object.getColumns_json()));
            gridParams.put("filters", new JSONArray(grid_object.getFilter_json()));
            if (!has_filter){
                filters = json.getJSONArray("filters");
                grid_object.setFilter_json(filters.toString());
            }
            filters = new JSONArray(grid_object.getFilter_json());
            cols = gridParams.getJSONArray("cols");
            rowCount = grid_object.setRowCount(gridParams, conn, filters, params);
            ps = conn.prepareStatement(grid_object.getSql(gridParams, filters, params, rowCount));
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
            for (int i = 0; i < cols.length(); i++) {
                JSONObject col = cols.getJSONObject(i);
                String colNum = col.getString("num");
                String colName = col.getString("name");
                if (col.has("show_col_sum")){
                    boolean show_col_sum = col.getBoolean("show_col_sum");
                    if (show_col_sum){
                        col_sums = new JSONObject();
                        String col_sum = getColumnSum(colName, gridParams, filters, params, grid_object);
                        col_sums.put("col_sum", JbUtil.nvl(col_sum, "0"));
                        col_sums.put("num", colNum);
                        col_sums.put("name", colName);
                        col_sums_arr.put(col_sums);
                    }
                }
            }
            grid.put("success", true);
        } catch (Exception e) {
            ExcMsg.call(grid, e, conn);
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
        grid.put("col_sums", col_sums_arr);
        return grid;
    }

    //Cr By: Arslonbek Kulmatov
    public JSONObject getFilter(String params, HttpServletRequest request){
        JSONObject response = new JSONObject();
        JSONObject json = new JSONObject(params);
        Integer grid_id =  json.getInt("grid_id");
        boolean check_session = json.getBoolean("check_session");
        Grid_New grid = get(grid_id, check_session);
        JSONArray filters = new JSONArray(grid.getFilter_json());
        Connection conn = null;
        PreparedStatement psCol = null;
        ResultSet rsCol = null;
        try {
            conn = hds.getConnection();
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
        }catch (Exception e){
            ExcMsg.call(response, e, conn);
        }finally {
            DB.done(psCol);
            DB.done(rsCol);
            DB.done(conn);
        }
        response.put("filters", filters);
        return response;
    }

    //Cr By: Arslonbek Kulmatov
    public JSONObject removeGridSession(String params){
        JSONObject response = new JSONObject();
        JSONObject json = new JSONObject(params);
        Integer grid_id =  json.getInt("grid_id");
        try{
            session.removeGrid(grid_id);
            response.put("sucess", true);
        }catch (Exception e){
            e.printStackTrace();
            response.put("sucess", false);
            response.put("error", e.getMessage());
        }

        return response;
    }

    //Cr By: Arslonbek Kulmatov
    //Get grid column translation
    public String getColumnTranslation(String column_code) {
        Connection conn = null;
        PreparedStatement ps = null;
        ResultSet res = null;
        String translation = "";
        try {
            conn = DB.con(hds);
            sApp.setDbSession(conn);
            ps = conn.prepareStatement("select * from CORE_GRIDS_COLUMNS where column_code =  '" + column_code + "' and rownum = 1");
            res = ps.executeQuery();
            if (res.next()) {
                translation = res.getString("column_translation");
            }
        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            DB.done(ps);
            DB.done(res);
            DB.done(conn);
        }
        return translation;
    }

    //Cr By: Arslonbek Kulmatov
    //Get grid column translation
    public String getColumnSum(String column_name, JSONObject grid, JSONArray filters, String params, Grid_New grid_object) {
        Connection conn = null;
        PreparedStatement ps = null;
        ResultSet res = null;
        String col_sum = "";
        try {
            conn = DB.con(hds);
            sApp.setDbSession(conn);
            ps = conn.prepareStatement(grid_object.getSqlColSum(column_name, grid, filters, params));
            res = ps.executeQuery();
            if (res.next()) {
                col_sum = res.getString("colSum");
            }
        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            DB.done(ps);
            DB.done(res);
            DB.done(conn);
        }
        return col_sum;
    }

    //Cr By: Arslonbek Kulmatov
    //getting grid data into excel
    public ResponseEntity<InputStreamResource> toExcel(String params){
        JSONObject pars = new JSONObject(params);
        String wh = "1=1";
        Integer grid_id = pars.getInt("grid_id");
        if (pars.has("wh")){
            wh = pars.getString("wh");
        }
        InputStreamResource resource = null;
        byte[] data;
        ByteArrayOutputStream bos = null;
        ByteArrayInputStream bis = null;
        JSONObject grid_req = new JSONObject();
        JSONObject grid_data;
        XSSFWorkbook workbook = new XSSFWorkbook();
        try{
            grid_req.put("grid_id", grid_id);
            grid_req.put("pageSize", 15000);
            grid_req.put("page", 1);
            grid_req.put("wh", wh);

            grid_data = grid(grid_req.toString());
            XSSFSheet sheet = workbook.createSheet("Report");
            XSSFCellStyle cellStyle = workbook.createCellStyle();
            cellStyle.setFillForegroundColor(new XSSFColor(new java.awt.Color(58, 106, 135)));
            cellStyle.setFillPattern(FillPatternType.SOLID_FOREGROUND);
            cellStyle.setAlignment(CellStyle.ALIGN_CENTER);
            cellStyle.setBorderRight(BorderStyle.THIN);
            cellStyle.setBorderBottom(BorderStyle.THIN);
            cellStyle.setRightBorderColor(IndexedColors.GREY_25_PERCENT.getIndex());
            cellStyle.setBottomBorderColor(IndexedColors.GREY_25_PERCENT.getIndex());

            XSSFFont font = workbook.createFont();
            font.setColor(IndexedColors.WHITE.index);
            cellStyle.setFont(font);

            int cor[] = {0, 0};//cor[0] - row, cor[1] - column
            Row row = sheet.createRow(cor[0]);
            Cell cell = row.createCell(0);
            cell.setCellValue(1);
            cell.setCellStyle(cellStyle);

            //get column labels
            JSONArray columns = grid_data.getJSONArray("cols");
            for(int col = 0; col < columns.length(); col ++){
                JSONObject val = columns.getJSONObject(col);
                if (val.getBoolean("excel")){
                    cell = row.createCell(++cor[1]);
                    String get_translation = getColumnTranslation(val.getString("label"));
                    if (get_translation.equals("")){
                        get_translation = val.getString("label");
                    }
                    cell.setCellValue(get_translation);
                    cell.setCellStyle(cellStyle);
                }
            }

            int rowIndex = 1;
            JSONArray rows = grid_data.getJSONArray("rows");
            for (int r = 0; r < rows.length(); r++) {
                JSONObject row_val = rows.getJSONObject(r);
                row = sheet.createRow(++cor[0]);
                cell = row.createCell(0);
                cell.setCellValue(rowIndex++);
                cell.setCellStyle(cellStyle);
                cor[1] = 0;
                //Get column values
                for (int col = 0; col < columns.length(); col ++) {
                    JSONObject val = columns.getJSONObject(col);
                    if (val.getBoolean("excel")) {
                        cell = row.createCell(++cor[1]);
                        if (val.has("col_type") && val.getString("col_type").equals("sum")){
                            String row_value = row_val.getString(val.getString("num"));
                            if (!row_value.equals("")){
                                double row_float = Double.parseDouble(row_value);
                                cell.setCellValue(row_float);
                            }
                            else{
                                cell.setCellValue(row_value);
                            }
                        }
                        else {
                            cell.setCellValue(row_val.getString(val.getString("num")));
                        }

                    }
                }
            }
            cor[1] = 0;
            sheet.autoSizeColumn(0);
            for (int col = 0; col < columns.length(); col ++) {
                JSONObject val = columns.getJSONObject(col);
                if (val.getBoolean("excel")) {
                    sheet.autoSizeColumn(++cor[1]);
                }
            }
            bos = new ByteArrayOutputStream();
            workbook.write(bos);
            data = bos.toByteArray();
            bis = new ByteArrayInputStream(data);
            resource = new InputStreamResource(bis);
        }
        catch (Exception e){
            e.printStackTrace();
        }
        finally {
            try {
                bos.flush();
                bos.close();
                bis.close();
                workbook.close();
            } catch (IOException e) {
                e.printStackTrace();
            }
        }

        HttpHeaders headers = new HttpHeaders();
        headers.add("Content-Disposition", "attachment; filename=grid_data.xlsx");
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_OCTET_STREAM)
                .headers(headers)
                .body(resource);
    }
}
