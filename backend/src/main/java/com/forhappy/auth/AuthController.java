package com.forhappy.auth;

import com.forhappy.common.BizException;
import com.forhappy.common.CityGeo;
import com.forhappy.common.JwtUtil;
import com.forhappy.common.Result;
import com.forhappy.common.UserContext;
import com.forhappy.entity.User;
import com.forhappy.mapper.UserMapper;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.LocalDate;
import java.util.HashMap;
import java.util.HexFormat;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private final UserMapper userMapper;
    private final JwtUtil jwtUtil;
    private final com.forhappy.common.PhoneCrypto phoneCrypto;
    private final com.forhappy.common.RateLimiter rateLimiter;

    @Value("${forhappy.sms.dev-code}")
    private String devCode;

    private static String clientIp(jakarta.servlet.http.HttpServletRequest request) {
        String xff = request.getHeader("X-Forwarded-For");
        return xff != null && !xff.isBlank()
                ? xff.split(",")[0].trim() : request.getRemoteAddr();
    }

    public static String sha256(String s) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest(s.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new BizException("sha256 failed");
        }
    }

    @PostMapping("/sms-code")
    public Result<Map<String, Object>> smsCode(
            @RequestBody Map<String, String> body,
            jakarta.servlet.http.HttpServletRequest request) {
        String phone = body.getOrDefault("phone", "");
        if (!phone.matches("1\\d{10}")) {
            throw new BizException(400, "手机号格式不正确");
        }
        // 频控：同号 60s 一条、每日 10 条；同 IP 每小时 20 条（防短信轰炸）
        String ip = clientIp(request);
        if (!rateLimiter.allow("sms:" + phone, 1, 60_000)) {
            throw new BizException(429, "发送太频繁，请 1 分钟后再试");
        }
        if (!rateLimiter.allow("sms-day:" + phone, 10, 24 * 3600_000L)) {
            throw new BizException(429, "今日验证码发送次数已达上限");
        }
        if (!rateLimiter.allow("sms-ip:" + ip, 20, 3600_000L)) {
            throw new BizException(429, "操作过于频繁，请稍后再试");
        }
        // 演示环境不真正下发短信，验证码固定为 dev-code（生产接入厂商并做 60s 防重发/每日上限）
        Map<String, Object> data = new HashMap<>();
        data.put("sent", true);
        return Result.ok(data);
    }

    @PostMapping("/login")
    public Result<Map<String, Object>> login(
            @RequestBody Map<String, String> body,
            jakarta.servlet.http.HttpServletRequest request) {
        String phone = body.getOrDefault("phone", "");
        String code = body.getOrDefault("code", "");
        if (!phone.matches("1\\d{10}")) {
            throw new BizException(400, "手机号格式不正确");
        }
        // 频控：同号 5 分钟 5 次、同 IP 每小时 30 次（防撞库）
        String ip = clientIp(request);
        if (!rateLimiter.allow("login:" + phone, 5, 300_000)) {
            throw new BizException(429, "尝试次数过多，请 5 分钟后再试");
        }
        if (!rateLimiter.allow("login-ip:" + ip, 30, 3600_000L)) {
            throw new BizException(429, "操作过于频繁，请稍后再试");
        }
        if (!devCode.equals(code)) {
            throw new BizException(400, "验证码错误");
        }
        User user = userMapper.findByPhoneHash(sha256(phone));
        boolean isNew = false;
        if (user == null) {
            user = new User();
            user.setPhoneHash(sha256(phone));
            user.setPhoneEnc(phoneCrypto.encrypt(phone));
            user.setNickname("用户" + phone.substring(7));
            userMapper.insert(user);
            isNew = true;
        }
        if (user.getStatus() != null && user.getStatus() == 5) {
            throw new BizException(403, "账号已注销，处于冷静期内");
        }
        if (user.getStatus() != null && user.getStatus() == 2) {
            throw new BizException(403, "账号已被禁用，如有疑问请联系客服");
        }
        if (user.getStatus() != null && user.getStatus() == 3) {
            throw new BizException(403, "账号已被封禁，如有疑问请联系客服");
        }
        if (user.getStatus() != null && user.getStatus() == 9) {
            throw new BizException(403, "账号不存在");
        }
        userMapper.touchActive(user.getId()); // 登录即视为活跃（活跃度排序/推荐分用）
        Map<String, Object> data = new HashMap<>();
        data.put("token", jwtUtil.issue(user.getId()));
        data.put("userId", user.getId());
        data.put("isNew", isNew);
        data.put("onboarded", user.getGender() != null && user.getGender() > 0);
        return Result.ok(data);
    }

    @PostMapping("/onboarding")
    public Result<Void> onboarding(@RequestBody Map<String, Object> body) {
        long uid = UserContext.get();
        User user = userMapper.findById(uid);
        if (user == null) {
            throw new BizException(404, "用户不存在");
        }
        int gender = ((Number) body.get("gender")).intValue();
        int prefer = ((Number) body.get("preferGender")).intValue();
        int birthYear = ((Number) body.get("birthYear")).intValue();
        if (java.time.LocalDate.now().getYear() - birthYear < 18) {
            throw new BizException(400, "未满 18 岁不能使用本应用");
        }
        user.setGender(gender);
        user.setPreferGender(prefer);
        user.setBirthday(LocalDate.of(birthYear, 1, 1));
        user.setCity(String.valueOf(body.getOrDefault("city", "杭州")));
        user.setLat(CityGeo.lat(user.getCity()));
        user.setLng(CityGeo.lng(user.getCity()));
        userMapper.onboarding(user);
        return Result.ok();
    }

    /** 注销账号：置为冷静期状态（status=5），信息流/配对随即不可见（设计 6.4：7 天后硬删） */
    @PostMapping("/deactivate")
    public Result<Void> deactivate() {
        userMapper.deactivate(UserContext.get());
        return Result.ok();
    }
}
