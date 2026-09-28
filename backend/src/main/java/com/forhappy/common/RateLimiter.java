package com.forhappy.common;

import org.springframework.stereotype.Component;

import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/** 滑动窗口内存限流（登录/短信频控；分布式部署需替换为 Redis 实现） */
@Component
public class RateLimiter {

    private record Window(int limit, long windowMs) {}

    private final Map<String, Deque<Long>> hits = new ConcurrentHashMap<>();

    /** key 在 window 内超过 limit 次则拒绝 */
    public boolean allow(String key, int limit, long windowMs) {
        long now = System.currentTimeMillis();
        Deque<Long> deque = hits.computeIfAbsent(key, k -> new ArrayDeque<>());
        synchronized (deque) {
            while (!deque.isEmpty() && now - deque.peekFirst() > windowMs) {
                deque.pollFirst();
            }
            if (deque.size() >= limit) {
                return false;
            }
            deque.addLast(now);
            return true;
        }
    }
}
