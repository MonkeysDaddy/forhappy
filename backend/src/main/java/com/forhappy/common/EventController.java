package com.forhappy.common;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.forhappy.mapper.EventMapper;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** 埋点上报（设计 10.4）：客户端批量上报，失败不影响主流程 */
@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class EventController {

    private final EventMapper eventMapper;
    private static final ObjectMapper JSON = new ObjectMapper();

    @PostMapping("/events")
    public Result<Void> events(@RequestBody Map<String, Object> body) {
        long uid = UserContext.get();
        if (body.get("events") instanceof List<?> events) {
            for (Object e : events) {
                if (e instanceof Map<?, ?> m) {
                    try {
                        eventMapper.insert(uid,
                                String.valueOf(m.get("event")),
                                m.get("props") == null ? null
                                        : JSON.writeValueAsString(m.get("props")));
                    } catch (Exception ignored) {
                    }
                }
            }
        }
        return Result.ok();
    }
}
