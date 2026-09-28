package com.forhappy.admin;

import com.forhappy.common.BizException;
import com.forhappy.mapper.EventMapper;
import com.forhappy.common.Result;
import com.forhappy.entity.MemberProduct;
import com.forhappy.mapper.MemberOrderMapper;
import com.forhappy.mapper.MemberProductMapper;
import com.forhappy.mapper.UserMapper;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 运营后台最小集（设计 7.3 admin 模块）：商品改价/上下架 + 运营统计。
 * 鉴权走 X-Admin-Key（演示环境免登录态，走独立密钥；生产环境替换为独立部署 + RBAC + 审计日志）。
 */
@RestController
@RequestMapping("/api/v1/admin")
@RequiredArgsConstructor
public class AdminController {

    private final MemberProductMapper productMapper;
    private final MemberOrderMapper orderMapper;
    private final UserMapper userMapper;
    private final EventMapper eventMapper;
    private final AdminApiSupport support;

    @Value("${forhappy.admin.key:forhappy-admin}")
    private String adminKey;

    private void auth(String key, String authHeader) {
        support.require(key, authHeader, "commerce");
    }

    private void auth(String key, String authHeader, String permission) {
        support.require(key, authHeader, permission);
    }

    /** 全量商品（含下架），供后台改价/上下架 */
    @GetMapping("/products")
    public Result<List<MemberProduct>> products(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader) {
        auth(key, authHeader, "commerce");
        return Result.ok(productMapper.listAll());
    }

    /** 改价/上下架/调排序：只传需要改的字段（改价即时生效于新订单，设计 4.9） */
    @PutMapping("/products/{id}")
    public Result<Void> updateProduct(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @PathVariable long id,
            @RequestBody Map<String, Object> body) {
        auth(key, authHeader, "commerce");
        int updated = productMapper.adminUpdate(id,
                body.containsKey("priceCents")
                        ? ((Number) body.get("priceCents")).intValue() : null,
                body.containsKey("originalCents")
                        ? ((Number) body.get("originalCents")).intValue() : null,
                body.containsKey("firstPriceCents")
                        ? ((Number) body.get("firstPriceCents")).intValue() : null,
                body.containsKey("status")
                        ? ((Number) body.get("status")).intValue() : null,
                body.containsKey("sortOrder")
                        ? ((Number) body.get("sortOrder")).intValue() : null);
        if (updated == 0) {
            throw new BizException(404, "商品不存在");
        }
        return Result.ok();
    }

    /** 新建订阅方案 */
    @PostMapping("/products")
    public Result<Void> createProduct(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestBody Map<String, Object> body) {
        auth(key, authHeader);
        int tier = body.containsKey("tier") ? ((Number) body.get("tier")).intValue() : 1;
        int durationDays = body.containsKey("durationDays")
                ? ((Number) body.get("durationDays")).intValue() : 30;
        int priceCents = body.containsKey("priceCents")
                ? ((Number) body.get("priceCents")).intValue() : 0;
        if ((tier != 1 && tier != 2 && tier != 3)
                || durationDays <= 0 || priceCents < 0) {
            throw new BizException(400, "商品参数无效");
        }
        String durationLabel = durationDays >= 365
                ? (durationDays / 365) + " 年" : durationDays + " 天";
        productMapper.adminCreate(tier, durationDays, durationLabel, priceCents,
                body.containsKey("originalCents")
                        ? ((Number) body.get("originalCents")).intValue() : null,
                body.containsKey("firstPriceCents")
                        ? ((Number) body.get("firstPriceCents")).intValue() : null,
                body.get("badge") == null ? null : body.get("badge").toString(),
                body.containsKey("sortOrder")
                        ? ((Number) body.get("sortOrder")).intValue() : 0);
        support.log("product.create", "新建方案 " + (tier == 3 ? "社交展示卡" : tier == 2 ? "SVIP" : "VIP")
                + " " + durationLabel + " ¥" + priceCents / 100.0);
        return Result.ok();
    }

    /** 删除订阅方案：已有订单的历史引用，需先确认无订单 */
    @org.springframework.web.bind.annotation.DeleteMapping("/products/{id}")
    public Result<Void> deleteProduct(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @PathVariable long id) {
        auth(key, authHeader, "commerce");
        if (productMapper.countOrdersOfProduct2(id) > 0) {
            throw new BizException(400, "该方案已有订单，请使用下架而不是删除");
        }
        productMapper.adminDelete(id);
        support.log("product.delete", "删除方案 #" + id);
        return Result.ok();
    }

    /** 运营统计看板：用户/配对/今日互动/订单收入/举报/今日埋点 */
    @GetMapping("/stats")
    public Result<Map<String, Object>> stats(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader) {
        auth(key, authHeader);
        Map<String, Object> data = new HashMap<>();
        data.put("users", userMapper.countAll());
        data.put("activeToday", userMapper.countActiveToday());
        data.put("newUsersToday", userMapper.countNewUsersToday());
        data.put("matches", userMapper.countMatches());
        data.put("likesToday", userMapper.countLikesTodayAll());
        data.put("reports", userMapper.countReports());
        Map<String, Object> revenue = orderMapper.sumRevenue();
        data.put("paidOrders", revenue.get("cnt"));
        data.put("revenueCents", revenue.get("amount"));
        data.put("eventsToday", eventMapper.countToday());
        return Result.ok(data);
    }
}
