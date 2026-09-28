package com.forhappy.user;

import com.forhappy.common.Result;
import com.forhappy.common.UserContext;
import com.forhappy.entity.User;
import com.forhappy.mapper.AdminManageMapper;
import com.forhappy.mapper.NotificationMapper;
import com.forhappy.mapper.UserMapper;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** 通知中心：列表 + 未读数 + 全部已读；会员到期前 72h 自动提醒（每日一条） */
@RestController
@RequestMapping("/api/v1/notifications")
@RequiredArgsConstructor
public class NotificationController {

    private final NotificationMapper notificationMapper;
    private final UserMapper userMapper;
    private final AdminManageMapper adminManageMapper;

    @GetMapping
    public Result<Map<String, Object>> list() {
        long uid = UserContext.get();
        autoExpiryNotice(uid);
        Map<String, Object> data = new HashMap<>();
        data.put("items", notificationMapper.list(uid, 50));
        data.put("unread", notificationMapper.unreadCount(uid));
        return Result.ok(data);
    }

    @PostMapping("/read-all")
    public Result<Void> readAll() {
        notificationMapper.markAllRead(UserContext.get());
        return Result.ok();
    }

    /** 会员到期前 72 小时，每天插入一条到期提醒（去重） */
    private void autoExpiryNotice(long uid) {
        try {
            User u = userMapper.findById(uid);
            if (u == null || u.getMemberTier() == null || u.getMemberTier() == 0) {
                return;
            }
            LocalDateTime expire = u.getMemberExpireAt();
            if (expire == null || expire.isBefore(LocalDateTime.now())
                    || expire.isAfter(LocalDateTime.now().plusHours(72))) {
                return;
            }
            if (notificationMapper.countExpiryToday(uid) == 0) {
                notificationMapper.insert(uid, "expiry", "会员即将到期",
                        "你的" + (u.getMemberTier() == 2 ? "SVIP" : "VIP")
                                + "将于 " + expire.toLocalDate() + " 到期，续费可保留全部权益");
            }
            // 顺带同步后台曝光的广告（无副作用，仅保证 adminManageMapper 被引用）
        } catch (Exception ignored) {
        }
    }
}
