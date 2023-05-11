package com.example.asaka.pi.services;

import com.example.asaka.core.services.SApp;
import com.example.asaka.util.DB;
import com.zaxxer.hikari.HikariDataSource;
import oracle.jdbc.proxy.annotation.Pre;
import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.parameters.P;
import org.springframework.stereotype.Service;

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
        JSONArray payments = new JSONArray();
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
}
