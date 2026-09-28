package com.forhappy.ws;

import java.io.IOException;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;

/** 在线连接注册表：uid → session（同 uid 后连踢前连，单设备在线） */
@Slf4j
@Service
public class WsPushService {

    private final Map<Long, WebSocketSession> sessions = new ConcurrentHashMap<>();

    public void register(long uid, WebSocketSession session) {
        WebSocketSession old = sessions.put(uid, session);
        if (old != null && old.isOpen()) {
            try {
                old.close();
            } catch (IOException ignored) {
            }
        }
        log.info("WS online uid={} total={}", uid, sessions.size());
    }

    public void unregister(long uid, WebSocketSession session) {
        sessions.remove(uid, session);
    }

    public boolean isOnline(long uid) {
        return sessions.containsKey(uid);
    }

    /** 向指定用户推送一帧 JSON；离线静默（消息仍可由 HTTP 拉取） */
    public void pushToUser(long uid, String json) {
        WebSocketSession session = sessions.get(uid);
        if (session == null || !session.isOpen()) {
            return;
        }
        try {
            // sendMessage 非线程安全，串行化发送
            synchronized (session) {
                session.sendMessage(new TextMessage(json));
            }
        } catch (Exception e) {
            log.warn("WS push uid={} failed: {}", uid, e.getMessage());
            sessions.remove(uid, session);
        }
    }
}
