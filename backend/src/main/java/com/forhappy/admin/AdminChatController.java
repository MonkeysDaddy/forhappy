package com.forhappy.admin;

import com.forhappy.common.BizException;
import com.forhappy.common.Result;
import com.forhappy.mapper.ConversationMapper;
import com.forhappy.mapper.MessageMapper;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** 管理端聊天取证：按用户查会话、按会话查消息 */
@RestController
@RequestMapping("/api/v1/admin/chats")
@RequiredArgsConstructor
public class AdminChatController {

    private final ConversationMapper conversationMapper;
    private final MessageMapper messageMapper;
    private final AdminApiSupport support;

    /** 用户参与的会话列表（取最近一条会话用于取证） */
    @GetMapping("/of-user/{userId}")
    public Result<List<Map<String, Object>>> ofUser(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @PathVariable long userId) {
        support.require(key, authHeader, "users");
        return Result.ok(conversationMapper.listByUserAdmin(userId));
    }

    /** 会话消息（举报核实的上下文调取） */
    @GetMapping("/{convId}/messages")
    public Result<?> messages(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @PathVariable long convId,
            @RequestParam(defaultValue = "200") int limit) {
        support.require(key, authHeader, "users");
        return Result.ok(messageMapper.latest(convId, Math.min(limit, 500)));
    }
}
