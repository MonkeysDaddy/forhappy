package com.forhappy.entity;

import java.time.LocalDateTime;
import lombok.Data;

@Data
public class Message {
    private Long id;
    private Long convId;
    private Long fromUser;
    private Integer type;
    private String content;
    private java.time.LocalDateTime readAt;
    private LocalDateTime createdAt;
}
