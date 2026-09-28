package com.forhappy.discover;

import com.forhappy.entity.User;
import com.forhappy.entity.UserCardVO;
import com.forhappy.social.SocialService;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import org.springframework.stereotype.Service;

/**
 * 推荐排序打分（设计 5.1-5.3 简化版，MVP 无 Redis 预计算、实时打分）：
 * score = 0.35·距离分 + 0.25·兴趣交集分 + 0.20·活跃度分 + 0.20·Elo分
 * 新注册 24h 内 1.5 倍曝光加权；每页注入 ≥20%"分数带外"用户防信息茧房。
 */
@Service
public class RecommendService {

    private static final double W_DISTANCE = 0.35;
    private static final double W_TAGS = 0.25;
    private static final double W_ACTIVITY = 0.20;
    private static final double W_ELO = 0.20;

    private static final double MAX_DIST_KM = 50;
    private static final int ACTIVE_WINDOW_MINUTES = 14 * 24 * 60; // 14 天未活跃归零

    /** 对候选集打分排序（确定性：score desc, id asc），保证游标分页稳定 */
    public List<UserCardVO> rank(User me, List<UserCardVO> candidates) {
        List<String> myTags = SocialService.parseTags(me.getTags());
        record Scored(UserCardVO card, double score) {}
        List<Scored> scored = candidates.stream()
                .map(c -> new Scored(c, score(me, c, myTags)))
                .sorted(Comparator.comparingDouble(Scored::score).reversed()
                        .thenComparingLong(s -> s.card().getId()))
                .map(s -> s)
                .toList();
        List<UserCardVO> sorted = scored.stream().map(Scored::card).toList();
        return injectDiversity(sorted);
    }

    double score(User me, UserCardVO c, List<String> myTags) {
        // 距离分：1 - dist/50（SQL 已按 maxDist 硬过滤）
        double dist = c.getDistanceKm() == null ? MAX_DIST_KM : c.getDistanceKm();
        double distScore = 1 - Math.min(dist / MAX_DIST_KM, 1);
        // 兴趣交集分：交集数/3 封顶
        List<String> tags = SocialService.parseTags(c.getTags());
        long overlap = tags.stream().filter(myTags::contains).count();
        double tagScore = Math.min(overlap / 3.0, 1);
        // 活跃度分：14 天窗口线性衰减（"死"用户趋近 0 分）
        int active = c.getLastActiveMinutes() == null ? ACTIVE_WINDOW_MINUTES : c.getLastActiveMinutes();
        double activityScore = 1 - Math.min((double) active / ACTIVE_WINDOW_MINUTES, 1);
        // Elo 分：1000-1400 归一
        int elo = c.getEloScore() == null ? 1200 : c.getEloScore();
        double eloScore = Math.max(0, Math.min((elo - 1000) / 400.0, 1));

        double s = W_DISTANCE * distScore + W_TAGS * tagScore
                + W_ACTIVITY * activityScore + W_ELO * eloScore;
        // 新用户保护（设计 5.3）：注册 24h 内 1.5 倍曝光加权
        if (c.getCreatedAt() != null
                && c.getCreatedAt().isAfter(LocalDateTime.now().minus(Duration.ofHours(24)))) {
            s *= 1.5;
        }
        // 会员曝光加权（权益 4.8）：SVIP 优先曝光 +15%，VIP +8%
        int tier = c.getMemberTier() == null ? 0 : c.getMemberTier();
        if (tier == 2) {
            s *= 1.15;
        } else if (tier == 1) {
            s *= 1.08;
        }
        return s;
    }

    /**
     * 多样性注入（设计 5.3）：第 5、10、15…位从尾部（低分段）取，保证每页 ≥20% 带外。
     * 输入需已按分数降序；输出确定性（同输入同输出），游标分页安全。
     */
    List<UserCardVO> injectDiversity(List<UserCardVO> sorted) {
        if (sorted.size() < 10) {
            return sorted;
        }
        List<UserCardVO> head = new ArrayList<>(sorted.subList(0, (int) (sorted.size() * 0.8)));
        List<UserCardVO> tail = new ArrayList<>(sorted.subList((int) (sorted.size() * 0.8), sorted.size()));
        List<UserCardVO> out = new ArrayList<>(sorted.size());
        int tailIdx = 0;
        for (int i = 0; i < sorted.size(); i++) {
            if ((i + 1) % 5 == 0 && tailIdx < tail.size()) {
                out.add(tail.get(tailIdx++));
            } else if (!head.isEmpty()) {
                out.add(head.remove(0));
            } else {
                out.add(tail.get(tailIdx++));
            }
        }
        return out;
    }
}
