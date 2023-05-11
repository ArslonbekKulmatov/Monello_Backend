package com.example.asaka.util;

import oracle.jdbc.OracleConnection;
import org.json.JSONArray;
import org.json.JSONObject;

import java.io.InputStream;
import java.sql.*;
import java.util.ArrayList;
import java.util.List;

public class JbSql {

    private OracleConnection conn;
    private String sql;
    List<Params> params = new ArrayList<>();
    List<Params> outs = new ArrayList<>();
    List<OutParams> outParams = new ArrayList<>();
    private boolean isFunc = true;
    private String res;

    public JbSql(String sql, Connection conn, boolean isFunc) {
        try {
            this.sql = sql;
            this.conn = conn.unwrap(OracleConnection.class);
            this.params = new ArrayList<>();
            this.outParams = new ArrayList<>();
            this.isFunc = isFunc;
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public static JSONArray rsToJson(String select, Connection con) throws Exception {
        JSONArray rows = new JSONArray();
        ResultSet rs = null;
        PreparedStatement ps = null;
        OracleConnection conn = con.unwrap(OracleConnection.class);
        try {
            ps = conn.prepareStatement(select);
            ps.execute();
            rs = ps.getResultSet();
            ResultSetMetaData md = rs.getMetaData();
            while (rs.next()) {
                JSONObject row = new JSONObject();
                for (int i = 1; i <= md.getColumnCount(); i++) {
                    String colName = md.getColumnName(i).toLowerCase();
                    switch (md.getColumnType(i)) {
                        case Types.ARRAY:
                            row.put(colName, rs.getArray(i));
                            break;
                        case Types.NUMERIC:
                        case Types.BIGINT:
                            row.put(colName, rs.getBigDecimal(i));
                            break;
                        case Types.TINYINT:
                        case Types.SMALLINT:
                            row.put(colName, rs.getInt(i));
                            break;
                        case Types.BOOLEAN:
                            row.put(colName, rs.getBoolean(i));
                            break;
                        case Types.DOUBLE:
                            row.put(colName, rs.getDouble(i));
                            break;
                        case Types.FLOAT:
                            row.put(colName, rs.getFloat(i));
                            break;
                        case Types.NVARCHAR:
                            row.put(colName, rs.getNString(i));
                            break;
                        case Types.DATE:
                            row.put(colName, rs.getDate(i) != null ? String.valueOf(rs.getDate(i)) : "");
                            break;
                        case Types.TIMESTAMP:
                            row.put(colName, rs.getTimestamp(i) != null ? String.valueOf(rs.getTimestamp(i)) : "");
                            break;
                        case Types.VARCHAR:
                            row.put(colName, JbUtil.nvl(DB.get(rs, colName), ""));
                            break;
                        default:
                            row.put(colName, DB.get(rs, colName));
                    }
                }
                rows.put(row);
            }
        } finally {
            DB.done(rs);
            DB.done(ps);
        }
        return rows;
    }

    public void exec() throws Exception {
        CallableStatement cs = null;
        String query = "";
        StringBuilder queryExec = isFunc ? new StringBuilder("{call ? := " + this.sql + "( ") : new StringBuilder("{call " + this.sql + "( ");
        for (Params params : this.params) {
            queryExec.append("?,");
        }
        for (OutParams params : this.outParams) {
            queryExec.append("?,");
        }
        queryExec = new StringBuilder(queryExec.substring(0, queryExec.length() - 1) + ")}");
        query = queryExec.toString();
        try {
            cs = this.conn.prepareCall(query);
            for (OutParams params : this.outParams)
                cs.registerOutParameter(params.getOrd(), params.getType());
            for (Params params : this.params) {
                Object val = params.getObj();
                if (val instanceof String)
                    cs.setString(params.getOrd(), (String) val);
                else if (val instanceof Integer)
                    cs.setInt(params.getOrd(), (Integer) val);
                else if (val instanceof Blob)
                    cs.setBlob(params.getOrd(), (Blob) val);
                else if (val instanceof InputStream)
                    cs.setBlob(params.getOrd(), (InputStream) val);
                else if (val instanceof Clob)
                    cs.setClob(params.getOrd(), (Clob) val);
                else if (val instanceof Number)
                    cs.setInt(params.getOrd(), (Integer) val);
                else if (val == null)
                    cs.setString(params.getOrd(), "");
                else if (val instanceof String[]) {
                    Array arr = conn.createOracleArray("ARRAY_VARCHAR", val);
                    cs.setArray(params.getOrd(), arr);
                } else if (val instanceof Integer[]) {
                    Integer[] param = ((Integer[]) val);
                    Array arr = conn.createOracleArray("ARRAY_NUMBER", param.length > 0 ? val : new Integer[0]);
                    cs.setArray(params.getOrd(), arr);
                } else if (val instanceof int[]) {
                    int[] param = ((int[]) val);
                    Array arr = conn.createOracleArray("ARRAY_NUMBER", param.length > 0 ? val : new Integer[0]);
                    cs.setArray(params.getOrd(), arr);
                }
            }
            if (isFunc) {
                cs.registerOutParameter(1, Types.VARCHAR);
            }
            cs.execute();
            for (OutParams params : this.outParams) {
                switch (params.getType()) {
                    case Types.NUMERIC:
                        this.outs.add(new Params(cs.getInt(params.getOrd()), params.getOrd()));
                        break;
                    case Types.DATE:
                        this.outs.add(new Params(cs.getDate(params.getOrd()), params.getOrd()));
                        break;
                    case Types.VARCHAR:
                        this.outs.add(new Params(cs.getString(params.getOrd()), params.getOrd()));
                        break;
                    case Types.INTEGER:
                        this.outs.add(new Params(cs.getInt(params.getOrd()), params.getOrd()));
                        break;
                    case Types.CLOB:
                        this.outs.add(new Params(cs.getString(params.getOrd()), params.getOrd()));
                        break;
                    default:
                        this.outs.add(new Params(cs.getString(params.getOrd()), params.getOrd()));
                        break;
                }
            }
            if (isFunc) {
                res = cs.getString(1);
            }
        } finally {
            DB.done(cs);
        }
    }

    //
    public void execQuery() throws Exception {
        CallableStatement cs = null;
        ResultSet rs = null;
        try {
            cs = this.conn.prepareCall(this.sql);
            for (int i = 0; i < this.params.size(); i++) {
                Object paramValue = this.params.get(i);
                if (paramValue instanceof String) {
                    cs.setString(this.outParams.size() + i + 1, (String) paramValue);
                } else if (paramValue instanceof Integer) {
                    cs.setInt(this.outParams.size() + i + 1, (Integer) paramValue);
                } else if (paramValue instanceof Blob) {
                    cs.setBlob(this.outParams.size() + i + 1, (InputStream) paramValue);
                } else if (paramValue instanceof Number) {
                    cs.setInt(this.outParams.size() + i + 1, (int) paramValue);
                } else if (paramValue == null) {
                    cs.setString(this.outParams.size() + i + 1, "");
                } else if (paramValue instanceof String[]) {
                    Array arr = conn.createOracleArray("ARRAY_VARCHAR", paramValue);
                    cs.setArray(this.outParams.size() + i + 1, arr);
                } else if (paramValue instanceof Integer[]) {
                    Integer[] param = ((Integer[]) paramValue);
                    Array arr;
                    if (param.length > 0)
                        arr = conn.createOracleArray("ARRAY_NUMBER", paramValue);
                    else
                        arr = conn.createOracleArray("ARRAY_NUMBER", new Integer[0]);
                    cs.setArray(this.outParams.size() + i + 1, arr);
                } else if (paramValue instanceof int[]) {
                    int[] param = ((int[]) paramValue);
                    Array arr;
                    if (param.length > 0)
                        arr = conn.createOracleArray("ARRAY_NUMBER", paramValue);
                    else
                        arr = conn.createOracleArray("ARRAY_NUMBER", new Integer[0]);
                    cs.setArray(this.outParams.size() + i + 1, arr);
                }
            }
            cs.execute();
            for (OutParams params : this.outParams) {
                switch (params.getType()) {
                    case Types.NUMERIC:
                        this.outs.add(new Params(cs.getInt(params.getOrd()), params.getOrd()));
                        break;
                    case Types.DATE:
                        this.outs.add(new Params(cs.getDate(params.getOrd()), params.getOrd()));
                        break;
                    case Types.VARCHAR:
                        this.outs.add(new Params(cs.getString(params.getOrd()), params.getOrd()));
                        break;
                    case Types.INTEGER:
                        this.outs.add(new Params(cs.getInt(params.getOrd()), params.getOrd()));
                        break;
                    default:
                        this.outs.add(new Params(cs.getString(params.getOrd()), params.getOrd()));
                        break;
                }
            }
        } finally {
            DB.done(rs);
            DB.done(cs);
        }
    }

    public Object getOutVal(Integer ord) {
        for (Params par : this.outs) {
            if (par.getOrd() == ord) {
                return par.getObj();
            }
        }
        return null;
    }


    public void addParam(Object obj, Integer ord) {
        this.params.add(new Params(obj, ord));
    }

    public void addOut(Integer type, Integer ord) {
        this.outParams.add(new OutParams(type, ord));
    }

    public String getResult() {
        return res;
    }

    private static String removeORA(String message) {
        int start = message.indexOf("ORA-");
        if (start > -1) {
            int end = message.indexOf("ORA-", start + 1);
            String temp = message.substring(start + 11, end);
            if (temp.trim().length() > 0) {
                message = temp;
            }
        }
        return message;
    }

    private static String encode(String s, String fromEncode, String toEncode) throws Exception {
        if ((s == null) || (s.length() == 0)) return s;
        String s1 = new String(s.getBytes(fromEncode), toEncode);
        int i = s1.indexOf('?', 0);
        while (i >= 0) {
            if (s.charAt(i) != '?')
                return s;
            i = s1.indexOf('?', i + 1);
        }
        return s1;
    }

    public static String encodeISO(String s) throws Exception {
        return encode(s, "ISO-8859-1", "Cp1251");
    }


    public static String getUserMessage(Exception e) {
        String message = e.getMessage();
        if ((e instanceof Exception)) {
            SQLException ex = (SQLException) e;
            if ((ex.getErrorCode() >= 20000) && (ex.getErrorCode() < 20999))
                message = removeORA(message);
            else
                try {
                    message = encodeISO(message);
                } catch (Throwable th) {
                }
        }
        if (message == null) {
            message = e.getClass().getName();
        }
        return message;
    }

    public String userMsg(Exception e) {
        String msg = "";
        msg = getUserMessage(e).replace("\n", "");
        return msg;
    }

}


