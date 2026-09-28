package com.forhappy.admin;

import com.forhappy.common.BizException;
import com.forhappy.mapper.AdminManageMapper;
import java.util.Map;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

/** 管理接口公共鉴权（RBAC 会话 + 超级密钥）与审计日志 */
@Component
@RequiredArgsConstructor
public class AdminApiSupport {

    /** 权限点：控制器各自声明所需权限；super 拥有全部 */
    private static final Map<String, java.util.Set<String>> ROLE_PERMISSIONS = Map.of(
            "super", java.util.Set.of("*"),
            "ops", java.util.Set.of("stats", "commerce", "ops", "logs"),
            "reviewer", java.util.Set.of("stats", "content"),
            "support", java.util.Set.of("stats", "users"));

    private final AdminManageMapper adminManageMapper;
    private final AdminKeyHolder keyHolder;
    private final AdminSessionStore sessionStore;

    private record Auth(String username, String role) {}

    /** Master Key 校验（应急通道） */
    public boolean isMaster(String authHeader, String key) {
        if (key != null && keyHolder.adminKey().equals(key)) return true;
        String bearer = authHeader != null && authHeader.startsWith("Bearer ")
                ? authHeader.substring("Bearer ".length()) : null;
        return bearer != null && keyHolder.adminKey().equals(bearer);
    }

    private Auth resolve(String key, String authHeader) {
        // 1) Master Key（X-Admin-Key 或 Bearer）
        if (key != null && keyHolder.adminKey().equals(key)) {
            return new Auth("master", "super");
        }
        String bearer = authHeader != null && authHeader.startsWith("Bearer ")
                ? authHeader.substring("Bearer ".length()) : null;
        if (bearer != null && keyHolder.adminKey().equals(bearer)) {
            return new Auth("master", "super");
        }
        // 2) RBAC 会话
        var session = sessionStore.validate(bearer);
        if (session != null) {
            return new Auth(session.username(), session.role());
        }
        throw new BizException(401, "管理密钥错误");
    }

    /** 鉴权并校验权限点 */
    public void require(String key, String authHeader, String permission) {
        Auth auth = resolve(key, authHeader);
        var perms = ROLE_PERMISSIONS.getOrDefault(auth.role(), java.util.Set.of());
        if (!perms.contains("*") && !perms.contains(permission)) {
            throw new BizException(403, "无权访问该功能（" + permission + "）");
        }
    }

    /** 审计日志：自动记录操作者与来源 IP */
    public void log(String action, String detail) {
        String ip = "";
        var attrs = RequestContextHolder.getRequestAttributes();
        if (attrs instanceof ServletRequestAttributes sra) {
            String xff = sra.getRequest().getHeader("X-Forwarded-For");
            ip = xff != null && !xff.isBlank()
                    ? xff.split(",")[0].trim() : sra.getRequest().getRemoteAddr();
        }
        adminManageMapper.insertAdminLogWithIp(currentUser(), action, detail, ip);
    }

    private String currentUser() {
        var attrs = RequestContextHolder.getRequestAttributes();
        if (attrs instanceof ServletRequestAttributes sra) {
            String token = sra.getRequest().getHeader("Authorization");
            if (token != null && token.startsWith("Bearer ")) {
                var session = sessionStore.validate(token.substring("Bearer ".length()));
                if (session != null) return session.username();
            }
            String key = sra.getRequest().getHeader("X-Admin-Key");
            if (key != null && keyHolder.adminKey().equals(key)) return "master";
        }
        return "unknown";
    }
}
