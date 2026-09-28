package com.forhappy.admin;

import com.forhappy.common.Result;
import com.forhappy.mapper.AdminManageMapper;
import com.forhappy.mapper.UserMapper;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** 举报处理闭环：核实通过 → 可禁用被举报人；不实 → 驳回 */
@RestController
@RequestMapping("/api/v1/admin/reports")
@RequiredArgsConstructor
public class AdminReportController {

    private final AdminManageMapper adminManageMapper;
    private final UserMapper userMapper;
    private final com.forhappy.mapper.ConversationMapper conversationMapper;
    private final com.forhappy.mapper.MessageMapper messageMapper;
    private final AdminApiSupport support;

    @GetMapping
    public Result<?> list(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestParam(defaultValue = "0") int offset,
            @RequestParam(defaultValue = "20") int limit,
            @RequestParam(required = false) Integer status) {
        support.require(key, authHeader, "content");
        Map<String, Object> data = new java.util.HashMap<>();
        data.put("items", adminManageMapper.reports(offset, limit, status));
        data.put("total", adminManageMapper.countReports(status));
        return Result.ok(data);
    }

    /** 举报取证：调取举报人与被举报人的聊天记录（上下文核查用） */
    @GetMapping("/{id}/chat")
    public Result<?> chat(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @PathVariable long id) {
        support.require(key, authHeader, "content");
        var row = adminManageMapper.reports(0, 1000, null).stream()
                .filter(r -> ((Number) r.get("id")).longValue() == id)
                .findFirst().orElse(null);
        if (row == null) {
            throw new com.forhappy.common.BizException(404, "举报不存在");
        }
        long reporter = ((Number) row.get("reporter")).longValue();
        long reported = ((Number) row.get("reported")).longValue();
        var conv = conversationMapper.findBetween(reporter, reported);
        if (conv == null) {
            return Result.ok(java.util.List.of());
        }
        long convId = ((Number) conv.get("id")).longValue();
        var messages = messageMapper.latest(convId, 200);
        return Result.ok(messages);
    }

    /** action=1 驳回 / action=2 核实并禁用被举报人 */
    @PutMapping("/{id}/handle")
    public Result<Void> handle(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @PathVariable long id,
            @RequestBody Map<String, Object> body) {
        support.require(key, authHeader, "content");
        int action = body.containsKey("action")
                ? ((Number) body.get("action")).intValue() : 1;
        if (action == 2) {
            Map<String, Object> report = adminManageMapper.reports(0, 1, null)
                    .stream().filter(r -> ((Number) r.get("id")).longValue() == id)
                    .findFirst().orElse(null);
            Long reported = report == null ? null
                    : (report.get("reported") instanceof Number n
                            ? n.longValue() : null);
            if (reported != null) {
                adminManageMapper.setStatus(reported, 2); // 禁用被举报人
            }
            adminManageMapper.handleReport(id, 2);
            support.log("report.verify", "举报 #" + id + " 核实，被举报人已禁用");
        } else {
            adminManageMapper.handleReport(id, 1);
            support.log("report.dismiss", "举报 #" + id + " 驳回");
        }
        return Result.ok();
    }
}
