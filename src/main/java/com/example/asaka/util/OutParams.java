package com.example.asaka.util;

import lombok.Data;

@Data
public class OutParams {

    public OutParams(Integer type, Integer ord) {
        this.type = type;
        this.ord = ord;
    }

    private Integer type;
    private Integer ord;

}

