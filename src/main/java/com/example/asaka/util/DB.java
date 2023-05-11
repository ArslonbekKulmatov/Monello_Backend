package com.example.asaka.util;

import com.zaxxer.hikari.HikariDataSource;

import javax.sql.DataSource;
import java.sql.*;

public class DB {

    private static Exception noDBException = new Exception("no_connection");

    public static void ps(Connection conn, String sql) throws Exception {
        conn.prepareStatement(sql);
    }

    // Закрития соединения
    public static void done(Connection conn) {
        try {
            if (conn != null) {
                conn.close();
            }
        } catch (Exception ex) {
            ex.printStackTrace();
        }
    }

    public static void done(PreparedStatement ps) {
        try {
            if (ps != null)
                ps.close();
        } catch (Exception ex) {
            ex.printStackTrace();
        }
    }

    public static void done(CallableStatement cs) {
        try {
            if (cs != null) {
                cs.close();
            }
        } catch (Exception ex) {
            ex.printStackTrace();
        }
    }

    public static void done(ResultSet rs) {
        try {
            if (rs != null) {
                rs.close();
            }
        } catch (Exception ex) {
            ex.printStackTrace();
        }
    }

    public static String get(ResultSet rs, String name) {
        try {
            return rs.getString(name);
        } catch (Exception ex) {
            return "";
        }
    }

    public static Integer getInt(ResultSet rs, String name) {
        try {
            return rs.getInt(name);
        } catch (Exception ex) {
            return 0;
        }
    }

    public static String nvl(ResultSet rs, String name, String defVal) {
        try {
            return get(rs, name) != null && !(get(rs, name)).equals("") ? get(rs, name) : defVal;
        } catch (Exception ex) {
            return defVal;
        }
    }

    public static Connection con(HikariDataSource hds) throws Exception {
        try {
            return hds.getConnection();
        } catch (Exception ex) {
            throw noDBException;
        }
    }

    public static Connection con(DataSource hds) throws Exception {
        try {
            return hds.getConnection();
        } catch (Exception ex) {
            throw noDBException;
        }
    }

}


