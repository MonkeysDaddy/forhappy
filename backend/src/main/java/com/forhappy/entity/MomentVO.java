package com.forhappy.entity;

import java.time.LocalDateTime;
import lombok.Data;

/** 动态流视图（含发布者信息与我是否点赞） */
@Data
public class MomentVO {
    private Long id;
    private String caption;
    private String photos; // JSON 字符串
    private Integer likesBase;
    private LocalDateTime createdAt;

    private Long userId;
    private String nickname;
    private String avatarUrl;
    private Integer gender;
    private Integer verified;
    private Integer memberTier;
    private String city;

    private Double distanceKm;
    private Integer likeCount;
    private Integer commentCount;
    private Boolean likedByMe;
}
