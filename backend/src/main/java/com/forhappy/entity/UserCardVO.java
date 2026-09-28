package com.forhappy.entity;

import lombok.Data;

/** 发现信息流 / 配对列表的用户卡片视图 */
@Data
public class UserCardVO {
    private Long id;
    private String nickname;
    private String avatarUrl;
    private Integer gender;
    private Integer age;
    private String city;
    private String occupation;
    private String bio;
    private String tags;
    private Integer verified;
    private Integer memberTier;
    private Integer lastActiveMinutes;
    private Boolean hasWechat;
    private Double distanceKm;
    private Integer eloScore;
    private java.time.LocalDateTime createdAt;
    private Boolean liked;
}
