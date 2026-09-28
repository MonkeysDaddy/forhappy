package com.forhappy.admin;

import com.forhappy.common.Result;
import com.forhappy.mapper.AdminManageMapper;
import java.util.HashMap;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RestController;

/** 订阅订单 / 对账 */
@RestController
@RequestMapping("/api/v1/admin/orders")
@RequiredArgsConstructor
public class AdminOrderController {

    private final AdminManageMapper adminManageMapper;
    private final com.forhappy.mapper.NotificationMapper notificationMapper;
    private final com.forhappy.mapper.MemberOrderMapper orderMapper;
    private final AdminApiSupport support;

    @GetMapping
    public Result<Map<String, Object>> list(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestParam(defaultValue = "0") int offset,
            @RequestParam(defaultValue = "20") int limit,
            @RequestParam(required = false) Long userId,
            @RequestParam(required = false) Integer status) {
        support.require(key, authHeader, "commerce");
        limit = Math.clamp(limit, 1, 100);
        Map<String, Object> data = new HashMap<>();
        data.put("items", adminManageMapper.orders(offset, limit, userId, status));
        data.put("total", adminManageMapper.countOrders(userId, status));
        return Result.ok(data);
    }

    /** 退款：仅已支付订单可退，退款后通知用户 */
    @PutMapping("/{orderNo}/refund")
    public Result<Void> refund(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @PathVariable String orderNo) {
        support.require(key, authHeader, "commerce");
        var order = orderMapper.findByNo(orderNo);
        if (order == null) {
            throw new com.forhappy.common.BizException(404, "订单不存在");
        }
        if (orderMapper.markRefund(orderNo) == 0) {
            throw new com.forhappy.common.BizException(400, "仅已支付订单可退款");
        }
        long uid = ((Number) order.get("user_id")).longValue();
        notificationMapper.insert(uid, "system", "退款通知",
                "订单 " + orderNo + " 已退款，金额将原路退回");
        support.log("order.refund", "订单 " + orderNo + " 已退款");
        return Result.ok();
    }

    /** 对账汇总：按状态汇总 + 近 7 天收入序列 */
    @GetMapping("/summary")
    public Result<Map<String, Object>> summary(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader) {
        support.require(key, authHeader, "commerce");
        Map<String, Object> data = new HashMap<>();
        data.put("byStatus", adminManageMapper.ordersByStatus());
        data.put("last7Days", adminManageMapper.revenueByDay());
        return Result.ok(data);
    }
}
