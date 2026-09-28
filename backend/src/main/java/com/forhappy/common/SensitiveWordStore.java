package com.forhappy.common;

import com.forhappy.mapper.AdminManageMapper;
import jakarta.annotation.PostConstruct;
import java.util.ArrayList;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/** 动态敏感词（管理后台可增删，内存缓存即时刷新） */
@Component
@RequiredArgsConstructor
public class SensitiveWordStore {

    private final AdminManageMapper adminManageMapper;

    private volatile List<String> words = List.of();

    @PostConstruct
    public void refresh() {
        try {
            words = List.copyOf(adminManageMapper.allWords());
        } catch (Exception ignored) {
            // 表尚未建好等场景：保持空表
        }
    }

    /** 返回命中的敏感词，未命中返回 null */
    public String hit(String text) {
        if (text == null || text.isBlank() || words.isEmpty()) {
            return null;
        }
        for (String w : words) {
            if (!w.isBlank() && text.contains(w)) {
                return w;
            }
        }
        return null;
    }
}
