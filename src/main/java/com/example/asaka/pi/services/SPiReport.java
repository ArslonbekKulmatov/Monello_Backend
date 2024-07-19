package com.example.asaka.pi.services;

import com.example.asaka.core.services.SApp;
import com.example.asaka.util.DB;
import com.zaxxer.hikari.HikariDataSource;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.streaming.SXSSFWorkbook;
import org.apache.poi.xssf.usermodel.*;
import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.InputStreamResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

@Service
public class SPiReport {
    @Autowired HikariDataSource hds;
    @Autowired private SApp sApp;
    public String accountingReport(String params){
        JSONObject json_params = new JSONObject(params);
        JSONObject response = null;
        JSONObject debtor;
        JSONObject payment;
        JSONArray payments;
        JSONArray debtors = new JSONArray();
        String begin_date = json_params.getString("begin_date");
        String end_date = json_params.getString("end_date");
        Connection conn = null;

        PreparedStatement ps = null;
        ResultSet rs = null;
        PreparedStatement ps1;
        ps1 = null;
        ResultSet rs1 = null;

        try {
            conn = DB.con(hds);
            sApp.setDbSession(conn);
            ps = conn.prepareStatement("select p.*" +
                                           "   from pi_debtors_paid_v p " +
                                           "  where p.max_paid_date between to_date('"+ begin_date +"', 'dd.mm.yyyy') and to_date('"+ end_date +"', 'dd.mm.yyyy')");
            rs = ps.executeQuery();
            while (rs.next()){
                payments = new JSONArray();
                debtor = new JSONObject();
                debtor.put("debtor_name", rs.getString("debtor_name"));
                debtor.put("regres_sum", rs.getBigDecimal("regres_sum"));
                debtor.put("debited_sum", rs.getBigDecimal("total_paid_amounts"));

                ps1 = conn.prepareStatement("select * from pi_regress_paid_amounts_v where cover_id = " + rs.getInt("cover_id"));
                rs1 = ps1.executeQuery();
                while (rs1.next()){
                    payment = new JSONObject();
                    payment.put("paid_amount", rs1.getBigDecimal("paid_amount"));
                    payment.put("paid_date", rs1.getString("paid_date"));
                    payment.put("pay_type", rs1.getString("pay_type"));
                    payments.put(payment);
                }

                debtor.put("payments", payments);
                debtors.put(debtor);

            }

            response = new JSONObject();
            response.put("debtors", debtors);
            response.put("success", true);
        }catch (Exception e){
            e.printStackTrace();
            response.put("success", false);
            response.put("error", e.getMessage());
        }finally {
            DB.done(ps);
            DB.done(rs);
            DB.done(ps1);
            DB.done(rs1);
            DB.done(conn);
        }

        return response.toString();
    }

    //Cr By: Arslonbek Kulmatov
    //Accounting report to excel
    public ResponseEntity<InputStreamResource> accountingReportExcel(String params){
        JSONObject pars = new JSONObject(params);
        InputStreamResource resource = null;
        byte[] data;
        ByteArrayOutputStream bos = null;
        ByteArrayInputStream bis = null;
        JSONObject request = new JSONObject();
        String response_data;
        JSONObject response_data_json;
        SXSSFWorkbook wb = new SXSSFWorkbook(100); // keep 100 rows in memory, exceeding rows will be flushed to disk
        try{
            request.put("method", "pi.accountingReport");
            request.put("params", pars);

            response_data = sApp.post(request.toString(), false);
            response_data_json = new JSONObject(response_data);

            Sheet sheet = wb.createSheet("Бухгалтерский отчет");
            Font font = wb.createFont();
            Font headerFont = wb.createFont();
            headerFont.setBold(true);
            headerFont.setColor(IndexedColors.WHITE.index);
            font.setFontName("Times New Roman");

            Font footerFont = wb.createFont();
            footerFont.setBold(true);
            footerFont.setFontName("Times New Roman");

            XSSFCellStyle noBorderStyle = (XSSFCellStyle) wb.createCellStyle();
            XSSFCellStyle textStyle = (XSSFCellStyle) wb.createCellStyle();
            XSSFCellStyle centerStyle = (XSSFCellStyle) wb.createCellStyle();
            XSSFCellStyle decimalStyle = (XSSFCellStyle) wb.createCellStyle();
            XSSFCellStyle headerStyle = (XSSFCellStyle) wb.createCellStyle();
            XSSFCellStyle footerStyle = (XSSFCellStyle) wb.createCellStyle();
            XSSFCellStyle numStyle = (XSSFCellStyle) wb.createCellStyle();

            noBorderStyle.setFont(font);

            headerStyle.setFont(headerFont);
            headerStyle.setBorderLeft(BorderStyle.THIN);
            headerStyle.setBorderTop(BorderStyle.THIN);
            headerStyle.setBorderRight(BorderStyle.THIN);
            headerStyle.setBorderBottom(BorderStyle.THIN);
            headerStyle.setAlignment(HorizontalAlignment.CENTER);
            headerStyle.setFillForegroundColor(new XSSFColor(new java.awt.Color(58, 106, 135)));
            headerStyle.setFillPattern(FillPatternType.SOLID_FOREGROUND);
            headerStyle.setRightBorderColor(IndexedColors.GREY_25_PERCENT.getIndex());
            headerStyle.setBottomBorderColor(IndexedColors.GREY_25_PERCENT.getIndex());

            textStyle.setFont(font);
            textStyle.setBorderLeft(BorderStyle.THIN);
            textStyle.setBorderTop(BorderStyle.THIN);
            textStyle.setBorderRight(BorderStyle.THIN);
            textStyle.setBorderBottom(BorderStyle.THIN);

            centerStyle.setFont(font);
            centerStyle.setBorderLeft(BorderStyle.THIN);
            centerStyle.setBorderTop(BorderStyle.THIN);
            centerStyle.setBorderRight(BorderStyle.THIN);
            centerStyle.setBorderBottom(BorderStyle.THIN);
            centerStyle.setAlignment(HorizontalAlignment.CENTER);

            XSSFDataFormat format = (XSSFDataFormat) wb.createDataFormat();
            decimalStyle.setDataFormat(format.getFormat("### ### ### ### ### ### ##0.00"));
            decimalStyle.setFont(font);
            decimalStyle.setBorderLeft(BorderStyle.THIN);
            decimalStyle.setBorderTop(BorderStyle.THIN);
            decimalStyle.setBorderRight(BorderStyle.THIN);
            decimalStyle.setBorderBottom(BorderStyle.THIN);
            decimalStyle.setAlignment(HorizontalAlignment.CENTER);

            footerStyle.setDataFormat(format.getFormat("### ### ### ### ### ### ##0.00"));
            footerStyle.setFont(footerFont);
            footerStyle.setBorderLeft(BorderStyle.THIN);
            footerStyle.setBorderTop(BorderStyle.THIN);
            footerStyle.setBorderRight(BorderStyle.THIN);
            footerStyle.setBorderBottom(BorderStyle.THIN);
            footerStyle.setAlignment(HorizontalAlignment.CENTER);
            footerStyle.setFillForegroundColor(new XSSFColor(new java.awt.Color(204, 203, 200)));
            footerStyle.setFillPattern(FillPatternType.SOLID_FOREGROUND);

            numStyle.setFont(footerFont);
            numStyle.setBorderLeft(BorderStyle.THIN);
            numStyle.setBorderTop(BorderStyle.THIN);
            numStyle.setBorderRight(BorderStyle.THIN);
            numStyle.setBorderBottom(BorderStyle.THIN);
            numStyle.setAlignment(HorizontalAlignment.CENTER);
            numStyle.setFillForegroundColor(new XSSFColor(new java.awt.Color(204, 203, 200)));
            numStyle.setFillPattern(FillPatternType.SOLID_FOREGROUND);

            // Setting columns width (256 = width of one character)
            sheet.setColumnWidth(0, 256 * 10);
            sheet.setColumnWidth(1, 225 * 100);
            sheet.setColumnWidth(2, 256 * 30);
            sheet.setColumnWidth(3, 256 * 30);
            sheet.setColumnWidth(4, 256 * 30);
            sheet.setColumnWidth(5, 256 * 30);
            sheet.setColumnWidth(6, 256 * 30);
            sheet.setColumnWidth(7, 256 * 30);
            sheet.setColumnWidth(8, 256 * 30);
            sheet.setColumnWidth(9, 256 * 30);
            sheet.setColumnWidth(10, 256 * 30);
            sheet.setColumnWidth(11, 256 * 30);


            int rowCount = 0;
            Row row = sheet.createRow(0);
            row.createCell(0).setCellValue("№");
            row.getCell(0).setCellStyle(headerStyle);
            row.createCell(1).setCellValue("ФИО должника");
            row.getCell(1).setCellStyle(headerStyle);
            row.createCell(2).setCellValue("Сумма задолженности");
            row.getCell(2).setCellStyle(headerStyle);
            row.createCell(3).setCellValue("Собранные средства");
            row.getCell(3).setCellStyle(headerStyle);
            row.createCell(4).setCellValue("Сумма");
            row.getCell(4).setCellStyle(headerStyle);
            row.createCell(5).setCellValue("Дата оплата");
            row.getCell(5).setCellStyle(headerStyle);
            row.createCell(6).setCellValue("Вид оплата");
            row.getCell(6).setCellStyle(headerStyle);
            row.createCell(7).setCellValue("Номер контракта");
            row.getCell(7).setCellStyle(headerStyle);
            row.createCell(8).setCellValue("ПИНФЛ");
            row.getCell(8).setCellStyle(headerStyle);
            row.createCell(9).setCellValue("Оставшийся долг");
            row.getCell(9).setCellStyle(headerStyle);
            row.createCell(10).setCellValue("Сумма, закрытая на этапе 1");
            row.getCell(10).setCellStyle(headerStyle);
            row.createCell(11).setCellValue("Номер полиса");
            row.getCell(11).setCellStyle(headerStyle);

            JSONArray debtors = response_data_json.getJSONObject("data").getJSONArray("payments");
            JSONObject total = response_data_json.getJSONObject("data").getJSONObject("total");
            for(int debtor = 0; debtor < debtors.length(); debtor++) {
                JSONObject object = debtors.getJSONObject(debtor);
                JSONArray paid_amounts = object.getJSONArray("paid_amounts");
                JSONArray paid_dates = object.getJSONArray("paid_dates");
                JSONArray pay_types = object.getJSONArray("pay_types");
                for (int i = 0; i < paid_amounts.length(); i++) {
                    sheet.createRow(++rowCount);
                    sheet.getRow(rowCount).createCell(0).setCellValue(debtor + 1);
                    sheet.getRow(rowCount).getCell(0).setCellStyle(numStyle);

                    sheet.getRow(rowCount).createCell(4).setCellValue(paid_amounts.getDouble(i));
                    sheet.getRow(rowCount).getCell(4).setCellStyle(decimalStyle);

                    sheet.getRow(rowCount).createCell(5).setCellValue(paid_dates.getString(i));
                    sheet.getRow(rowCount).getCell(5).setCellStyle(centerStyle);

                    sheet.getRow(rowCount).createCell(6).setCellValue(pay_types.getString(i));
                    sheet.getRow(rowCount).getCell(6).setCellStyle(centerStyle);
                }

                sheet.getRow(rowCount).createCell(1).setCellValue(object.getString("debtor_name"));
                sheet.getRow(rowCount).getCell(1).setCellStyle(centerStyle);

                sheet.getRow(rowCount).createCell(2).setCellValue(object.getDouble("regres_sum"));
                sheet.getRow(rowCount).getCell(2).setCellStyle(decimalStyle);

                sheet.getRow(rowCount).createCell(3).setCellValue(object.getDouble("debited_sum"));
                sheet.getRow(rowCount).getCell(3).setCellStyle(decimalStyle);

                sheet.getRow(rowCount).createCell(7).setCellValue(object.getString("contract_num"));
                sheet.getRow(rowCount).getCell(7).setCellStyle(centerStyle);

                sheet.getRow(rowCount).createCell(8).setCellValue(object.getString("pinfl"));
                sheet.getRow(rowCount).getCell(8).setCellStyle(centerStyle);

                sheet.getRow(rowCount).createCell(9).setCellValue(object.getDouble("remaining_debt"));
                sheet.getRow(rowCount).getCell(9).setCellStyle(decimalStyle);

                sheet.getRow(rowCount).createCell(10).setCellValue(object.getDouble("first_period_paid_amount"));
                sheet.getRow(rowCount).getCell(10).setCellStyle(decimalStyle);

                sheet.getRow(rowCount).createCell(11).setCellValue(object.getString("polis_num"));
                sheet.getRow(rowCount).getCell(11).setCellStyle(centerStyle);

            }

            sheet.createRow(++rowCount).createCell(1).setCellValue("Общий");
            sheet.getRow(rowCount).getCell(1).setCellStyle(footerStyle);

            sheet.getRow(rowCount).createCell(2).setCellValue(total.getDouble("regres_sum"));
            sheet.getRow(rowCount).getCell(2).setCellStyle(footerStyle);

            sheet.getRow(rowCount).createCell(3).setCellValue(total.getDouble("debited_sum"));
            sheet.getRow(rowCount).getCell(3).setCellStyle(footerStyle);

            sheet.getRow(rowCount).createCell(4).setCellValue(total.getDouble("paid_amounts"));
            sheet.getRow(rowCount).getCell(4).setCellStyle(footerStyle);

            bos = new ByteArrayOutputStream();
            wb.write(bos);
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
                wb.close();
            } catch (IOException e) {
                e.printStackTrace();
            }
        }

        HttpHeaders headers = new HttpHeaders();
        headers.add("Content-Disposition", "attachment; filename=Buxgalterskiy_Otchet.xlsx");
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_OCTET_STREAM)
                .headers(headers)
                .body(resource);
    }
}
