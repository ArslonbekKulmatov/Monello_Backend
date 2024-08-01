package com.example.asaka.al.services;

import com.example.asaka.core.services.SApp;
import com.example.asaka.util.DB;
import com.zaxxer.hikari.HikariDataSource;
import org.apache.tomcat.util.codec.binary.Base64;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import org.openxmlformats.schemas.wordprocessingml.x2006.main.STLongHexNumber;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.security.core.parameters.P;
import org.springframework.stereotype.Service;

import java.nio.file.Path;
import java.nio.file.Paths;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.Objects;

import static com.example.asaka.util.JbUtil.nvl;

@Service
public class SAl {
    @Autowired HikariDataSource hds;
    @Autowired private SApp sApp;

    //Cr By: Arslonbek Kulmatov
    //Getting images by id
    public String getImageBase64(String params) throws JSONException {
        JSONObject json_params = new JSONObject(params);
        JSONObject response = new JSONObject();
        String encodedString;

        Connection conn = null;
        PreparedStatement ps = null;
        ResultSet res = null;
        try {
            conn = DB.con(hds);
            String object_type = json_params.getString("object_type");
            String sql = null;
            int object_id;
            float width;
            float height;
            if (object_type.equals("project")){
                object_id = json_params.getInt("project_id");
                sql = "select image, width, height, url from al_images where building_id is null and room_id is null and floor_id is null and project_id = " + object_id;
            }
            else if(object_type.equals("building")){
                object_id = json_params.getInt("building_id");
                sql = "select image, width, height, url from al_images where room_id is null and floor_id is null and building_id = " + object_id;
            }
            else if(object_type.equals("floor")){
                object_id = json_params.getInt("floor_id");
                sql = "select image, width, height, url from al_images where room_id is null and floor_id = " + object_id;
            }
            else if(object_type.equals("room")){
                object_id = json_params.getInt("room_id");
                sql = "select image, width, height, url from al_images where room_id = " + object_id;
            }
            ps = conn.prepareStatement(sql);
            res = ps.executeQuery();
            if (res.next()) {
                String url = nvl(res.getString("url"), "");
                width = res.getFloat("width");
                height = res.getFloat("height");
                if (!url.equals("")){
                    Path file = Paths.get( url.replace("\\", "/"));
                    Resource resource = new UrlResource(file.toUri());
                    byte[] fileContent = resource.getInputStream().readAllBytes();
                    encodedString= Base64.encodeBase64String(fileContent);
                    response.put("success", true);
                    response.put("encoded_image", encodedString);
                    response.put("width", width);
                    response.put("height", height);
                    return  response.toString();
                }
                byte[] imageContent = res.getBytes("image");
                encodedString = Base64.encodeBase64String(imageContent);

                response.put("success", true);
                response.put("encoded_image", encodedString);
                response.put("width", width);
                response.put("height", height);
            }
            else {
                response.put("success", false);
                response.put("error", "No image entered.");
            }
        } catch (Exception e) {
            response.put("success", false);
            response.put("error", e.getMessage());
            e.printStackTrace();
        } finally {
            DB.done(ps);
            DB.done(res);
            DB.done(conn);
        }
        return  response.toString();
    }

    //Cr By: Arslonbek Kulmatov
    //Getting user projects
    public String getUserProjectsWithImage(String params) throws JSONException {
        JSONObject json_params = new JSONObject(params);
        String user_id = json_params.getString("user_id");
        String sql;
        if (Objects.equals(user_id, "")){
            sql = "select t.id, t.name, t.image, t.width, t.height, t.url, t.is_animation_used from al_user_projects_v t where t.user_id = core_session.Get_User_Id order by t.id desc";
        }
        else {
            sql = "select t.id, t.name, t.image, t.width, t.height, t.url, t.is_animation_used from al_user_projects_v t where t.user_id = " + user_id + " order by t.id desc";
        }
        JSONObject project;
        JSONObject response = new JSONObject();
        JSONArray projects = new JSONArray();
        String encodedString;

        Connection conn = null;
        PreparedStatement ps = null;
        ResultSet res = null;
        try {
            conn = DB.con(hds);
            sApp.setDbSession(conn);
            ps = conn.prepareStatement(sql);
            res = ps.executeQuery();
            while (res.next()) {
                int project_id = res.getInt("id");
                String project_name = res.getString("name");
                float width = res.getFloat("width");
                float height = res.getFloat("height");
                byte[] imageContent = res.getBytes("image");
                String url = nvl(res.getString("url"), "");
                encodedString = Base64.encodeBase64String(imageContent);
                boolean is_animation_used = res.getBoolean("is_animation_used");

                project = new JSONObject();
                project.put("project_id", project_id);
                project.put("project_name", project_name);
                project.put("image", encodedString);
                project.put("image_width", width);
                project.put("image_height", height);
                project.put("image_url", url);
                project.put("is_animation_used", is_animation_used);

                projects.put(project);
            }
            response.put("success", true);
            response.put("projects", projects);
        } catch (Exception e) {
            response.put("success", false);
            response.put("error", e.getMessage());
            e.printStackTrace();
        } finally {
            DB.done(ps);
            DB.done(res);
            DB.done(conn);
        }
        return  response.toString();
    }

    //Cr By: Arslonbek Kulmatov
    //Getting building esps
    public JSONObject getBuildingEsps(int building_id) throws JSONException {
        JSONObject esp;
        JSONObject response = new JSONObject();
        JSONArray esps = new JSONArray();

        Connection conn = null;
        PreparedStatement ps = null;
        ResultSet res = null;
        try {
            conn = DB.con(hds);
            sApp.setDbSession(conn);
            ps = conn.prepareStatement("select * from al_building_esps_v where building_id = " + building_id);
            res = ps.executeQuery();
            while (res.next()) {
                int esp_id = res.getInt("code");
                String esp_name = res.getString("name");
                int light_count = res.getInt("light_count");

                esp = new JSONObject();
                esp.put("esp_id", esp_id);
                esp.put("esp_name", esp_name);
                esp.put("light_count", light_count);

                esps.put(esp);
            }
            response.put("success", true);
            response.put("esps", esps);
        } catch (Exception e) {
            response.put("success", false);
            response.put("error", e.getMessage());
            e.printStackTrace();
        } finally {
            DB.done(ps);
            DB.done(res);
            DB.done(conn);
        }
        return response;
    }

    //Cr By: Arslonbek Kulmatov
    //Getting project
    public JSONObject getProjectById(int project_id) throws JSONException {
        JSONObject project = new JSONObject();
        JSONObject response = new JSONObject();

        Connection conn = null;
        PreparedStatement ps = null;
        ResultSet res = null;
        try {
            conn = DB.con(hds);
            sApp.setDbSession(conn);
            ps = conn.prepareStatement("select * from al_projects_v where id = " + project_id);
            res = ps.executeQuery();
            if (res.next()) {
                String color = nvl(res.getString("color"), "FFFFFF");
                String animation_status = nvl(res.getString("animation_status"), "off");
                String lights_status = nvl(res.getString("lights_status"), "off");
                String name = nvl(res.getString("name"), "");

                project.put("color", color);
                project.put("animation", animation_status);
                project.put("lights", lights_status);
                project.put("project_name", name);
            }
            response.put("success", true);
            response.put("project", project);
        } catch (Exception e) {
            response.put("success", false);
            response.put("error", e.getMessage());
            e.printStackTrace();
        } finally {
            DB.done(ps);
            DB.done(res);
            DB.done(conn);
        }
        return response;
    }

    //Cr By: Arslonbek Kulmatov
    //Getting project buildings
    public String getProjectBuildings(String params) throws JSONException {
        JSONObject json_params = new JSONObject(params);
        int project_id = json_params.getInt("project_id");

        JSONObject building;
        JSONObject response = new JSONObject();
        JSONArray buildings = new JSONArray();
        String encodedString;

        Connection conn = null;
        PreparedStatement ps = null;
        ResultSet res = null;
        try {
            conn = DB.con(hds);
            sApp.setDbSession(conn);
            ps = conn.prepareStatement("select t.project_id, " +
                                           "t.building_id, " +
                                           "t.building_name, " +
                                           "t.coordinates, " +
                                           "t.image, " +
                                           "t.width, " +
                                           "t.url, " +
                                           "t.height from AL_PROJECT_BUILDINGS_V t where t.project_id = " + project_id + " order by t.building_id desc");
            res = ps.executeQuery();
            while (res.next()) {
                int building_id = res.getInt("building_id");
                String building_name = res.getString("building_name");
                String coordinates = res.getString("coordinates");
                float width = res.getFloat("width");
                float height = res.getFloat("height");
//                byte[] imageContent = res.getBytes("image");
                String url = nvl(res.getString("url"), "");
                encodedString = "";
//                encodedString = Base64.encodeBase64String(imageContent);
                JSONObject esp = getBuildingEsps(building_id);
                JSONArray esps;
                if (esp.getBoolean("success")){
                    esps = esp.getJSONArray("esps");
                }
                else {
                    esps = null;
                }
                building = new JSONObject();
                building.put("project_id", project_id);
                building.put("building_id", building_id);
                building.put("building_name", building_name);
                building.put("esps", esps);
                building.put("coordinates", coordinates);
                building.put("image", encodedString);
                building.put("image_width", width);
                building.put("image_height", height);
                building.put("image_url", url);

                buildings.put(building);
            }
            JSONObject project = getProjectById(project_id);
            response.put("success", true);
            if (project.getBoolean("success")){
                response.put("color", nvl(project.getJSONObject("project").getString("color"), "FFFFFF"));
                response.put("animation", nvl(project.getJSONObject("project").getString("animation"), "off"));
                response.put("lights", nvl(project.getJSONObject("project").getString("lights"), "off"));
                response.put("project_name", nvl(project.getJSONObject("project").getString("project_name"), ""));
            }

            response.put("buildings", buildings);
        } catch (Exception e) {
            response.put("success", false);
            response.put("error", e.getMessage());
            e.printStackTrace();
        } finally {
            DB.done(ps);
            DB.done(res);
            DB.done(conn);
        }
        return  response.toString();
    }

    //Cr By: Arslonbek Kulmatov
    //Getting building floors
    public String getBuildingFloors(String params) throws JSONException {
        JSONObject json_params = new JSONObject(params);
        int building_id = json_params.getInt("building_id");
        String encodedString;

        JSONObject floor;
        JSONObject response = new JSONObject();
        JSONArray floors = new JSONArray();

        Connection conn = null;
        PreparedStatement ps = null;
        ResultSet res = null;
        try {
            conn = DB.con(hds);
            sApp.setDbSession(conn);
            ps = conn.prepareStatement("select t.floor_id, " +
                    "t.building_id, " +
                    "t.name, " +
                    "t.image, " +
                    "t.width, " +
                    "t.height, " +
                    "t.is_block, " +
                    "t.esp_name, " +
                    "t.block_light_ids, " +
                    "t.url, " +
                    "t.coordinates from al_building_floors_v t where t.building_id = " + building_id + " order by t.floor_id desc");
            res = ps.executeQuery();
            while (res.next()) {
                int floor_id = res.getInt("floor_id");
                String floor_name = res.getString("name");
                boolean is_block = res.getBoolean("is_block");
                String esp_name = nvl(res.getString("esp_name"), "");
                String block_light_Ids = nvl(res.getString("block_light_ids"), "");
                String coordinates = res.getString("coordinates");
                float width = res.getFloat("width");
                float height = res.getFloat("height");
                byte[] imageContent = res.getBytes("image");
                String url = nvl(res.getString("url"), "");
                if(url.equals("")){
                    encodedString = Base64.encodeBase64String(imageContent);
                }
                else {
                    encodedString = "";
                }

                floor = new JSONObject();
                floor.put("is_block", is_block);
                floor.put("esp_name", esp_name);
                floor.put("block_light_ids", block_light_Ids);
                floor.put("floor_id", floor_id);
                floor.put("building_id", building_id);
                floor.put("floor_name", floor_name);
                floor.put("coordinates", coordinates);
                floor.put("image", encodedString);
                floor.put("image_width", width);
                floor.put("image_height", height);
                floor.put("image_url", url);

                floors.put(floor);
            }
            response.put("success", true);
            response.put("floors", floors);
        } catch (Exception e) {
            response.put("success", false);
            response.put("error", e.getMessage());
            e.printStackTrace();
        } finally {
            DB.done(ps);
            DB.done(res);
            DB.done(conn);
        }
        return  response.toString();
    }

    //Cr By: Arslonbek Kulmatov
    //Getting room coordinates
    public JSONObject getRoomCoordinates(int room_id) throws JSONException {
        JSONObject coordinate;
        JSONObject response = new JSONObject();
        JSONArray coordinates = new JSONArray();

        Connection conn = null;
        PreparedStatement ps = null;
        ResultSet res = null;
        try {
            conn = DB.con(hds);
            sApp.setDbSession(conn);
            ps = conn.prepareStatement("select * from al_room_coordinates where room_id = " + room_id);
            res = ps.executeQuery();
            while (res.next()) {
                String coordinates_data = res.getString("coordinates");
                coordinates.put(coordinates_data);
            }
            response.put("success", true);
            response.put("coordinates", coordinates);
        } catch (Exception e) {
            response.put("success", false);
            response.put("error", e.getMessage());
            e.printStackTrace();
        } finally {
            DB.done(ps);
            DB.done(res);
            DB.done(conn);
        }
        return response;
    }

    //Cr By: Arslonbek Kulmatov
    //Getting building rooms
    public String getBuildingRooms(String params) throws JSONException {
        JSONObject json_params = new JSONObject(params);
        int building_id = json_params.getInt("building_id");
        int floor_id = json_params.getInt("floor_id");

        JSONObject room;
        JSONObject response = new JSONObject();
        JSONArray rooms = new JSONArray();
        String encodedString;

        Connection conn = null;
        PreparedStatement ps = null;
        ResultSet res = null;
        try {
            conn = DB.con(hds);
            sApp.setDbSession(conn);
            ps = conn.prepareStatement("select t.id, " +
                    "t.building_id, " +
                    "t.floor_id, " +
                    "t.esp_id, " +
                    "t.esp_name, " +
                    "t.name, " +
                    "t.light_ids, " +
                    "t.image, " +
                    "t.width, " +
                    "t.url, " +
                    "t.height from al_building_rooms_v t where t.building_id = " + building_id + " and t.floor_id = " + floor_id + " order by t.id desc");
            res = ps.executeQuery();
            while (res.next()) {
                int room_id = res.getInt("id");
                int esp_id = res.getInt("esp_id");
                String esp_name = nvl(res.getString("esp_name"), "");
                String room_name = res.getString("name");
                String light_ids = res.getString("light_ids");
//                String coordinates = res.getString("coordinates");
                JSONObject coordinate = getRoomCoordinates(room_id);
                JSONArray coordinates;
                if (coordinate.getBoolean("success")){
                    coordinates = coordinate.getJSONArray("coordinates");
                }
                else {
                    coordinates = null;
                }
                float width = res.getFloat("width");
                float height = res.getFloat("height");
                byte[] imageContent = res.getBytes("image");
                String url = nvl(res.getString("url"), "");
                if(url.equals("")){
                    encodedString = Base64.encodeBase64String(imageContent);
                }
                else {
                    encodedString = "";
                }

                room = new JSONObject();
                room.put("building_id", building_id);
                room.put("esp_id", esp_id);
                room.put("esp_name", esp_name);
                room.put("floor_id", floor_id);
                room.put("room_id", room_id);
                room.put("room_name", room_name);
                room.put("light_ids", light_ids);
                room.put("coordinates", coordinates);
                room.put("image", encodedString);
                room.put("image_width", width);
                room.put("image_height", height);
                room.put("image_url", url);

                rooms.put(room);
            }
            response.put("success", true);
            response.put("rooms", rooms);
        } catch (Exception e) {
            response.put("success", false);
            response.put("error", e.getMessage());
            e.printStackTrace();
        } finally {
            DB.done(ps);
            DB.done(res);
            DB.done(conn);
        }
        return  response.toString();
    }

}
