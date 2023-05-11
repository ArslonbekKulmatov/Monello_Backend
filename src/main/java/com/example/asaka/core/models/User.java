package com.example.asaka.core.models;

import lombok.Data;
import java.util.List;

@Data
public class User {
    private Long id;
    private String login;
    private String password;
    private String filialCode;
    private String firstName;
    private String lastName;
    private String patronymicName;
    private String userState;
    List<Role> roles;
    private boolean firstLogon;
    private String checkSign = "N";
    private String ekeyId;
    private String refresh_token;

    private String clientId;
    List<Client> clients;
}