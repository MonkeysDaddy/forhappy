package com.forhappy.entity;

import java.time.LocalDateTime;
import lombok.Data;

/** 会话列表视图（含对方信息） */
@Data
public class ConversationVO {
    private Long id;
    private Long matchId;
    private String lastMessage;
    private Integer unread;
    private LocalDateTime updatedAt;

    private Long peerId;
    private String peerNickname;
    private String peerAvatarUrl;
    private Integer peerGender;
    private Integer peerVerified;
}
