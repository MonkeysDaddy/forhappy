package com.forhappy.social;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.forhappy.common.BizException;
import com.forhappy.common.Result;
import com.forhappy.entity.ConversationEntity;
import com.forhappy.mapper.BlockMapper;
import com.forhappy.mapper.ConversationMapper;
import com.forhappy.mapper.LikeMapper;
import com.forhappy.mapper.MatchMapper;
import com.forhappy.mapper.UserMapper;
import com.forhappy.entity.User;
import com.forhappy.ws.WsPushService;
import java.time.LocalDate;
import java.time.Period;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class SocialService {

    private final LikeMapper likeMapper;
    private final MatchMapper matchMapper;
    private final ConversationMapper conversationMapper;
    private final BlockMapper blockMapper;
    private final UserMapper userMapper;
    private final WsPushService wsPush;
    private final com.forhappy.mapper.NotificationMapper notificationMapper;

    @Value("${forhappy.like.daily-quota:30}")
    private int dailyQuota;

    @Transactional
    public Map<String, Object> like(long me, long to, int action) {
        if (me == to) {
            throw new BizException(400, "不能对自己操作");
        }
        if (blockMapper.exists(me, to) > 0 || blockMapper.exists(to, me) > 0) {
            throw new BizException(403, "无法与该用户互动");
        }
        Map<String, Object> data = new HashMap<>();
        if (action == 2) {
            likeMapper.insert(me, to, 2, 0);
            userMapper.adjustElo(to, -8); // 被隐藏降权（设计 5.2 惩罚项）
            data.put("hidden", true);
            return data;
        }
        if (action != 1 && action != 3) {
            throw new BizException(400, "无效操作");
        }
        User meUser = userMapper.findById(me);
        int myTier = meUser.getMemberTier() == null ? 0 : meUser.getMemberTier();
        // 超级喜欢（权益表 4.8）：会员专属，VIP 每日 1 次 / SVIP 每日 5 次，曝光加权 +40
        if (action == 3) {
            if (myTier <= 0) {
                throw new BizException(Result.NOT_MEMBER, "超级喜欢是会员权益，开通后每次都会置顶曝光");
            }
            int superQuota = myTier >= 2 ? 5 : 1;
            if (likeMapper.countSuperToday(me) >= superQuota) {
                throw new BizException(Result.QUOTA_EXCEEDED,
                        myTier >= 2 ? "今日超级喜欢已用完（SVIP 每日 5 次）" : "今日超级喜欢已用完（VIP 每日 1 次）");
            }
        }
        boolean member = myTier > 0;
        if (action == 1 && !member && likeMapper.countLikesToday(me) >= dailyQuota) {
            throw new BizException(Result.QUOTA_EXCEEDED, "今日喜欢次数已用完");
        }
        if (likeMapper.exists(me, to) > 0) {
            data.put("matched", false);
            data.put("already", true);
            return data;
        }
        boolean reverse = Integer.valueOf(1).equals(likeMapper.findAction(to, me))
                || Integer.valueOf(3).equals(likeMapper.findAction(to, me));
        likeMapper.insert(me, to, action, reverse ? 1 : 0);
        userMapper.adjustElo(to, action == 3 ? 40 : 10); // 被喜欢 +10 / 超级喜欢 +40（互动先验）
        notificationMapper.insert(to, "like",
                (action == 3 ? "有人超级喜欢了你" : "有人喜欢了你"),
                action == 3 ? "你的资料让对方心动了，把握机会" : "互相喜欢即可配对聊天");
        data.put("matched", reverse);
        data.put("super", action == 3);
        if (reverse) {
            userMapper.adjustElo(me, 25); // 互相喜欢双方再 +25
            userMapper.adjustElo(to, 25);
            long lo = Math.min(me, to);
            long hi = Math.max(me, to);
            User other = userMapper.findById(to);
            List<String> commonTags = commonTags(meUser, other);
            Long matchId = matchMapper.findActive(lo, hi);
            if (matchId == null) {
                matchMapper.insert(lo, hi, toJson(commonTags));
                matchId = matchMapper.findActive(lo, hi);
            }
            if (conversationMapper.findByMatch(matchId) == null) {
                ConversationEntity conv = new ConversationEntity();
                conv.setMatchId(matchId);
                conv.setUserA(lo);
                conv.setUserB(hi);
                conv.setLastMessage("配对成功，快打个招呼吧～");
                conversationMapper.insert(conv);
            }
            data.put("matchId", matchId);
            data.put("commonTags", commonTags);
            data.put("icebreakers", icebreakers(other, commonTags));
            // 配对即时推送（设计 4.4）：对方在线则经 WS 通知，文案不带隐私信息
            wsPush.pushToUser(to, "{\"type\":\"match\",\"matchId\":" + matchId + "}");
            notificationMapper.insert(me, "match", "配对成功！",
                    "你和 " + other.getNickname() + " 互相喜欢，去打个招呼吧");
            notificationMapper.insert(to, "match", "配对成功！",
                    "你和 " + meUser.getNickname() + " 互相喜欢，去打个招呼吧");
        }
        return data;
    }

    @Transactional
    public void unmatch(long me, long matchId) {
        matchMapper.deactivate(matchId);
        conversationMapper.deactivateByMatch(matchId);
    }

    /** 反悔（撤销喜欢/隐藏）：免费用户不可用，VIP 每日 5 次，SVIP 不限（设计 4.8） */
    @Transactional
    public Map<String, Object> undoLike(long me, long to) {
        User meUser = userMapper.findById(me);
        int tier = meUser.getMemberTier() == null ? 0 : meUser.getMemberTier();
        if (tier <= 0) {
            throw new BizException(Result.NOT_MEMBER, "反悔是 VIP 权益，开通后可撤销喜欢/隐藏");
        }
        int undoRemaining = -1;
        if (tier == 1) { // VIP 每日 5 次（先校验配额再执行撤销）
            String key = "undo:" + me + ":" + LocalDate.now().format(UNDO_DATE);
            int used = undoCounter.computeIfAbsent(key, k -> new java.util.concurrent.atomic.AtomicInteger())
                    .incrementAndGet();
            if (used > 5) {
                throw new BizException(Result.QUOTA_EXCEEDED, "今日反悔次数已用完（VIP 每日 5 次，SVIP 不限）");
            }
            undoRemaining = Math.max(5 - used, 0);
        }
        Map<String, Object> data = new HashMap<>();
        data.put("undone", likeMapper.delete(me, to) > 0);
        data.put("undoRemaining", undoRemaining);
        return data;
    }

    private static final java.time.format.DateTimeFormatter UNDO_DATE =
            java.time.format.DateTimeFormatter.ofPattern("yyyyMMdd");
    /** 单机内存计数（多实例部署换 Redis，同 AI 回复配额） */
    private final Map<String, java.util.concurrent.atomic.AtomicInteger> undoCounter =
            new java.util.concurrent.ConcurrentHashMap<>();

    /** 每小时清扫昨日及更早的反悔计数 key（uid:日期 每天新增一批，不清扫会无限堆积） */
    @org.springframework.scheduling.annotation.Scheduled(
            fixedDelay = 3_600_000, initialDelay = 3_600_000)
    public void sweepUndoCounters() {
        String today = LocalDate.now().format(UNDO_DATE);
        undoCounter.keySet().removeIf(k -> !k.endsWith(today));
    }

    // ---------- 共同点与破冰话术（设计 4.6：配对时计算，最多 3 条共同点 + 3 条话术） ----------

    private static final ObjectMapper JSON = new ObjectMapper();

    /** 共同兴趣、同城、年龄相近、都已认证，取最多 3 条 */
    public static List<String> commonTags(User a, User b) {
        Set<String> tags = new LinkedHashSet<>();
        List<String> mine = parseTags(a.getTags());
        List<String> theirs = parseTags(b.getTags());
        for (String t : mine) {
            if (theirs.contains(t)) {
                tags.add("都喜欢" + t);
                if (tags.size() >= 3) {
                    return List.copyOf(tags);
                }
            }
        }
        if (a.getCity() != null && a.getCity().equals(b.getCity())) {
            tags.add("同在" + a.getCity());
        }
        if (a.getBirthday() != null && b.getBirthday() != null) {
            int diff = Math.abs(Period.between(a.getBirthday(), LocalDate.now()).getYears()
                    - Period.between(b.getBirthday(), LocalDate.now()).getYears());
            if (diff <= 3) {
                tags.add("年龄相仿");
            }
        }
        if (Integer.valueOf(1).equals(a.getVerified()) && Integer.valueOf(1).equals(b.getVerified())) {
            tags.add("都完成了真人认证");
        }
        return tags.stream().limit(3).toList();
    }

    /** 基于共同点选模板生成 3 条破冰话术 */
    static List<String> icebreakers(User other, List<String> commonTags) {
        List<String> lines = new ArrayList<>();
        for (String tag : commonTags) {
            if (tag.startsWith("都喜欢") && lines.size() < 3) {
                lines.add("你们都「" + tag.substring(3) + "」，最近一次入坑是什么时候？");
            }
            if (tag.startsWith("同在") && lines.size() < 3) {
                lines.add("都在" + tag.substring(2) + "，你最喜欢哪条散步路线？");
            }
            if ("年龄相仿".equals(tag) && lines.size() < 3) {
                lines.add("同龄人路过！最近有什么值得二刷的剧或歌吗？");
            }
        }
        if (other.getOccupation() != null && !other.getOccupation().isBlank() && lines.size() < 3) {
            lines.add("好奇问一下，" + other.getOccupation() + "的日常是什么样的？");
        }
        if (lines.size() < 3) {
            lines.add("最近有什么值得安利的电影或歌吗？");
        }
        if (lines.size() < 3) {
            lines.add("周末一般喜欢宅着还是出去玩？");
        }
        return lines.stream().limit(3).toList();
    }

    public static List<String> parseTags(String raw) {
        if (raw == null || raw.isBlank()) {
            return List.of();
        }
        try {
            return JSON.readValue(raw, new com.fasterxml.jackson.core.type.TypeReference<List<String>>() {});
        } catch (Exception e) {
            return List.of();
        }
    }

    static String toJson(List<String> tags) {
        try {
            return JSON.writeValueAsString(tags);
        } catch (Exception e) {
            return "[]";
        }
    }
}
