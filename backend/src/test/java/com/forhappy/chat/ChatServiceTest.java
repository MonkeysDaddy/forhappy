package com.forhappy.chat;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.forhappy.common.BizException;
import com.forhappy.common.SensitiveWordStore;
import com.forhappy.entity.Message;
import com.forhappy.entity.User;
import com.forhappy.mapper.AdminManageMapper;
import com.forhappy.mapper.ConversationMapper;
import com.forhappy.mapper.MessageMapper;
import com.forhappy.mapper.UserMapper;
import com.forhappy.ws.WsPushService;
import java.time.LocalDateTime;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 聊天收发统一风控：HTTP 与 WS 共用 ChatService.send，
 * 敏感词必须在服务层拦截（修复 WS 路径绕过检查的缺陷）。
 */
@ExtendWith(MockitoExtension.class)
class ChatServiceTest {

    @Mock private ConversationMapper conversationMapper;
    @Mock private MessageMapper messageMapper;
    @Mock private UserMapper userMapper;
    @Mock private WsPushService wsPush;
    @Mock private SensitiveWordStore sensitiveWordStore;
    @Mock private AdminManageMapper violationMapper;

    private ChatService chatService;

    private static User sender() {
        User u = new User();
        u.setId(1L);
        u.setNickname("张三");
        return u;
    }

    @BeforeEach
    void setUp() {
        chatService = new ChatService(conversationMapper, messageMapper,
                userMapper, wsPush, sensitiveWordStore, violationMapper);
    }

    @Test
    void sensitiveWordBlockedWithViolationRecorded() {
        when(sensitiveWordStore.hit("加我微信聊聊")).thenReturn("微信");

        BizException e = assertThrows(BizException.class,
                () -> chatService.send(10L, 1L, 1, "加我微信聊聊"));

        assertEquals(400, e.getCode());
        // 违规流水必须落库（供后台处置），且消息不得入库、会话不得更新
        verify(violationMapper).insertViolation(1L, "chat", "加我微信聊聊", "微信");
        verify(messageMapper, never()).insert(any());
        verify(conversationMapper, never()).appendMessage(anyLong(), anyLong(), any());
    }

    @Test
    void cleanTextMessageDelivered() {
        when(sensitiveWordStore.hit("你好呀")).thenReturn(null);
        when(conversationMapper.findMine(10L, 1L)).thenReturn(77L);
        when(userMapper.findById(1L)).thenReturn(sender());
        when(conversationMapper.findPeer(10L, 1L)).thenReturn(2L);

        Message m = chatService.send(10L, 1L, 1, "你好呀");

        assertEquals("你好呀", m.getContent());
        assertEquals(1, m.getType());
        verify(messageMapper).insert(m);
        verify(conversationMapper).appendMessage(10L, 1L, "你好呀");
    }

    @Test
    void mediaMessageMustUseLocalFiles() {
        when(sensitiveWordStore.hit("https://evil.com/x.jpg")).thenReturn(null);
        when(conversationMapper.findMine(10L, 1L)).thenReturn(77L);
        when(userMapper.findById(1L)).thenReturn(sender());

        BizException e = assertThrows(BizException.class,
                () -> chatService.send(10L, 1L, 2, "https://evil.com/x.jpg"));

        assertEquals(400, e.getCode());
        verify(messageMapper, never()).insert(any());
    }

    @Test
    void mutedSenderRejected() {
        when(sensitiveWordStore.hit("在吗")).thenReturn(null);
        when(conversationMapper.findMine(10L, 1L)).thenReturn(77L);
        User muted = sender();
        muted.setMuteUntil(LocalDateTime.now().plusDays(1));
        when(userMapper.findById(1L)).thenReturn(muted);

        assertThrows(BizException.class, () -> chatService.send(10L, 1L, 1, "在吗"));
        verify(messageMapper, never()).insert(any());
    }

    @Test
    void textOver500CharsRejected() {
        String longText = "a".repeat(501);
        when(sensitiveWordStore.hit(longText)).thenReturn(null);
        when(conversationMapper.findMine(10L, 1L)).thenReturn(77L);
        when(userMapper.findById(1L)).thenReturn(sender());

        assertThrows(BizException.class, () -> chatService.send(10L, 1L, 1, longText));
        verify(messageMapper, never()).insert(any());
    }

    @Test
    void foreignConversationRejected() {
        when(sensitiveWordStore.hit("你好")).thenReturn(null);
        when(conversationMapper.findMine(10L, 1L)).thenReturn(null);

        BizException e = assertThrows(BizException.class,
                () -> chatService.send(10L, 1L, 1, "你好"));
        assertEquals(403, e.getCode());
        verify(messageMapper, never()).insert(any());
    }
}
