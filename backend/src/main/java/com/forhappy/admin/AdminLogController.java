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

/** 行为日志（用户埋点）与后台操作日志 */
@RestController
@RequestMapping("/api/v1/admin/logs")
@RequiredArgsConstructor
public class AdminLogController {

    private final AdminManageMapper adminManageMapper;
    private final AdminApiSupport support;

    @GetMapping("/events")
    public Result<Map<String, Object>> events(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestParam(defaultValue = "0") int offset,
            @RequestParam(defaultValue = "20") int limit,
            @RequestParam(required = false) Long userId,
            @RequestParam(required = false) String event) {
        support.require(key, authHeader, "logs");
        limit = Math.clamp(limit, 1, 100);
        Map<String, Object> data = new HashMap<>();
        data.put("items", adminManageMapper.events(offset, limit, userId, event));
        data.put("total", adminManageMapper.countEvents(userId, event));
        data.put("distinctEvents", adminManageMapper.distinctEvents());
        return Result.ok(data);
    }

    @GetMapping("/admin")
    public Result<Map<String, Object>> adminLogs(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestParam(defaultValue = "0") int offset,
            @RequestParam(defaultValue = "20") int limit,
            @RequestParam(required = false) String action) {
        support.require(key, authHeader, "logs");
        limit = Math.clamp(limit, 1, 100);
        Map<String, Object> data = new HashMap<>();
        data.put("items", adminManageMapper.adminLogs(offset, limit, action));
        data.put("total", adminManageMapper.countAdminLogs(action));
        return Result.ok(data);
    }
}
