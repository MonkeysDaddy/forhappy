package com.forhappy.entity;

import lombok.Data;

@Data
public class Photo {
    private Long id;
    private Long userId;
    private String url;
    private Integer sortOrder;
    private Integer isAvatar;
    private Integer reviewStatus;
}
