package com.example.asaka.config;

import com.example.asaka.core.models.Grid_New;
import com.zaxxer.hikari.HikariDataSource;
import lombok.Data;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import org.springframework.web.context.annotation.SessionScope;
import org.springframework.web.util.WebUtils;

import javax.servlet.http.HttpServletRequest;

@Component
@SessionScope
@Data
public class Session {
    @Autowired HttpServletRequest req;
    @Autowired HikariDataSource hds;

    //Cr By: Arslonbek Kulmatov
    public void setGrid(Grid_New grid){
        //System.out.println("set_grid: "  + req.getRequestedSessionId());
        WebUtils.setSessionAttribute(req, "GRID_" + grid.getGrid_id(), grid);
        WebUtils.setSessionAttribute(req, "GRIDPAGESIZE_" + grid.getGrid_id(), grid.getPageSize());
    }

    //Cr By: Arslonbek Kulmatov
    public Grid_New getGrid(Integer gridId){
        //System.out.println("get_grid: "  + req.getRequestedSessionId());
        return (Grid_New) WebUtils.getSessionAttribute(req, "GRID_" + gridId);
    }

    //Cr By: Arslonbek Kulmatov
    public void addSession(String sessionName, String val){
        WebUtils.setSessionAttribute(req, sessionName, val);
    }

    //Cr By: Arslonbek Kulmatov
    public void removeGrid(Integer gridId) {
        WebUtils.setSessionAttribute(req, "GRID_" + gridId, null);
    }
}
