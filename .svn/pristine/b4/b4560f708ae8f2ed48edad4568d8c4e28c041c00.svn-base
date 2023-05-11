package com.example.asaka.security.services;

import lombok.Data;
import net.minidev.json.annotate.JsonIgnore;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import com.example.asaka.core.models.Client;
import com.example.asaka.core.models.Role;
import com.example.asaka.core.models.User;

import java.util.*;
import java.util.stream.Collectors;

@Data
public class UserDetailsImpl implements UserDetails {

    private static final long serialVersionUID = 1L;

    private Long id;
    private String firstName;
    private String lastName;
    private String patronymicName;
    private String login;
    private String clientId;
    private String userState;
    private boolean firstLogon;
    private String checkSign = "N";
    private String ekeyId;
    private List<Client> clients;

    @JsonIgnore
    private String password;

    private Collection<? extends GrantedAuthority> authorities;

    public UserDetailsImpl(Long id, String login, String firstName,
                           String lastName, String patronymicName,
                           List<Client> clients, String password,
                           String userState, boolean firstLogon, String checkSign, String ekeyId,
                           Collection<? extends GrantedAuthority> authorities) {
        this.id = id;
        this.login = login;
        this.firstName = firstName;
        this.lastName = lastName;
        this.patronymicName = patronymicName;
        this.clients = clients;
        this.password = password;
        this.userState = userState;
        this.firstLogon = firstLogon;
        this.checkSign = checkSign;
        this.ekeyId = ekeyId;
        this.authorities = authorities;

    }

    public static UserDetailsImpl build(User user) {
        List<Role> roles = new ArrayList<>();
        Role rol = new Role();
        rol.setId(1);
        rol.setName("ROLE_USER");
        roles.add(rol);
        user.setRoles(roles);
        List<GrantedAuthority> authorities = user.getRoles().stream()
                .map(role -> new SimpleGrantedAuthority(role.getName()))
                .collect(Collectors.toList());
        return new UserDetailsImpl(user.getId(),
                user.getLogin(),
                user.getFirstName(),
                user.getLastName(),
                user.getPatronymicName(),
                user.getClients(),
                user.getPassword(),
                user.getUserState(),
                user.isFirstLogon(),
                user.getCheckSign(),
                user.getEkeyId(),
                authorities);
    }

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return authorities;
    }

    @Override
    public String getUsername() {
        return firstName;
    }

    public String getUserState() {
        return userState;
    }

    @Override
    public String getPassword() {
        return password;
    }

    @Override
    public boolean isAccountNonExpired() {
        return true;
    }

    @Override
    public boolean isAccountNonLocked() {
        return true;
    }

    @Override
    public boolean isCredentialsNonExpired() {
        return true;
    }

    @Override
    public boolean isEnabled() {
        return true;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o)
            return true;
        if (o == null || getClass() != o.getClass())
            return false;
        UserDetailsImpl user = (UserDetailsImpl) o;
        return Objects.equals(id, user.id);
    }

}

