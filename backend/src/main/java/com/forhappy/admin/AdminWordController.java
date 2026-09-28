package com.forhappy.admin;

import com.forhappy.common.BizException;
import com.forhappy.common.Result;
import com.forhappy.common.SensitiveWordStore;
import com.forhappy.mapper.AdminManageMapper;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** 敏感词管理：词命中即时生效（聊天/动态发布拦截并记违规） */
@RestController
@RequestMapping("/api/v1/admin/words")
@RequiredArgsConstructor
public class AdminWordController {

    private final AdminManageMapper adminManageMapper;
    private final SensitiveWordStore sensitiveWordStore;
    private final AdminApiSupport support;

    @GetMapping
    public Result<List<Map<String, Object>>> list(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader) {
        support.require(key, authHeader, "content");
        return Result.ok(adminManageMapper.listWords());
    }

    @PostMapping
    public Result<Void> add(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestBody Map<String, Object> body) {
        support.require(key, authHeader, "content");
        String word = body.getOrDefault("word", "").toString().trim();
        if (word.isEmpty() || word.length() > 64) {
            throw new BizException(400, "敏感词 1-64 个字符");
        }
        try {
            adminManageMapper.insertWord(word);
        } catch (Exception e) {
            throw new BizException(409, "敏感词已存在");
        }
        sensitiveWordStore.refresh();
        support.log("word.add", "新增敏感词：" + word);
        return Result.ok();
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @PathVariable long id) {
        support.require(key, authHeader, "content");
        adminManageMapper.deleteWord(id);
        sensitiveWordStore.refresh();
        support.log("word.delete", "删除敏感词 #" + id);
        return Result.ok();
    }
}
