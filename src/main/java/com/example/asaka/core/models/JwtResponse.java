package com.example.asaka.core.models;

import lombok.Data;
import java.util.List;
@Data
public class JwtResponse {

    private String token;
    private String type = "Bearer";
    private Long id;
    private String login;
    private String firstName;
    private String lastName;
    private String patronymicName;
    private List<String> roles;
    private String expiresIn;
    private boolean firstLogon;
    private String clientName = "";
    private String refresh_token;

    public JwtResponse() {
    }

    public JwtResponse(String token, String expiresIn, Long id, String login, String firstName, String lastName, String patronymicName, boolean firstLogon, List<String> roles) {
        this.token = token;
        this.expiresIn = expiresIn;
        this.id = id;
        this.login = login;
        this.firstName = firstName;
        this.lastName = lastName;
        this.patronymicName = patronymicName;
        this.firstLogon = firstLogon;
        this.roles = roles;
    }

    public JwtResponse(String token, String expiresIn, Long id, String login, String firstName, String lastName, String patronymicName, String clientName) {
        this.token = token;
        this.expiresIn = expiresIn;
        this.id = id;
        this.login = login;
        this.firstName = firstName;
        this.lastName = lastName;
        this.patronymicName = patronymicName;
        this.clientName = clientName;
    }

    public JwtResponse(String token, String expiresIn) {
        this.token = token;
        this.expiresIn = expiresIn;
    }

    public JwtResponse(String token, String expiresIn, Long id, String login, String firstName, String lastName, String patronymicName, boolean firstLogon, List<String> roles, String refresh_token) {
        this.token = token;
        this.expiresIn = expiresIn;
        this.id = id;
        this.login = login;
        this.firstName = firstName;
        this.lastName = lastName;
        this.patronymicName = patronymicName;
        this.firstLogon = firstLogon;
        this.roles = roles;
        this.refresh_token = refresh_token;
    }
}
