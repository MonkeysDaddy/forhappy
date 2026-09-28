package com.forhappy.entity;

import java.time.LocalDateTime;
import lombok.Data;

@Data
public class MomentCommentVO {
    private Long id;
    private Long momentId;
    private Long userId;
    private String author;
    private String content;
    private LocalDateTime createdAt;
}
