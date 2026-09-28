package com.forhappy.common;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.lang.reflect.Field;
import java.util.Map;
import org.junit.jupiter.api.Test;

class RateLimiterTest {

    @Test
    void allowsWithinLimitAndDeniesBeyond() {
        RateLimiter limiter = new RateLimiter();
        assertTrue(limiter.allow("login:13800000001", 2, 60_000));
        assertTrue(limiter.allow("login:13800000001", 2, 60_000));
        assertFalse(limiter.allow("login:13800000001", 2, 60_000), "超过 limit 应拒绝");
    }

    @Test
    void windowSlidesAfterExpiry() throws InterruptedException {
        RateLimiter limiter = new RateLimiter();
        assertTrue(limiter.allow("k", 1, 80));
        assertFalse(limiter.allow("k", 1, 80));
        Thread.sleep(120); // 窗口滑过
        assertTrue(limiter.allow("k", 1, 80), "窗口过期后应重新放行");
    }

    @Test
    void keysAreIsolated() {
        RateLimiter limiter = new RateLimiter();
        assertTrue(limiter.allow("a", 1, 60_000));
        assertTrue(limiter.allow("b", 1, 60_000), "不同 key 互不影响");
    }

    @Test
    @SuppressWarnings("unchecked")
    void sweepRemovesExpiredIdleKeys() throws Exception {
        RateLimiter limiter = new RateLimiter();
        limiter.allow("idle-key", 1, 80);
        limiter.allow("fresh-key", 1, 600_000);
        Thread.sleep(120); // idle-key 窗口滑空

        limiter.sweep();

        Field field = RateLimiter.class.getDeclaredField("hits");
        field.setAccessible(true);
        Map<String, ?> hits = (Map<String, ?>) field.get(limiter);
        assertFalse(hits.containsKey("idle-key"), "过期且不再访问的 key 应被清扫");
        assertTrue(hits.containsKey("fresh-key"), "窗口内的 key 必须保留");
    }
}
