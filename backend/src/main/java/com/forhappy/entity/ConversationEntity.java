package com.forhappy.entity;

import lombok.Data;

@Data
public class ConversationEntity {
    private Long id;
    private Long matchId;
    private Long userA;
    private Long userB;
    private String lastMessage;
}
