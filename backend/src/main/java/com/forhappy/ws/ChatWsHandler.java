package com.forhappy.ws;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.forhappy.chat.ChatService;
import com.forhappy.entity.Message;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

/**
 * /ws/chat 长连接（设计 9.4）：
 * 下行帧 {"type":"message"|"match"}；上行帧支持 {"type":"auth"|"ping"|"send",convId,type,content}。
 * 鉴权为首帧认证：连接建立后 5 秒内须发 {"type":"auth","token":"<JWT>"}，
 * 校验通过后 uid 存于 session attributes，此前的其他帧一律拒绝。
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ChatWsHandler extends TextWebSocketHandler {

    public static final String ATTR_UID = "uid";

    private static final long AUTH_DEADLINE_MS = 5_000;

    private final WsPushService pushService;
    private final ChatService chatService;
    private final com.forhappy.common.JwtUtil jwtUtil;
    private final com.forhappy.mapper.MessageMapper messageMapper;
    private final com.forhappy.mapper.ConversationMapper conversationMapper;

    private static final ObjectMapper JSON = new ObjectMapper();

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        // 5 秒未完成认证则主动断开（调度器兜底，不依赖客户端再来一帧）
        session.getAttributes().put("authDeadline", System.currentTimeMillis() + AUTH_DEADLINE_MS);
        java.util.concurrent.ScheduledFuture<?> killer = authKiller.schedule(() -> {
            try {
                if (attrUid(session) == null && session.isOpen()) {
                    session.close(CloseStatus.POLICY_VIOLATION);
                }
            } catch (Exception ignored) {
            }
        }, AUTH_DEADLINE_MS, java.util.concurrent.TimeUnit.MILLISECONDS);
        session.getAttributes().put("authKiller", killer);
    }

    private static final java.util.concurrent.ScheduledExecutorService authKiller =
        java.util.concurrent.Executors.newScheduledThreadPool(1, r -> {
            Thread t = new Thread(r, "ws-auth-killer");
            t.setDaemon(true);
            return t;
        });

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message)
            throws Exception {
        JsonNode frame;
        try {
            frame = JSON.readTree(message.getPayload());
        } catch (Exception e) {
            return;
        }
        String type = frame.path("type").asText("");
        Long uid = attrUid(session);
        // 未认证：只接受 auth 帧（含超时检查）
        if (uid == null) {
            if ("auth".equals(type)) {
                handleAuth(session, frame);
            } else if (System.currentTimeMillis() > authDeadline(session)) {
                session.close(CloseStatus.POLICY_VIOLATION);
            }
            return;
        }
        switch (type) {
            case "ping" -> pushService.pushToUser(uid, "{\"type\":\"pong\"}");
            case "read" -> {
                // 已读回执（权益 4.8）：标记已读并把事件推给对方
                long convId = frame.path("convId").asLong();
                messageMapper.markRead(convId, uid);
                Map<String, Object> ev = new java.util.HashMap<>();
                ev.put("type", "read");
                ev.put("convId", convId);
                ev.put("reader", uid);
                // 对方在线才推；不在线无需推送（读状态以库为准）
                java.util.List<Long> members = conversationMapper.membersOf(convId);
                for (Long peer : members) {
                    if (peer != null && peer != uid) {
                        pushService.pushToUser(peer, JSON.writeValueAsString(ev));
                    }
                }
            }
            case "send" -> {
                long convId = frame.path("convId").asLong();
                int msgType = frame.path("msgType").asInt(1);
                String content = frame.path("content").asText("");
                try {
                    Message m = chatService.send(convId, uid, msgType, content);
                    // 回执：带上原帧 tempId 便于客户端乐观更新对齐
                    Map<String, Object> ack = new java.util.HashMap<>();
                    ack.put("type", "sent");
                    ack.put("tempId", frame.path("tempId").asText(""));
                    ack.put("message", m);
                    pushService.pushToUser(uid, JSON.writeValueAsString(ack));
                } catch (Exception e) {
                    Map<String, Object> err = new java.util.HashMap<>();
                    err.put("type", "error");
                    err.put("tempId", frame.path("tempId").asText(""));
                    err.put("msg", e.getMessage() != null ? e.getMessage() : "发送失败");
                    pushService.pushToUser(uid, JSON.writeValueAsString(err));
                }
            }
            default -> log.debug("未知 WS 帧 type={}", type);
        }
    }

    /** 首帧认证：JWT 校验通过 → 注册 uid 并立即补一条 pong 作确认 */
    private void handleAuth(WebSocketSession session, JsonNode frame) throws Exception {
        String token = frame.path("token").asText("");
        Long uid = token.isBlank() ? null : jwtUtil.parse(token);
        if (uid == null) {
            session.close(CloseStatus.POLICY_VIOLATION);
            return;
        }
        session.getAttributes().put(ATTR_UID, uid);
        Object killer = session.getAttributes().get("authKiller");
        if (killer instanceof java.util.concurrent.ScheduledFuture<?> f) {
            f.cancel(false);
        }
        pushService.register(uid, session);
        pushService.pushToUser(uid, "{\"type\":\"pong\"}");
        log.info("WS auth ok uid={}", uid);
    }

    private static long authDeadline(WebSocketSession session) {
        Object v = session.getAttributes().get("authDeadline");
        return v instanceof Long l ? l : 0L;
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        Object killer = session.getAttributes().get("authKiller");
        if (killer instanceof java.util.concurrent.ScheduledFuture<?> f) {
            f.cancel(false);
        }
        Long uid = attrUid(session);
        if (uid != null) {
            pushService.unregister(uid, session);
            log.info("WS offline uid={} status={}", uid, status);
        }
    }

    @Override
    public void handleTransportError(WebSocketSession session, Throwable error) {
        Long uid = attrUid(session);
        if (uid != null) {
            pushService.unregister(uid, session);
        }
    }

    private static Long attrUid(WebSocketSession session) {
        Object v = session.getAttributes().get(ATTR_UID);
        return v instanceof Long l ? l : null;
    }
}
