package com.example.asaka.core.services;

import com.zaxxer.hikari.HikariDataSource;
import io.jsonwebtoken.Claims;
import oracle.jdbc.OracleConnection;
import org.json.JSONArray;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.json.JSONObject;
import org.springframework.util.StringUtils;
import org.springframework.web.client.HttpStatusCodeException;
import org.springframework.web.multipart.MultipartFile;
import com.example.asaka.security.jwt.JwtUtils;
import com.example.asaka.security.services.UserDetailsImpl;
import com.example.asaka.security.services.UserDetailsServiceImpl;
import com.example.asaka.util.*;

import java.nio.file.Path;
import java.nio.file.Paths;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Types;

import static com.example.asaka.util.JbUtil.nvl;

@Service
public class SApp {

    @Autowired HikariDataSource hds;
    @Autowired PasswordEncoder encoder;
    @Autowired JwtUtils jwtUtils;
    @Autowired Req req;
    @Autowired UserDetailsServiceImpl userDetailsService;
    @Autowired AuthenticationManager authenticationManager;
    @Value("${jwt.expirationMs}") Integer jwtExpirationMs;
    @Autowired private FilesStorageService storageService;

    private @Autowired SUser sUser;

    public String post(String params, Boolean use_session) throws Exception {
        Connection conn = DB.con(hds);
        JSONObject pars = new JSONObject(params);
        String method = pars.getString("method");
        JbSql sql;
        JSONObject res = new JSONObject();
        res.put("success", true);
        try {
            if(use_session){
                setDbSession(conn);
            }
            sql = new JbSql("Core_App.Set_Method", conn, false);
            sql.addParam(params, 1);
            sql.addOut(Types.CLOB, 2);
            sql.exec();
            boolean isOper;
            String outAddStr = (String) sql.getOutVal(2);
            if (outAddStr != null) {
                JSONObject outObj = new JSONObject(outAddStr);
                if (method.equals("judical.deleteData")) {
                    String url = outObj.getString("url");
                    storageService.delete(url);
                }
                isOper = outObj.has("oper") && !outObj.isNull("oper") ? outObj.getBoolean("oper") : false;
                String message = outObj.has("message") && !outObj.isNull("message") ? outObj.getString("message") : "";
                if (outObj.has("message") && !outObj.isNull("message")) {
                    res.put("message", message);
                }
                // Agar operatsiyaligini bildiruvchi qiymati bo'lmasa
                if (outObj.has("oper") && !outObj.isNull("oper")) {
                    res.put("oper", isOper);
                }
                outObj.remove("oper");
                outObj.remove("message");
                res.put("data", outObj);
            }

        } catch (Exception e) {
            ExcMsg.call(res, e, conn);
        } finally {
            DB.done(conn);
        }
        return res.toString();
    }

    public String wtpost(String params) throws Exception {
        Connection conn = DB.con(hds);
        JbSql sql = null;
        JSONObject res = new JSONObject();
        res.put("success", true);
        try {
            sql = new JbSql("Core_App.Set_Method", conn, false);
            sql.addParam(params, 1);
            sql.addOut(Types.CLOB, 2);
            sql.exec();
            boolean isOper = false;
            String outAddStr = (String) sql.getOutVal(2);
            if (outAddStr != null) {
                JSONObject outObj = new JSONObject(outAddStr);
                isOper = outObj.has("oper") && !outObj.isNull("oper") ? outObj.getBoolean("oper") : false;
                String message = outObj.has("message") && !outObj.isNull("message") ? outObj.getString("message") : "";
                if (outObj.has("message") && !outObj.isNull("message")) {
                    res.put("message", message);
                }
                // Agar operatsiyaligini bildiruvchi qiymati bo'lmasa
                if (outObj.has("oper") && !outObj.isNull("oper")) {
                    res.put("oper", isOper);
                }
                outObj.remove("oper");
                outObj.remove("message");
                res.put("data", outObj);
            }

        } catch (Exception e) {
            ExcMsg.call(res, e, conn);
        } finally {
            DB.done(conn);
        }
        return res.toString();
    }

    public String postFile(String params, MultipartFile multipartFile) throws Exception {
        JSONObject pars = new JSONObject(params);
        String method = pars.getString("method");
        JSONObject upload_params = null;
        Path root = Paths.get("");
        Connection conn = DB.con(hds);
        JbSql sql;
        JSONObject res = new JSONObject();
        String outAddStr;
        res.put("success", true);
        res.put("message", "");
        if (multipartFile != null){
            upload_params = getMethodParamValue(method, "file_upload_type");
            pars.put("fileName", multipartFile.getOriginalFilename());
            pars.put("fileType", multipartFile.getContentType());
            String file_extension = storageService.getExtensionByStringHandling(multipartFile.getOriginalFilename()).get();
            if (upload_params.has("root")){
                root = Paths.get(upload_params.getString("root"));
                pars.put("root", root);
            }
            pars.put("fileExtension", file_extension);
        }
        params = pars.toString();
        try {
            setDbSession(conn, pars);
            if (multipartFile != null) {
                sql = new JbSql("Core_App.Set_Method_File", conn, false);
            }
            else {
                sql = new JbSql("Core_App.Set_Method", conn, false);
            }
            sql.addParam(params, 1);
            if (multipartFile != null){
                sql.addParam(multipartFile.getInputStream(), 2);
                sql.addOut(Types.VARCHAR, 3);
            }
            else{
                sql.addOut(Types.VARCHAR, 2);
            }

            sql.exec();
            if (multipartFile != null){
                outAddStr = (String) sql.getOutVal(3);
            }
            else{
                outAddStr = (String) sql.getOutVal(2);
            }

            JSONObject outObj = new JSONObject(outAddStr);
            boolean isOper = outObj.getBoolean("oper");
            String message = "";
            message = isOper ? outObj.getString("message") : "";

            if (multipartFile != null) {
                if(upload_params.has("type")){
                    String type = upload_params.getString("type");

                    if(type.equals("SERVER_INSERT") && isOper){
                        String file_name = outObj.getString("file_name");
                        storageService.save(multipartFile, file_name, root);
                    }
                    else if (type.equals("SERVER_UPDATE") && isOper) {
                        String file_name = outObj.getString("file_name");
                        Path path = root.resolve(file_name);
                        storageService.delete(path.toString());
                        storageService.save(multipartFile, file_name, root);
                    }
                }
            }

            outObj.remove("oper");
            outObj.remove("message");
            res.put("data", outObj);
            res.put("message", message);
            res.put("oper", isOper);
        } catch (Exception e) {
            ExcMsg.call(res, e, conn);
        } finally {
            DB.done(conn);
        }
        return res.toString();
    }

    public String execSelect(String params) throws Exception {
        Connection conn = DB.con(hds);
        JSONObject res = new JSONObject();
        try {
            setDbSession(conn);
            JSONObject json = new JSONObject(params);
            // json.getString("wh")
            JSONArray rows = JbSql.rsToJson("Select * From " + json.getString("view")
                    + (json.isNull("wh") ? "" : " Where " + json.getString("wh")), conn);
            res.put("rows", rows);
            res.put("success", true);
        } catch (Exception e) {
            ExcMsg.call(res, e, conn);
        } finally {
            DB.done(conn);
        }
        return res.toString();
    }

    public String signUp(String params) throws Exception {
        JSONObject jo = new JSONObject(params);
        JSONObject res = new JSONObject();
        Connection conn = DB.con(hds);
        JbSql sql = null;
        String method = jo.getString("method");
        res.put("success", true);
        try {
            if (method.equals("userReg")) {
                sql = new JbSql("Core_User.User_Reg", conn, true);
                sql.addParam(params, 2);
                sql.addParam(encoder.encode(jo.getString("password").replace("\"", "")), 3);
                sql.exec();
                //
                JSONObject obj = new JSONObject(params);
                Authentication authentication = authenticationManager.authenticate(
                        new UsernamePasswordAuthenticationToken(obj.getString("login"), obj.getString("password")));
                SecurityContextHolder.getContext().setAuthentication(authentication);
                UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();
                String jwt = jwtUtils.generateJwtToken(authentication);
                res.put("userId", sql.getResult());
                res.put("jwt", jwt);
                res.put("expiresIn", jwtExpirationMs.toString());
                res.put("firstName", obj.getString("firstName"));
                res.put("lastName", obj.getString("lastName"));
                res.put("patronymicName", obj.getString("patronymicName"));
            } else {
                sql = new JbSql("Core_App.Set_Method", conn, false);
                sql.addParam(params, 1);
                sql.addOut(Types.VARCHAR, 2);
                sql.exec();
            }
        } catch (Exception e) {
            ExcMsg.call(res, e, conn);
        } finally {
            DB.done(conn);
        }
        return res.toString();
    }

    public String addEditUser(String params) throws Exception {
        JSONObject jo = new JSONObject(params);
        JSONObject res = new JSONObject();
        res.put("success", true);
        Connection conn = DB.con(hds);
        JbSql sql = null;
        setDbSession(conn);
        try {
            sql = new JbSql("Core_User.Add_Edit_User", conn, false);
            sql.addParam(params, 1);
            sql.addParam(encoder.encode(jo.getString("password")), 2);
            //sql.addParam(jo.getString("phoneNum"), 3);
            //sql.addParam("forgotPassword", 4);
            sql.exec();
            res.put("message", "successSave");
        } catch (Exception e) {
            ExcMsg.call(res, e, conn);
        } finally {
            DB.done(conn);
        }
        return res.toString();
    }
    public String updatePassword(String params) throws Exception {
        JSONObject jo = new JSONObject(params);
        JSONObject res = new JSONObject();
        res.put("success", true);
        Connection conn = DB.con(hds);
        JbSql sql = null;
        setDbSession(conn);
        try {
            sql = new JbSql("Core_User.Edit_User_Password", conn, false);
            sql.addParam(params, 1);
            sql.addParam(encoder.encode(jo.getString("password")), 2);
            sql.addParam(jo.getString("phoneNum"), 3);
            sql.addParam("forgotPassword", 4);
            sql.exec();
            res.put("message", "successSave");
        } catch (Exception e) {
            ExcMsg.call(res, e, conn);
        } finally {
            DB.done(conn);
        }
        return res.toString();
    }

    public String confirmCode(String params) throws Exception {
        JSONObject jo = new JSONObject(params);
        JSONObject res = new JSONObject();
        Connection conn = DB.con(hds);
        JbSql sql = null;
        String method = jo.getString("method");
        res.put("success", true);
        try {
            if (method.equals("sendConfirmCode")) {
                sql = new JbSql("Core_User.Send_Conf_Code", conn, false);
                sql.addParam(params, 1);
                sql.exec();
            } else if (method.equals("checkConfirmCode")) {
                sql = new JbSql("Core_User.Check_Confirm_Code", conn, false);
                sql.addParam(params, 1);
                sql.addOut(Types.CLOB, 2);
                sql.exec();
                boolean isOper;
                String outAddStr = (String) sql.getOutVal(2);
                if (outAddStr != null) {
                    JSONObject outObj = new JSONObject(outAddStr);
                    isOper = outObj.has("oper") && !outObj.isNull("oper") && outObj.getBoolean("oper");
                    String message = outObj.has("message") && !outObj.isNull("message") ? outObj.getString("message") : "";
                    if (outObj.has("message") && !outObj.isNull("message")) {
                        res.put("message", message);
                    }
                    if (outObj.has("oper") && !outObj.isNull("oper")) {
                        res.put("oper", isOper);
                    }
                    outObj.remove("oper");
                    outObj.remove("message");
                    res.put("data", outObj);
                }
            }
        } catch (Exception e) {
            ExcMsg.call(res, e, conn);
        } finally {
            DB.done(conn);
        }
        return res.toString();
    }

    public void setDbSession(Connection connection) throws Exception {
        String headerAuth = req.getHeader("Authorization");
        if (StringUtils.hasText(headerAuth) && headerAuth.startsWith("Bearer ")) {
            headerAuth = headerAuth.substring(7, headerAuth.length());
        }
        Claims claims = jwtUtils.getAllClaimsFromToken(headerAuth);
        if (claims == null){
            throw  new HttpStatusCodeException(HttpStatus.FORBIDDEN) {
                @Override
                public HttpStatus getStatusCode() {
                    return super.getStatusCode();
                }
            };
        }
        OracleConnection conn = connection.unwrap(OracleConnection.class);
        JbSql form = new JbSql("Core_Session.Set_User_Session", conn, false);
        String userId = claims.get("userId").toString();

        String filialCode = claims.get("filialCode") != null ? claims.get("filialCode").toString() : null;
        /*
        String lang = JbUtil.nvl(req.getHeader("lang"), "");
        */
        try {
            form.addParam(userId, 1);

            boolean hasFilial = false;
            if (filialCode != null && !"".equals(filialCode)) {
                form.addParam(filialCode, 2);
                hasFilial = true;
            }
            /*
            if (!lang.equals(""))
                form.addParam(lang, hasClient ? 3 : 2);
            */
            form.exec();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public void setDbSession(Connection connection, JSONObject json) throws Exception {
        String headerAuth = req.getHeader("Authorization");
        if (StringUtils.hasText(headerAuth) && headerAuth.startsWith("Bearer ")) {
            headerAuth = headerAuth.substring(7, headerAuth.length());
        }
        Claims claims = jwtUtils.getAllClaimsFromToken(headerAuth);
        if (claims == null){
            throw  new HttpStatusCodeException(HttpStatus.FORBIDDEN) {
                @Override
                public HttpStatus getStatusCode() {
                    return super.getStatusCode();
                }
            };
        }
        OracleConnection conn = connection.unwrap(OracleConnection.class);
        JbSql form = new JbSql("Core_Session.Set_User_Session", conn, false);
        String userId = claims.get("userId").toString();
        String filialCode = json.isNull("filialCode") ? null : json.getString("filialCode");
        String lang = nvl(req.getHeader("lang"), "");
        try {
            boolean hasFilial = false;
            form.addParam(userId, 1);
            if (filialCode != null && !"".equals(filialCode)) {
                form.addParam(filialCode, 2);
                hasFilial = true;
            }
            if (!lang.equals(""))
                form.addParam(lang, hasFilial ? 3 : 2);
            form.exec();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public void setCustomDbSession(Connection connection, JSONObject json) throws Exception {
        OracleConnection conn = connection.unwrap(OracleConnection.class);
        JSONArray customSessions = json.isNull("c") ? null : json.getJSONArray("cSns"); // customSessions
        if (customSessions != null) {
            try {
                for (int n = 0; n < customSessions.length(); n++) {
                    JSONObject obj = customSessions.getJSONObject(n);
                    String contextName = obj.getString("contextName");
                    String value = obj.getString("value");
                    DB.ps(conn, "Begin Core_Session.Set_Context('" + contextName + "', '" + value + "'); End;");
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
    }

    public void loginLog(Long iuserId) throws Exception {
        Connection conn = DB.con(hds);
        JbSql form = new JbSql("Core_user.create_login", conn, false);
        String userId = iuserId.toString();
        try {
            form.addParam(userId, 1);
            form.exec();
        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            DB.done(conn);
        }
    }

    public void logOutLog() throws Exception {
        String headerAuth = req.getHeader("Authorization");
        if (StringUtils.hasText(headerAuth) && headerAuth.startsWith("Bearer ")) {
            headerAuth = headerAuth.substring(7, headerAuth.length());
        }
        Claims claims = jwtUtils.getAllClaimsFromToken(headerAuth);
        Authentication authentication = authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(claims.get("login").toString(), claims.get("password").toString()));
        SecurityContextHolder.getContext().setAuthentication(authentication);
        UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();
        String jwt = jwtUtils.generateJwtToken(authentication);
    }

    //Cr By: Arslonbek Kulmatov
    //Get method param values
    public JSONObject getMethodParamValue(String method_name, String column_name) {
        Connection conn = null;
        PreparedStatement ps = null;
        ResultSet res = null;
        String result = "{}";
        JSONObject response;
        try {
            conn = DB.con(hds);
            setDbSession(conn);
            ps = conn.prepareStatement("select "+ column_name +" from core_methods where upper(method) =  upper('" + method_name + "')");
            res = ps.executeQuery();
            if (res.next()) {
                result = nvl(res.getString(column_name), "{}");
            }
        } catch (Exception e) {
            e.printStackTrace();
            result = "{}";
        } finally {
            DB.done(ps);
            DB.done(res);
            DB.done(conn);
        }

        response = new JSONObject(result);
        return response;
    }

    //Cr By: Arslonbek Kulmatov
    //Updating login and password
    public String updateLoginPassword(String params) throws Exception {
        JSONObject req_param = new JSONObject(params);
        JSONObject res = new JSONObject();
        Connection conn = DB.con(hds);
        JbSql sql;
        setDbSession(conn);
        try {
            sql = new JbSql("Core_User.Edit_Login_Password", conn, false);
            sql.addParam(req_param.getInt("user_id"), 1);
            sql.addParam(req_param.getString("new_login"), 2);
            sql.addParam(encoder.encode(req_param.getString("new_password")), 3);
            sql.exec();
            res.put("success", true);
            res.put("message", "Successfully updated.");
        } catch (Exception e) {
            ExcMsg.call(res, e, conn);
            res.put("success", false);
        } finally {
            DB.done(conn);
        }
        return res.toString();
    }
}


