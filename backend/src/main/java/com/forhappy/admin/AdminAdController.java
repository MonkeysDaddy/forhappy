package com.forhappy.admin;

import com.forhappy.common.Result;
import com.forhappy.mapper.AdminManageMapper;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RestController;

/** 广告投放管理 */
@RestController
@RequestMapping("/api/v1/admin/ads")
@RequiredArgsConstructor
public class AdminAdController {

    private final AdminManageMapper adminManageMapper;
    private final AdminApiSupport support;

    @GetMapping
    public Result<?> list(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader) {
        support.require(key, authHeader, "ops");
        return Result.ok(adminManageMapper.adsAll());
    }

    @PostMapping
    public Result<Void> create(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestBody Map<String, Object> body) {
        support.require(key, authHeader, "ops");
        String title = body.getOrDefault("title", "").toString().trim();
        if (title.isEmpty()) {
            throw new com.forhappy.common.BizException(400, "广告标题不能为空");
        }
        adminManageMapper.insertAd(title,
                body.getOrDefault("content", "").toString(),
                body.get("imageUrl") == null ? null : body.get("imageUrl").toString(),
                body.get("linkUrl") == null ? null : body.get("linkUrl").toString(),
                body.getOrDefault("position", "feed").toString());
        support.log("ad.create", "投放广告：" + title);
        return Result.ok();
    }

    @PutMapping("/{id}/active")
    public Result<Void> setActive(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @PathVariable long id,
            @RequestBody Map<String, Object> body) {
        support.require(key, authHeader, "ops");
        int active = body.containsKey("active")
                && Boolean.TRUE.equals(body.get("active")) ? 1 : 0;
        adminManageMapper.setAdActive(id, active);
        support.log("ad." + (active == 1 ? "on" : "off"), "广告 #" + id);
        return Result.ok();
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @PathVariable long id) {
        support.require(key, authHeader, "ops");
        adminManageMapper.deleteAd(id);
        support.log("ad.delete", "广告 #" + id);
        return Result.ok();
    }
}
