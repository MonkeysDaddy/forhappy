package com.forhappy.chat;

import com.forhappy.common.BizException;
import com.forhappy.common.Result;
import com.forhappy.common.UserContext;
import com.forhappy.entity.ConversationVO;
import com.forhappy.entity.Message;
import com.forhappy.mapper.ConversationMapper;
import com.forhappy.mapper.MessageMapper;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/conversations")
@RequiredArgsConstructor
public class ChatController {

    private final ConversationMapper conversationMapper;
    private final MessageMapper messageMapper;
    private final LlmService llmService;
    private final ChatService chatService;

    @GetMapping
    public Result<List<ConversationVO>> list() {
        return Result.ok(conversationMapper.listForUser(UserContext.get()));
    }

    /** 已读回执：进入/查看会话时把对方消息标记已读（权益 4.8，VIP/SVIP） */
    @PostMapping("/{id}/read")
    public Result<Void> markRead(@PathVariable long id) {
        long uid = UserContext.get();
        if (conversationMapper.findMine(id, uid) == null) {
            throw new com.forhappy.common.BizException(403, "无权访问该会话");
        }
        messageMapper.markRead(id, uid);
        return Result.ok();
    }

    @GetMapping("/{id}/messages")
    public Result<List<Message>> messages(@PathVariable long id) {
        long uid = UserContext.get();
        if (conversationMapper.findMine(id, uid) == null) {
            throw new BizException(403, "无权访问该会话");
        }
        List<Message> list = messageMapper.latest(id, 100);
        Collections.reverse(list);
        conversationMapper.clearUnread(id, uid);
        return Result.ok(list);
    }

    @PostMapping("/{id}/messages")
    public Result<Message> send(@PathVariable long id,
                                @RequestBody Map<String, Object> body) {
        long uid = UserContext.get();
        Integer type = body.containsKey("type")
                ? ((Number) body.get("type")).intValue() : null;
        String content = body.get("content") == null
                ? "" : String.valueOf(body.get("content"));
        // 敏感词拦截在 ChatService.send 内统一执行（与 WS 路径共用）
        return Result.ok(chatService.send(id, uid, type, content));
    }

    /** AI 回复建议：不知道怎么回时，基于双方资料 + 最近聊天记录生成 3 条候选（无 Key 时模板降级） */
    @PostMapping("/{id}/ai-reply")
    public Result<Map<String, Object>> aiReply(@PathVariable long id) {
        return Result.ok(llmService.aiReply(id, UserContext.get()));
    }
}
