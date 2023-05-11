package com.example.asaka.core.controllers;

import org.json.JSONException;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;
import com.example.asaka.core.models.JwtResponse;
import com.example.asaka.core.services.SApp;
import com.example.asaka.core.services.SEkey;
import com.example.asaka.core.services.SUser;
import com.example.asaka.security.jwt.JwtUtils;
import com.example.asaka.security.services.UserDetailsImpl;
import com.example.asaka.security.services.UserDetailsServiceImpl;

import java.util.*;
import java.util.stream.Collectors;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/auth")
public class CAuth {

  @Autowired AuthenticationManager authenticationManager;
  @Autowired JwtUtils jwtUtils;
  @Autowired SApp sApp;
  @Value("${jwt.expirationMs}") private Integer jwtExpirationMs;
  @Autowired UserDetailsServiceImpl userDetailsService;
  @Autowired PasswordEncoder passwordEncoder;
  @Autowired SUser sUser;
  @Autowired SEkey sEkey;

  @RequestMapping(value = "/signin", produces = "application/json")
  public ResponseEntity<?> authenticateUser(@RequestBody String params) throws JSONException {
    try {
      UserDetailsImpl userDetails = null;
      String jwt = null;
      JSONObject json = new JSONObject(params);
      List<String> roles;

      try {
        Authentication authentication = authenticationManager.authenticate(new UsernamePasswordAuthenticationToken(json.getString("login"),
          json.getString("password")));
        SecurityContextHolder.getContext().setAuthentication(authentication);
        userDetails = (UserDetailsImpl) authentication.getPrincipal();
        jwt = jwtUtils.generateJwtToken(authentication);
        roles = userDetails.getAuthorities().stream()
          .map(item -> item.getAuthority())
          .collect(Collectors.toList());

      }
      catch (BadCredentialsException e){
        return sUser.getMsgEror("login.error");
      }
      //
      if (userDetails.getUserState().equals("P")) {
        return sUser.notActive();
      }

      // Saving log
      if (userDetails.getUserState().equals("A")) {
        try {
          sApp.loginLog(userDetails.getId());
        } catch (Exception e) {
          e.printStackTrace();
        }
      }
      return ResponseEntity.ok(new JwtResponse(jwt, jwtExpirationMs.toString(), userDetails.getId(), userDetails.getLogin(), userDetails.getFirstName(), userDetails.getLastName(), userDetails.getPatronymicName(), userDetails.isFirstLogon(), roles));
    } catch (Exception e) {
      e.printStackTrace();
    }
    return ResponseEntity.ok("");
  }

  // Select Filial
  @RequestMapping(value = "/selectFilial", produces = "application/json")
  public ResponseEntity<?> selectFilial(@RequestBody String params) throws JSONException {
    JwtResponse jwtResponse = new JwtResponse();
    String jwt = jwtUtils.generateJwtToken(params, jwtResponse);
    return ResponseEntity.ok(jwtResponse);
  }

  //signOut
  @PostMapping("/signout")
  @ResponseBody
  public void signout() throws Exception {
    sApp.logOutLog();
    //jwtUtils.generateJwtToken(authentication);
  }

  @RequestMapping(value = "/signup", produces = "application/json")
  public ResponseEntity<?> signupUser(@RequestBody String params) throws Exception {
    return ResponseEntity.ok(sApp.signUp(params));
  }

  @RequestMapping(value = "/register", produces = "application/json")
  public ResponseEntity<?> registerUser(@RequestBody String params) throws Exception {
    return ResponseEntity.ok(sApp.addEditUser(params));
  }

  @RequestMapping(value = "/updatePassword", produces = "application/json")
  public ResponseEntity<?> updatePassword(@RequestBody String params) throws Exception {
    return ResponseEntity.ok(sApp.updatePassword(params));
  }

    /*
	@RequestMapping(value = "/updateEmail", produces = "application/json")
	public ResponseEntity<?> updateEmail(@RequestBody String params) throws Exception {
		return ResponseEntity.ok(sApp.updateEmail(params));
	}*/

  @RequestMapping(value = "/confirmCode", produces = "application/json")
  public ResponseEntity<?> confirmCode(@RequestBody String params) throws Exception {
    return ResponseEntity.ok(sApp.confirmCode(params));
  }
}

