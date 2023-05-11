package com.example.asaka.security.services;

import com.zaxxer.hikari.HikariDataSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;
import com.example.asaka.core.models.User;
import com.example.asaka.util.DB;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

@Service
public class UserDetailsServiceImpl implements UserDetailsService {

    @Autowired
    HikariDataSource hds;

    @Override
    public UserDetails loadUserByUsername(String userName) throws UsernameNotFoundException {
        return UserDetailsImpl.build(findByLogin(userName));
    }

    public User findByLogin(String login) {
        Connection conn = null;
        PreparedStatement ps = null;
        ResultSet rs = null;
        User user = new User();
        try {
            conn = DB.con(hds);
            ps = conn.prepareStatement("Select t.* " +
                                           "  From Core_Users t " +
                                           " Where lower(login) = lower(?)");
            ps.setString(1, login);
            ps.execute();
            rs = ps.getResultSet();
            if (rs.next()) {
                user.setId(rs.getLong("User_Id"));
                user.setLogin(rs.getString("Login"));
                user.setPassword(rs.getString("Password"));
                user.setFirstName(rs.getString("First_Name"));
                user.setLastName(rs.getString("Last_Name"));
                user.setPatronymicName(rs.getString("Patronymic_Name"));
                user.setUserState(rs.getString("State"));
                user.setFirstLogon(rs.getString("First_Logon").equals("Y"));
//                user.setCheckSign(rs.getString("Check_Sign_Onlogon"));
//                user.setEkeyId(rs.getString("Ekey_Id"));
            }
        } catch (Exception e) {
            e.printStackTrace();
            throw new UsernameNotFoundException(String.format("No user found with userName '%s'" + login));
        } finally {
            DB.done(conn);
            DB.done(ps);
            DB.done(rs);
        }
        return user;
    }
}

