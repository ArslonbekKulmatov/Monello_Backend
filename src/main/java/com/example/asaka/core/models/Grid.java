package com.example.asaka.core.models;

import lombok.Data;

@Data
public class Grid {

    String rows;
    String filters;

    public Grid(String rows, String filters) {
        this.rows = rows;
        this.filters = filters;
    }
}

