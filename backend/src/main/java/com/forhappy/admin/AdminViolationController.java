package com.forhappy.admin;

import com.forhappy.common.Result;
import com.forhappy.mapper.AdminManageMapper;
import java.util.HashMap;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** 违规记录：聊天/动态命中敏感词的拦截流水 */
@RestController
@RequestMapping("/api/v1/admin/violations")
@RequiredArgsConstructor
public class AdminViolationController {

    private final AdminManageMapper adminManageMapper;
    private final AdminApiSupport support;

    @GetMapping
    public Result<Map<String, Object>> list(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestParam(defaultValue = "0") int offset,
            @RequestParam(defaultValue = "20") int limit,
            @RequestParam(required = false) Long userId,
            @RequestParam(required = false) String type) {
        support.require(key, authHeader, "content");
        limit = Math.clamp(limit, 1, 100);
        Map<String, Object> data = new HashMap<>();
        data.put("items", adminManageMapper.violations(offset, limit, userId, type));
        data.put("total", adminManageMapper.countViolations(userId, type));
        return Result.ok(data);
    }
}
