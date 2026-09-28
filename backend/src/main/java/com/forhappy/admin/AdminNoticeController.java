package com.forhappy.admin;

import com.forhappy.common.Result;
import com.forhappy.mapper.AdminManageMapper;
import com.forhappy.mapper.NotificationMapper;
import java.util.HashMap;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** 系统公告群发：向全部正常状态用户 fan-out 通知 */
@RestController
@RequestMapping("/api/v1/admin/notices")
@RequiredArgsConstructor
public class AdminNoticeController {

    private final NotificationMapper notificationMapper;
    private final AdminManageMapper adminManageMapper;
    private final AdminApiSupport support;

    @PostMapping
    public Result<Map<String, Object>> send(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestBody Map<String, Object> body) {
        support.require(key, authHeader, "ops");
        String title = body.getOrDefault("title", "").toString().trim();
        String content = body.getOrDefault("content", "").toString().trim();
        if (title.isEmpty() || content.isEmpty()) {
            throw new com.forhappy.common.BizException(400, "标题与内容不能为空");
        }
        // 定向：all 全部 / vip / svip / member(全部会员) / user(指定 userId)
        String target = body.getOrDefault("target", "all").toString();
        java.util.List<Long> userIds;
        if ("user".equals(target) && body.get("userId") instanceof Number n) {
            userIds = java.util.List.of(n.longValue());
        } else {
            userIds = switch (target) {
                case "vip" -> adminManageMapper.activeUserIdsByTier(1);
                case "svip" -> adminManageMapper.activeUserIdsByTier(2);
                case "member" -> adminManageMapper.activeUserIdsByTier(9);
                default -> adminManageMapper.activeUserIds();
            };
        }
        for (var uid : userIds) {
            notificationMapper.insert(uid, "system", title, content);
        }
        support.log("notice.send", "群发公告「" + title + "」给 " + userIds.size() + " 位用户");
        Map<String, Object> data = new HashMap<>();
        data.put("sent", userIds.size());
        return Result.ok(data);
    }
}
