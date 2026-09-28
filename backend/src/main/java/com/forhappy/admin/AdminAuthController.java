package com.forhappy.admin;

import com.forhappy.common.BizException;
import com.forhappy.common.RateLimiter;
import com.forhappy.common.Result;
import com.forhappy.mapper.AdminManageMapper;
import jakarta.servlet.http.HttpServletRequest;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.HashMap;
import java.util.HexFormat;
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

/** 管理员登录（RBAC 会话）与账号管理（仅 super） */
@RestController
@RequestMapping("/api/v1/admin/auth")
@RequiredArgsConstructor
public class AdminAuthController {

    /** 登录请求体 */
    public record Creds(String password, String username) {}

    private final AdminManageMapper adminManageMapper;
    private final AdminSessionStore sessionStore;
    private final AdminApiSupport support;
    private final RateLimiter rateLimiter;

    @Value("${forhappy.admin.key:forhappy-admin}")
    private String masterKey;

    private static final SecureRandom RANDOM = new SecureRandom();

    private String sha(String salt, String password) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest((salt + password).getBytes(
                            java.nio.charset.StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new BizException("hash failed");
        }
    }

    private static String clientIp(HttpServletRequest request) {
        String xff = request.getHeader("X-Forwarded-For");
        return xff != null && !xff.isBlank()
                ? xff.split(",")[0].trim() : request.getRemoteAddr();
    }

    private Map<String, Object> accountOrNull(String authHeader) {
        String token = authHeader != null && authHeader.startsWith("Bearer ")
                ? authHeader.substring("Bearer ".length()) : null;
        var session = sessionStore.validate(token);
        return session == null ? null : Map.of(
                "username", session.username(), "role", session.role());
    }

    /** 超管：Master Key 直接通过 */
    private boolean isSuperByMaster(String authHeader, String key) {
        return support.isMaster(authHeader, key);
    }

    @PostMapping("/login")
    public Result<Map<String, Object>> login(
            @RequestBody Creds creds, HttpServletRequest request) {
        String username = creds.username() == null ? "" : creds.username().trim();
        String password = creds.password() == null ? "" : creds.password();
        String ip = clientIp(request);
        if (!rateLimiter.allow("alogin:" + username + ":" + ip, 5, 300_000)) {
            throw new BizException(429, "尝试次数过多，请 5 分钟后再试");
        }
        // 超级密钥应急通道：直接以密钥为 token（无状态，重启不失效）
        if (password.equals(masterKey)) {
            Map<String, Object> data = new HashMap<>();
            data.put("accessToken", masterKey);
            data.put("username", "master");
            return Result.ok(data);
        }
        Map<String, Object> account = adminManageMapper.findAdminByUsername(username);
        if (account == null
                || ((Number) account.get("status")).intValue() != 1
                || !sha((String) account.get("salt"), password)
                        .equals(account.get("passwordHash"))) {
            throw new BizException(401, "用户名或密码错误");
        }
        String token = sessionStore.create(username,
                (String) account.get("role"));
        Map<String, Object> data = new HashMap<>();
        data.put("accessToken", token);
        data.put("username", username);
        data.put("role", account.get("role"));
        return Result.ok(data);
    }

    @GetMapping("/me")
    public Result<Map<String, Object>> me(
            @RequestHeader(value = "Authorization", required = false) String authHeader) {
        Map<String, Object> account = accountOrNull(authHeader);
        if (account == null) {
            throw new BizException(401, "未登录");
        }
        return Result.ok(account);
    }

    // ---------- 账号管理（仅 super） ----------

    private void requireSuper(String authHeader) {
        // Master Key 应急通道
        if (authHeader != null && authHeader.startsWith("Bearer ")
                && masterKey.equals(authHeader.substring("Bearer ".length()))) {
            return;
        }
        String token = authHeader != null && authHeader.startsWith("Bearer ")
                ? authHeader.substring("Bearer ".length()) : null;
        var session = sessionStore.validate(token);
        if (session != null && "super".equals(session.role())) {
            return;
        }
        throw new BizException(403, "仅超级管理员可管理账号");
    }

    @GetMapping("/accounts")
    public Result<List<Map<String, Object>>> accounts(
            @RequestHeader(value = "Authorization", required = false) String authHeader) {
        requireSuper(authHeader);
        return Result.ok(adminManageMapper.adminAccounts());
    }

    @PostMapping("/accounts")
    public Result<Void> create(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestBody Map<String, Object> body) {
        requireSuper(authHeader);
        String username = body.getOrDefault("username", "").toString().trim();
        String password = body.getOrDefault("password", "").toString();
        String role = body.getOrDefault("role", "support").toString();
        if (!username.matches("[a-zA-Z0-9_]{3,32}")) {
            throw new BizException(400, "用户名 3-32 位字母数字下划线");
        }
        if (password.length() < 6) {
            throw new BizException(400, "密码至少 6 位");
        }
        if (!List.of("super", "ops", "reviewer", "support").contains(role)) {
            throw new BizException(400, "无效角色");
        }
        byte[] saltBytes = new byte[16];
        RANDOM.nextBytes(saltBytes);
        String salt = HexFormat.of().formatHex(saltBytes);
        try {
            adminManageMapper.insertAdminAccount(username,
                    sha(salt, password), salt, role);
        } catch (Exception e) {
            throw new BizException(409, "用户名已存在");
        }
        support.log("account.create", "创建管理员 " + username + " (" + role + ")");
        return Result.ok();
    }

    @PutMapping("/accounts/{id}/status")
    public Result<Void> setStatus(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @PathVariable long id,
            @RequestBody Map<String, Object> body) {
        requireSuper(authHeader);
        int status = body.containsKey("status")
                ? ((Number) body.get("status")).intValue() : 1;
        if (status != 0 && status != 1) {
            throw new BizException(400, "无效状态");
        }
        adminManageMapper.setAdminStatus(id, status);
        sessionStore.revokeAll(); // 简化处理：禁用后全员重新登录
        support.log("account.status", "管理员 #" + id
                + (status == 1 ? " 启用" : " 停用"));
        return Result.ok();
    }

    @PutMapping("/accounts/{id}/password")
    public Result<Void> resetPassword(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @PathVariable long id,
            @RequestBody Map<String, Object> body) {
        requireSuper(authHeader);
        String password = body.getOrDefault("password", "").toString();
        if (password.length() < 6) {
            throw new BizException(400, "密码至少 6 位");
        }
        byte[] saltBytes = new byte[16];
        RANDOM.nextBytes(saltBytes);
        String salt = HexFormat.of().formatHex(saltBytes);
        adminManageMapper.resetAdminPassword(id, sha(salt, password), salt);
        support.log("account.reset-password", "管理员 #" + id + " 密码已重置");
        return Result.ok();
    }
}
