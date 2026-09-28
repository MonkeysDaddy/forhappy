package com.forhappy.admin;

import com.forhappy.common.BizException;
import com.forhappy.common.Result;
import com.forhappy.entity.User;
import com.forhappy.mapper.AdminManageMapper;
import com.forhappy.mapper.PhotoMapper;
import java.security.MessageDigest;
import java.util.HashMap;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** 用户管理：列表 / 搜索 / 创建 / 禁用启用 / 删除 / 详情（含订阅与消费） */
@RestController
@RequestMapping("/api/v1/admin/users")
@RequiredArgsConstructor
public class AdminUserController {

    private final AdminManageMapper adminManageMapper;
    private final AdminApiSupport support;
    private final com.forhappy.common.PhoneCrypto phoneCrypto;
    private final com.forhappy.mapper.UserMapper userMapper;
    private final PhotoMapper photoMapper;

    @GetMapping
    public Result<Map<String, Object>> list(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestParam(defaultValue = "0") int offset,
            @RequestParam(defaultValue = "20") int limit,
            @RequestParam(required = false) String q,
            @RequestParam(required = false) Integer status,
            @RequestParam(required = false) Integer tier) {
        support.require(key, authHeader, "users");
        limit = Math.clamp(limit, 1, 100);
        // 完整手机号搜索走 hash 精确匹配（密文无法 LIKE）
        String phoneHash = q != null && q.matches("1\\d{10}") ? sha256(q) : null;
        Map<String, Object> data = new HashMap<>();
        data.put("items", adminManageMapper.users(offset, limit, q, phoneHash, status, tier));
        data.put("total", adminManageMapper.countUsers(q, phoneHash, status, tier));
        return Result.ok(data);
    }

    /** 创建用户：手机号注册制（用户侧用验证码登录，演示码 123456） */
    @PostMapping
    public Result<Map<String, Object>> create(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestBody Map<String, Object> body) {
        support.require(key, authHeader, "users");
        String phone = body.getOrDefault("phone", "").toString().trim();
        String nickname = body.getOrDefault("nickname", "").toString().trim();
        int gender = body.containsKey("gender")
                ? ((Number) body.get("gender")).intValue() : 0;
        String city = body.getOrDefault("city", "杭州").toString();
        if (!phone.matches("^1\\d{10}$")) {
            throw new BizException(400, "手机号格式不正确");
        }
        if (nickname.length() < 2 || nickname.length() > 12) {
            throw new BizException(400, "昵称 2-12 个字符");
        }
        if (gender != 1 && gender != 2) {
            throw new BizException(400, "请选择性别");
        }
        String hash = sha256(phone);
        if (adminManageMapper.countPhoneHash(hash) > 0) {
            throw new BizException(409, "该手机号已注册");
        }
        // 手机号 AES-GCM 密文存储
        adminManageMapper.adminInsertUser(hash, phoneCrypto.encrypt(phone),
                nickname, gender, city);
        support.log("user.create", "创建用户 " + nickname + " (" + phone + ")");
        Map<String, Object> data = new HashMap<>();
        data.put("created", true);
        return Result.ok(data);
    }

    /** 启用（1）/ 禁用（2）；禁用后无法登录且从信息流消失 */
    @PutMapping("/{id}/status")
    public Result<Void> setStatus(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @PathVariable long id,
            @RequestBody Map<String, Object> body) {
        support.require(key, authHeader, "users");
        int status = ((Number) body.get("status")).intValue();
        if (status != 1 && status != 2) {
            throw new BizException(400, "无效状态");
        }
        adminManageMapper.setStatus(id, status);
        support.log(status == 1 ? "user.enable" : "user.disable", "用户 #" + id);
        return Result.ok();
    }

    /** 分级处置：禁言 N 天（1-30），并写入用户通知 */
    @PutMapping("/{id}/mute")
    public Result<Void> mute(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @PathVariable long id,
            @RequestBody Map<String, Object> body) {
        support.require(key, authHeader, "users");
        int days = body.containsKey("days") ? ((Number) body.get("days")).intValue() : 3;
        if (days < 1 || days > 30) {
            throw new BizException(400, "禁言时长 1-30 天");
        }
        var until = java.time.LocalDateTime.now().plusDays(days);
        userMapper.setMuteUntil(id, until);
        adminManageMapper.insertNotification(id, "system", "禁言通知",
                "你因违规被禁言 " + days + " 天，至 " + until.toLocalDate());
        support.log("user.mute", "用户 #" + id + " 禁言 " + days + " 天");
        return Result.ok();
    }

    /** 解除禁言 */
    @PutMapping("/{id}/unmute")
    public Result<Void> unmute(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @PathVariable long id) {
        support.require(key, authHeader, "users");
        userMapper.setMuteUntil(id, null);
        support.log("user.unmute", "用户 #" + id + " 解除禁言");
        return Result.ok();
    }

    /** 封禁（status=3）：登录拒绝 + 信息流消失 + 通知 */
    @PutMapping("/{id}/ban")
    public Result<Void> ban(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @PathVariable long id) {
        support.require(key, authHeader, "users");
        adminManageMapper.setStatus(id, 3);
        adminManageMapper.insertNotification(id, "system", "封禁通知",
                "你因严重违规被永久封禁，如有疑问请联系客服");
        support.log("user.ban", "用户 #" + id + " 封禁");
        return Result.ok();
    }

    /** 删除（匿名化软删 status=9）：释放手机号可重新注册，资料脱敏保留 */
    @DeleteMapping("/{id}")
    public Result<Void> delete(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @PathVariable long id) {
        support.require(key, authHeader, "users");
        adminManageMapper.anonymizeDeletedUser(id);
        support.log("user.delete", "删除用户 #" + id + "（匿名化）");
        return Result.ok();
    }

    /** 手动开通/取消会员（客服补偿）：tier=1 VIP / 2 SVIP / 0 取消 */
    @PutMapping("/{id}/membership")
    public Result<Void> setMembership(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @PathVariable long id,
            @RequestBody Map<String, Object> body) {
        support.require(key, authHeader, "users");
        int tier = body.containsKey("tier") ? ((Number) body.get("tier")).intValue() : 0;
        int days = body.containsKey("days") ? ((Number) body.get("days")).intValue() : 30;
        if (tier == 0) {
            userMapper.updateMembership(id, 0, null);
        } else if (tier == 1 || tier == 2) {
            User u = userMapper.findById(id);
            java.time.LocalDateTime now = java.time.LocalDateTime.now();
            java.time.LocalDateTime base = (u.getMemberTier() != null
                    && u.getMemberTier().equals(tier)
                    && u.getMemberExpireAt() != null
                    && u.getMemberExpireAt().isAfter(now)) ? u.getMemberExpireAt() : now;
            userMapper.updateMembership(id, tier, base.plusDays(days));
            adminManageMapper.insertNotification(id, "system", "会员服务通知",
                    "运营已为你手动开通 " + (tier == 2 ? "SVIP" : "VIP") + " " + days + " 天");
        } else {
            throw new BizException(400, "无效档位");
        }
        support.log("member.manual", "用户 #" + id + " 会员调整为 tier=" + tier + " +" + days + " 天");
        return Result.ok();
    }

    /** 详情：资料 + 订阅 + 消费 + 互动计数 */
    @GetMapping("/{id}")
    public Result<Map<String, Object>> detail(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @PathVariable long id) {
        support.require(key, authHeader, "users");
        Map<String, Object> user = adminManageMapper.userDetail(id);
        if (user == null) {
            throw new BizException(404, "用户不存在");
        }
        Map<String, Object> data = new HashMap<>(user);
        data.put("likesGiven", adminManageMapper.likesGiven(id));
        data.put("likesReceived", adminManageMapper.likesReceived(id));
        data.put("moments", adminManageMapper.momentCount(id));
        data.put("orders", adminManageMapper.orders(0, 50, id, null));
        data.put("photos", photoMapper.adminPhotos(id));
        return Result.ok(data);
    }

    private static String sha256(String s) {
        try {
            return HexFormat.of().formatHex(
                    MessageDigest.getInstance("SHA-256").digest(s.getBytes()));
        } catch (Exception e) {
            throw new BizException("sha256 failed");
        }
    }
}
