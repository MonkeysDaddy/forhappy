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

    /** 每小时清扫过期会话：validate 只清理被再次访问的 token，不再访问的会永久残留 */
    @org.springframework.scheduling.annotation.Scheduled(
            fixedDelay = 3_600_000, initialDelay = 3_600_000)
    public void sweepExpired() {
        Instant now = Instant.now();
        sessions.values().removeIf(s -> s.expiresAt().isBefore(now));
    }
}
