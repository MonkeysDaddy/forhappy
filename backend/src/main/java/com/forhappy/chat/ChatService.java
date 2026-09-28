package com.forhappy.chat;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.forhappy.common.BizException;
import com.forhappy.entity.Message;
import com.forhappy.entity.User;
import com.forhappy.mapper.ConversationMapper;
import com.forhappy.mapper.MessageMapper;
import com.forhappy.mapper.UserMapper;
import com.forhappy.ws.WsPushService;
import java.util.HashMap;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** 消息收发（HTTP 与 WS 共用）：落库 → 更新会话 → 推送给对方 */
@Service
@RequiredArgsConstructor
public class ChatService {

    private final ConversationMapper conversationMapper;
    private final MessageMapper messageMapper;
    private final UserMapper userMapper;
    private final WsPushService wsPush;
    private final com.forhappy.common.SensitiveWordStore sensitiveWordStore;
    private final com.forhappy.mapper.AdminManageMapper violationMapper;

    private static final ObjectMapper JSON = new ObjectMapper();

    /**
     * noRollbackFor：敏感词命中时违规流水必须落库（供后台处置），
     * 不能随拦截抛出的 BizException 一起回滚；此前未写入的数据不受影响。
     */
    @Transactional(noRollbackFor = BizException.class)
    public Message send(long convId, long uid, Integer typeIn, String contentIn) {
        // 动态敏感词拦截（HTTP 与 WS 统一在此检查，避免两条路径风控不一致）
        String hit = sensitiveWordStore.hit(contentIn);
        if (hit != null) {
            violationMapper.insertViolation(uid, "chat",
                    contentIn != null && contentIn.length() > 500
                            ? contentIn.substring(0, 500) : contentIn, hit);
            throw new BizException(400, "消息包含违规内容，已被拦截");
        }
        if (conversationMapper.findMine(convId, uid) == null) {
            throw new BizException(403, "无权访问该会话");
        }
        // 分级处置：禁言期内禁止发言
        User sender = userMapper.findById(uid);
        if (sender != null && sender.getMuteUntil() != null
                && sender.getMuteUntil().isAfter(java.time.LocalDateTime.now())) {
            throw new BizException(403, "你已被禁言至 "
                    + sender.getMuteUntil().toLocalDate() + "，期间无法发送消息");
        }
        String content = contentIn == null ? "" : contentIn.trim();
        if (content.isEmpty()) {
            throw new BizException(400, "消息不能为空");
        }
        // 1文本 2图片 3语音（媒体 content=本站 /files/ 上传结果，防外链）
        int type = typeIn != null ? typeIn : 1;
        if (type == 2 || type == 3) {
            String path = content.contains("/files/")
                    ? content.substring(content.indexOf("/files/")) : content;
            if (!path.startsWith("/files/")) {
                throw new BizException(400, type == 2 ? "图片消息仅支持本站上传的图片" : "语音消息仅支持本站上传的录音");
            }
            content = path;
        } else {
            type = 1;
            if (content.length() > 500) {
                throw new BizException(400, "消息不能超过 500 字");
            }
        }
        Message m = new Message();
        m.setConvId(convId);
        m.setFromUser(uid);
        m.setType(type);
        m.setContent(content);
        messageMapper.insert(m);
        conversationMapper.appendMessage(convId, uid,
                type == 2 ? "[图片]" : type == 3 ? "[语音]" : content);

        // 实时推送给对方（离线静默，下次进聊天页走 HTTP 拉取）
        Long peerId = conversationMapper.findPeer(convId, uid);
        if (peerId != null) {
            try {
                Map<String, Object> frame = new HashMap<>();
                frame.put("type", "message");
                frame.put("convId", convId);
                frame.put("message", m);
                frame.put("fromNickname",
                        userMapper.findById(uid).getNickname());
                wsPush.pushToUser(peerId, JSON.writeValueAsString(frame));
            } catch (Exception ignored) {
            }
        }
        return m;
    }
}
