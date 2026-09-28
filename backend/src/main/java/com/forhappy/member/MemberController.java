package com.forhappy.member;

import com.forhappy.common.BizException;
import com.forhappy.common.Result;
import com.forhappy.common.UserContext;
import com.forhappy.entity.MemberProduct;
import com.forhappy.entity.User;
import com.forhappy.mapper.LikeMapper;
import com.forhappy.mapper.MemberOrderMapper;
import com.forhappy.mapper.MemberProductMapper;
import com.forhappy.mapper.UserMapper;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/member")
@RequiredArgsConstructor
public class MemberController {

    private final MemberProductMapper productMapper;
    private final MemberOrderMapper orderMapper;
    private final UserMapper userMapper;
    private final LikeMapper likeMapper;

    @org.springframework.beans.factory.annotation.Value("${forhappy.like.daily-quota:30}")
    private int dailyLikeQuota;

    @GetMapping("/products")
    public Result<List<MemberProduct>> products() {
        return Result.ok(productMapper.listOnShelf());
    }

    @GetMapping("/status")
    public Result<Map<String, Object>> status() {
        User u = userMapper.findById(UserContext.get());
        boolean member = u.getMemberTier() != null && u.getMemberTier() > 0;
        Map<String, Object> data = new HashMap<>();
        data.put("tier", u.getMemberTier());
        data.put("expireAt", u.getMemberExpireAt());
        // 今日剩余喜欢次数（设计 9.6；会员返回 -1 表示无限）
        data.put("likesUsedToday", likeMapper.countLikesToday(u.getId()));
        data.put("likesRemaining", member ? -1
                : Math.max(dailyLikeQuota - likeMapper.countLikesToday(u.getId()), 0));
        return Result.ok(data);
    }

    @PostMapping("/orders")
    public Result<Map<String, Object>> createOrder(@RequestBody Map<String, Object> body) {
        long uid = UserContext.get();
        long productId = ((Number) body.get("productId")).longValue();
        int channel = body.containsKey("channel")
                ? ((Number) body.get("channel")).intValue() : 1;
        MemberProduct p = productMapper.findById(productId);
        if (p == null) {
            throw new BizException(404, "商品不存在");
        }
        User u = userMapper.findById(uid);
        boolean firstPurchase = u.getMemberTier() == null || u.getMemberTier() == 0;
        int amount = (firstPurchase && p.getFirstPriceCents() != null)
                ? p.getFirstPriceCents() : p.getPriceCents();
        String orderNo = UUID.randomUUID().toString().replace("-", "").substring(0, 20);
        orderMapper.insert(orderNo, uid, productId, amount, channel);
        Map<String, Object> data = new HashMap<>();
        data.put("orderNo", orderNo);
        data.put("amountCents", amount);
        return Result.ok(data);
    }

    /** 演示支付：直接标记成功并开通权益 */
    @PostMapping("/orders/{orderNo}/pay")
    @Transactional
    public Result<Map<String, Object>> pay(@PathVariable String orderNo) {
        long uid = UserContext.get();
        Map<String, Object> order = orderMapper.findByNo(orderNo);
        if (order == null
                || uid != ((Number) order.get("user_id")).longValue()) {
            throw new BizException(404, "订单不存在");
        }
        if (orderMapper.markPaid(orderNo) == 0) {
            throw new BizException(400, "订单状态不正确");
        }
        MemberProduct p = productMapper.findById(
                ((Number) order.get("product_id")).longValue());
        User u = userMapper.findById(uid);
        LocalDateTime now = LocalDateTime.now();
        // 社交展示卡（tier=3，按月订阅）：只延长社交展示期，不改会员档位
        if (p.getTier() != null && p.getTier() == 3) {
            LocalDateTime socBase = (u.getSocialExpireAt() != null
                    && u.getSocialExpireAt().isAfter(now))
                    ? u.getSocialExpireAt() : now;
            LocalDateTime socExpire = socBase.plusDays(p.getDurationDays());
            userMapper.extendSocialShowcase(uid, socExpire);
            Map<String, Object> soc = new HashMap<>();
            soc.put("tier", 3);
            soc.put("expireAt", socExpire.toString());
            return Result.ok(soc);
        }
        LocalDateTime base = (u.getMemberTier() != null
                && u.getMemberTier().equals(p.getTier())
                && u.getMemberExpireAt() != null
                && u.getMemberExpireAt().isAfter(now))
                ? u.getMemberExpireAt() : now;
        LocalDateTime expire = base.plusDays(p.getDurationDays());
        userMapper.updateMembership(uid, p.getTier(), expire);
        Map<String, Object> data = new HashMap<>();
        data.put("tier", p.getTier());
        data.put("expireAt", expire.toString());
        return Result.ok(data);
    }
}
