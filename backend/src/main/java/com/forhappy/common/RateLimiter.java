package com.forhappy.common;

import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** 滑动窗口内存限流（登录/短信频控；分布式部署需替换为 Redis 实现） */
@Component
public class RateLimiter {

    /** 记录每个 key 的命中时间戳与窗口宽度（窗口宽度供定期清扫判断过期） */
    private record Window(Deque<Long> hits, long windowMs) {}

    private final Map<String, Window> hits = new ConcurrentHashMap<>();

    /** key 在 window 内超过 limit 次则拒绝；窗口滑空后顺手移除该 key，防止 map 无限增长 */
    public boolean allow(String key, int limit, long windowMs) {
        long now = System.currentTimeMillis();
        boolean[] allowed = {false};
        hits.compute(key, (k, cur) -> {
            Deque<Long> dq = cur == null ? new ArrayDeque<>() : cur.hits();
            while (!dq.isEmpty() && now - dq.peekFirst() > windowMs) {
                dq.pollFirst();
            }
            if (dq.size() < limit) {
                dq.addLast(now);
                allowed[0] = true;
            }
            return dq.isEmpty() ? null : new Window(dq, windowMs);
        });
        return allowed[0];
    }

    /** 每小时清扫：把窗口已滑空但再无访问的 key（一次性手机号/IP 等）从表中移除 */
    @Scheduled(fixedDelay = 3_600_000, initialDelay = 3_600_000)
    public void sweep() {
        long now = System.currentTimeMillis();
        hits.keySet().forEach(key -> hits.computeIfPresent(key, (k, w) -> {
            Deque<Long> dq = w.hits();
            while (!dq.isEmpty() && now - dq.peekFirst() > w.windowMs()) {
                dq.pollFirst();
            }
            return dq.isEmpty() ? null : w;
        }));
    }
}
