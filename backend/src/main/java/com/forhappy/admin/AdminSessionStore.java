package com.forhappy.admin;

import org.springframework.stereotype.Component;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/** 管理员会话（内存版；分布式部署需换 Redis） */
@Component
public class AdminSessionStore {

    public record Session(String username, String role, Instant expiresAt) {}

    private static final long TTL_MS = 8 * 3600_000L; // 8 小时

    private final Map<String, Session> sessions = new ConcurrentHashMap<>();

    public String create(String username, String role) {
        String token = UUID.randomUUID().toString().replace("-", "");
        sessions.put(token, new Session(username, role,
                Instant.now().plusMillis(TTL_MS)));
        return token;
    }

    /** 校验会话，无效/过期返回 null */
    public Session validate(String token) {
        if (token == null || token.isBlank()) return null;
        Session s = sessions.get(token);
        if (s == null) return null;
        if (s.expiresAt().isBefore(Instant.now())) {
            sessions.remove(token);
            return null;
        }
        return s;
    }

    public void revokeAll() {
        sessions.clear();
    }
}
