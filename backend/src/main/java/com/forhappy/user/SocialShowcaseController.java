package com.forhappy.user;

import com.forhappy.common.BizException;
import com.forhappy.common.Result;
import com.forhappy.common.UserContext;
import com.forhappy.entity.User;
import com.forhappy.mapper.AdminManageMapper;
import com.forhappy.mapper.UserMapper;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** 社交账号展示（社交展示卡·按月订阅）：
 * GET /social-showcase  我的展示配置 + 订阅状态
 * PUT /social-showcase  保存展示配置（需有效订阅，到期立即不再对外展示）
 */
@RestController
@RequestMapping("/api/v1/social-showcase")
@RequiredArgsConstructor
public class SocialShowcaseController {

    private final UserMapper userMapper;
    private final AdminManageMapper adminManageMapper;

    private static final com.fasterxml.jackson.databind.ObjectMapper JSON =
            new com.fasterxml.jackson.databind.ObjectMapper();

    /** 解析 JSON 数组字符串 [{platform,account}]；异常/为空返回空列表 */
    static List<Map<String, String>> parseShowcase(String json) {
        if (json == null || json.isBlank()) {
            return List.of();
        }
        try {
            List<Map<String, String>> out = new ArrayList<>();
            for (Object o : JSON.readValue(json, List.class)) {
                if (o instanceof Map<?, ?> m) {
                    Map<String, String> it = new HashMap<>();
                    it.put("platform",
                            m.get("platform") == null ? "" : m.get("platform").toString());
                    it.put("account",
                            m.get("account") == null ? "" : m.get("account").toString());
                    out.add(it);
                }
            }
            return out;
        } catch (Exception e) {
            return List.of();
        }
    }

    static String toJson(List<?> list) {
        try {
            return JSON.writeValueAsString(list);
        } catch (Exception e) {
            return "[]";
        }
    }

    boolean active(User u) {
        return u.getSocialExpireAt() != null
                && u.getSocialExpireAt().isAfter(LocalDateTime.now());
    }

    @GetMapping
    public Result<Map<String, Object>> mine() {
        User u = userMapper.findById(UserContext.get());
        Map<String, Object> data = new HashMap<>();
        data.put("active", active(u));
        data.put("expireAt", u.getSocialExpireAt());
        data.put("items", active(u) ? parseShowcase(u.getSocialShowcase()) : List.of());
        return Result.ok(data);
    }

    @PutMapping
    public Result<Map<String, Object>> save(@RequestBody Map<String, Object> body) {
        long uid = UserContext.get();
        User u = userMapper.findById(uid);
        if (!active(u)) {
            throw new BizException(4003,
                    "对外展示社交账号需要「社交展示卡」月度订阅");
        }
        List<?> rawItems = body.get("items") instanceof List<?> list
                ? list : List.of();
        List<Map<String, String>> items = parseShowcase(toJson(rawItems));
        if (items.size() > 6) {
            throw new BizException(400, "最多展示 6 个社交账号");
        }
        for (Map<String, String> it : items) {
            if (it.get("platform").isBlank() || it.get("account").isBlank()) {
                throw new BizException(400, "平台与账号不能为空");
            }
        }
        userMapper.updateSocialShowcase(uid, toJson(items));
        adminManageMapper.insertAdminLog("system", "social.update",
                "用户 #" + uid + " 更新社交展示");
        Map<String, Object> data = new HashMap<>();
        data.put("items", items);
        return Result.ok(data);
    }
}
