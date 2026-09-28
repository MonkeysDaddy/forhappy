package com.forhappy.entity;

import java.time.LocalDate;
import java.time.LocalDateTime;
import lombok.Data;

@Data
public class User {
    private Long id;
    private String phoneHash;
    private String phoneEnc;
    private String nickname;
    private String avatarUrl;
    private Integer gender;
    private Integer preferGender;
    private LocalDate birthday;
    private String city;
    private Integer heightCm;
    private Integer weightKg;
    private String education;
    private String occupation;
    private String income;
    private String bio;
    private String tags; // JSON 字符串
    private Integer verified;
    private Integer memberTier;
    private LocalDateTime memberExpireAt;
    private String wechat;
    private String instagram;
    private String facebook;
    private Double lat;
    private Double lng;
    private Integer lastActiveMinutes;
    private Integer eloScore;
    private Integer hideDistance;
    private String socialShowcase;
    private java.time.LocalDateTime muteUntil;
    private java.time.LocalDateTime socialExpireAt;
    private Integer status;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
