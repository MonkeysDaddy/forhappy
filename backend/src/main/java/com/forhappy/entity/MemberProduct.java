package com.forhappy.entity;

import lombok.Data;

@Data
public class MemberProduct {
    private Long id;
    private Integer tier;
    private Integer durationDays;
    private Integer priceCents;
    private Integer originalCents;
    private Integer firstPriceCents;
    private String badge;
    private Integer status;
    private Integer sortOrder;
}
