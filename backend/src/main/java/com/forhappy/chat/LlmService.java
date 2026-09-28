package com.forhappy.chat;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.forhappy.common.BizException;
import com.forhappy.common.Result;
import com.forhappy.entity.Message;
import com.forhappy.entity.User;
import com.forhappy.mapper.ConversationMapper;
import com.forhappy.mapper.MessageMapper;
import com.forhappy.mapper.UserMapper;
import com.forhappy.social.SocialService;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.net.http.HttpTimeoutException;
import java.time.Duration;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.regex.Pattern;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

/**
 * AI 回复建议（聊天中"不知道怎么回"时的一键求助）：
 * 拼装双方资料 + 最近聊天记录 → 调用 OpenAI 兼容大模型生成 3 条候选回复；
 * 未配置 api-key 或调用失败时降级为本地模板，保证功能永远可用。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class LlmService {

    private final ConversationMapper conversationMapper;
    private final MessageMapper messageMapper;
    private final UserMapper userMapper;

    private static final ObjectMapper JSON = new ObjectMapper();
    private static final DateTimeFormatter DATE_KEY = DateTimeFormatter.ofPattern("yyyyMMdd");

    /** 联系方式/风险内容过滤：命中的候选直接丢弃（安全红线，设计 6.1/6.5） */
    private static final Pattern RISKY = Pattern.compile(
            "\\d{7,}|微信号|加微|加V|vx|VX|扣扣|QQ号|转账|支付宝|刷单|投资理财|杀猪盘|约炮|一夜情");

    @Value("${forhappy.llm.base-url}")
    private String baseUrl;

    @Value("${forhappy.llm.api-key:}")
    private String apiKey;

    @Value("${forhappy.llm.model}")
    private String model;

    @Value("${forhappy.llm.timeout-ms:15000}")
    private int timeoutMs;

    @Value("${forhappy.llm.daily-limit:20}")
    private int dailyLimit;

    /** 单机内存配额计数（演示环境够用；多实例部署换 Redis） */
    private final Map<String, AtomicInteger> dailyCounter = new ConcurrentHashMap<>();

    private final HttpClient http = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(5))
            .build();

    public Map<String, Object> aiReply(long convId, long uid) {
        if (conversationMapper.findMine(convId, uid) == null) {
            throw new BizException(403, "无权访问该会话");
        }
        // 每日配额（按用户+日期计数，code=4002 由客户端提示）
        String key = uid + ":" + LocalDate.now().format(DATE_KEY);
        int used = dailyCounter
                .computeIfAbsent(key, k -> new AtomicInteger())
                .incrementAndGet();
        if (used > dailyLimit) {
            throw new BizException(Result.AI_REPLY_LIMIT, "今日 AI 回复次数已用完，明天再来吧");
        }

        User me = userMapper.findById(uid);
        // 对端用户：会话里另一位
        Long peerId = conversationMapper.findPeer(convId, uid);
        User peer = peerId != null ? userMapper.findById(peerId) : null;
        // 最近消息（含我发过的），供提示词拼装上下文
        List<Message> recent = messageMapper.latest(convId, 10);
        Message lastFromPeer = null;
        for (Message m : recent) {
            if (m.getFromUser() != uid) {
                lastFromPeer = m;
                break;
            }
        }

        List<String> replies = null;
        String source = "fallback";
        if (!apiKey.isBlank()) {
            try {
                replies = callLlm(me, peer, recent, uid);
                source = "llm";
            } catch (Exception e) {
                log.warn("LLM 调用失败，降级模板: {}", e.getMessage());
            }
        }
        if (replies == null || replies.isEmpty()) {
            replies = fallbackReplies(me, peer, lastFromPeer);
            source = "fallback";
        }
        return Map.of("replies", replies, "source", source);
    }

    // ---------- 提示词 ----------

    static String systemPrompt() {
        return """
                你是交友 App「ForHappy」的聊天回复助手。两名用户已互相喜欢并配对成功，\
                其中一方（下称"我"）不知道如何回复对方，需要你帮忙拟稿。

                请严格遵守：
                1. 以"我"的第一人称口吻写给"对方"，每条 1-2 句、不超过 60 字，口语化、真诚自然、不油腻、不卑不亢；
                2. 紧扣对方最近一条消息的话题推进对话，可自然融入双方共同点或对方资料中的兴趣，但不要堆砌信息；
                3. 禁止"在吗""哈哈"等无意义敷衍，禁止查户口式连环提问，禁止过度讨好；
                4. 三条候选风格互补：第一条顺着话题提问；第二条分享自己的相关经历或看法；第三条轻松幽默或适度表达好感；
                5. 内容红线：不得出现手机号/微信号/QQ 等联系方式或引流话术，不得涉及转账、投资、刷单，不得性暗示或攻击任何人，不得替对方说话；
                6. 只输出一个 JSON 字符串数组（恰好 3 个元素），不要任何解释、markdown 代码块或编号。
                """;
    }

    static String userPrompt(User me, User peer, List<Message> recent, long uid,
                             List<String> commonTags) {
        StringBuilder sb = new StringBuilder();
        sb.append("【我的资料】").append(profileLine(me)).append('\n');
        if (peer != null) {
            sb.append("【对方资料】").append(profileLine(peer)).append('\n');
        }
        if (!commonTags.isEmpty()) {
            sb.append("【共同点】").append(String.join("、", commonTags)).append('\n');
        }
        sb.append("【最近聊天记录】");
        if (recent.isEmpty()) {
            sb.append("（还没有任何消息——这是会话开场，请以\"我\"的口吻生成 3 条开场消息）");
        } else {
            sb.append("按时间正序，时间格式 MM-dd HH:mm：\n");
            for (int i = recent.size() - 1; i >= 0; i--) {
                Message m = recent.get(i);
                String who = m.getFromUser() == uid ? "我" : "对方";
                String time = m.getCreatedAt() != null
                        ? m.getCreatedAt().format(DateTimeFormatter.ofPattern("MM-dd HH:mm"))
                        : "";
                sb.append(who).append('(').append(time).append(")：")
                        .append(clip(m.getContent(), 200)).append('\n');
            }
            sb.append("请以\"我\"的口吻，针对对方的最后一条消息生成回复。");
        }
        return sb.toString();
    }

    private static String profileLine(User u) {
        if (u == null) {
            return "未知";
        }
        StringBuilder sb = new StringBuilder();
        sb.append(u.getNickname());
        if (u.getGender() != null) {
            sb.append(u.getGender() == 1 ? "，男" : "，女");
        }
        if (u.getBirthday() != null) {
            int age = java.time.Period.between(u.getBirthday(), LocalDate.now()).getYears();
            sb.append("，").append(age).append("岁");
        }
        if (u.getCity() != null && !u.getCity().isBlank()) {
            sb.append("，").append(u.getCity());
        }
        if (u.getOccupation() != null && !u.getOccupation().isBlank()) {
            sb.append("，职业：").append(u.getOccupation());
        }
        List<String> tags = SocialService.parseTags(u.getTags());
        if (!tags.isEmpty()) {
            sb.append("，兴趣：").append(String.join("/", tags));
        }
        if (u.getBio() != null && !u.getBio().isBlank()) {
            sb.append("，简介：").append(clip(u.getBio(), 60));
        }
        return sb.toString();
    }

    private static String clip(String s, int max) {
        if (s == null) {
            return "";
        }
        return s.length() <= max ? s : s.substring(0, max) + "…";
    }

    // ---------- 大模型调用（OpenAI 兼容 /chat/completions） ----------

    private List<String> callLlm(User me, User peer, List<Message> recent, long uid)
            throws IOException, InterruptedException {
        List<String> commonTags = peer != null ? SocialService.commonTags(me, peer) : List.of();
        ObjectNode body = JSON.createObjectNode();
        body.put("model", model);
        body.put("temperature", 0.8);
        body.put("max_tokens", 512);
        ArrayNode messages = body.putArray("messages");
        messages.addObject().put("role", "system").put("content", systemPrompt());
        messages.addObject().put("role", "user")
                .put("content", userPrompt(me, peer, recent, uid, commonTags));

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(baseUrl + "/chat/completions"))
                .timeout(Duration.ofMillis(timeoutMs))
                .header("Authorization", "Bearer " + apiKey)
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(body.toString()))
                .build();
        HttpResponse<String> resp =
                http.send(request, HttpResponse.BodyHandlers.ofString());
        if (resp.statusCode() != 200) {
            throw new IOException("LLM HTTP " + resp.statusCode() + ": " + clip(resp.body(), 200));
        }
        JsonNode content = JSON.readTree(resp.body())
                .path("choices").path(0).path("message").path("content");
        if (content.isMissingNode() || content.asText().isBlank()) {
            throw new IOException("LLM 返回为空");
        }
        return parseReplies(content.asText());
    }

    /** 容错解析：剥掉 markdown 代码块围栏后按 JSON 数组读；失败则按行拆 */
    static List<String> parseReplies(String content) {
        String text = content.trim();
        if (text.startsWith("```")) {
            text = text.replaceAll("^```[a-zA-Z]*\\s*", "").replaceAll("\\s*```$", "").trim();
        }
        List<String> raw = new ArrayList<>();
        int l = text.indexOf('[');
        int r = text.lastIndexOf(']');
        if (l >= 0 && r > l) {
            try {
                for (JsonNode n : JSON.readTree(text.substring(l, r + 1))) {
                    if (n.isTextual() && !n.asText().isBlank()) {
                        raw.add(n.asText().trim());
                    }
                }
            } catch (Exception ignored) {
                raw.clear();
            }
        }
        if (raw.isEmpty()) {
            for (String line : text.split("\\n+")) {
                String s = line.replaceFirst("^\\s*[\\d一二三四五1-5][.、）)]\\s*", "").trim();
                if (!s.isEmpty() && s.length() <= 120) {
                    raw.add(s);
                }
            }
        }
        // 安全过滤 + 去重 + 最多 3 条
        List<String> safe = raw.stream()
                .filter(s -> !RISKY.matcher(s).find())
                .distinct()
                .limit(3)
                .toList();
        return safe;
    }

    // ---------- 本地模板降级 ----------

    static List<String> fallbackReplies(User me, User peer, Message lastFromPeer) {
        List<String> out = new ArrayList<>();
        String peerName = peer != null && peer.getNickname() != null ? peer.getNickname() : "你";
        List<String> peerTags = peer != null ? SocialService.parseTags(peer.getTags()) : List.of();
        if (lastFromPeer == null || lastFromPeer.getContent() == null || lastFromPeer.getContent().isBlank()) {
            // 开场
            if (!peerTags.isEmpty()) {
                out.add("你好呀！看到你也喜欢" + peerTags.get(0) + "，最近有去玩吗？");
            }
            out.add("嗨，配对成功好巧，周末一般喜欢宅着还是出去玩？");
            out.add("你好～聊聊最近看过的剧或电影？我刚好想找新的下饭剧");
            return out;
        }
        String topic = clip(lastFromPeer.getContent(), 12);
        out.add("你说的「" + topic + "」我挺感兴趣的，再多跟我说说？");
        if (!peerTags.isEmpty()) {
            out.add("看到你喜欢" + peerTags.get(0) + "，我一直想入坑，有新手建议吗？");
        } else if (peer != null && peer.getCity() != null && !peer.getCity().isBlank()) {
            out.add("都在" + peer.getCity() + "，这周天气不错，要不要找家咖啡店聊聊？");
        }
        out.add("和你聊天挺舒服的，周末有安排吗？");
        return out.stream().limit(3).toList();
    }
}
