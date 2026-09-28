package com.forhappy.common;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

@Component
@RequiredArgsConstructor
public class AuthInterceptor implements HandlerInterceptor {

    private final JwtUtil jwtUtil;

    @Override
    public boolean preHandle(HttpServletRequest req, HttpServletResponse res, Object handler) {
        String header = req.getHeader("Authorization");
        Long uid = null;
        if (header != null && header.startsWith("Bearer ")) {
            uid = jwtUtil.parse(header.substring(7));
        }
        if (uid == null) {
            res.setStatus(401);
            res.setContentType("application/json;charset=UTF-8");
            try {
                res.getWriter().write("{\"code\":401,\"msg\":\"未登录\",\"data\":null}");
            } catch (Exception ignored) {
            }
            return false;
        }
        UserContext.set(uid);
        return true;
    }

    @Override
    public void afterCompletion(HttpServletRequest req, HttpServletResponse res,
                                Object handler, Exception ex) {
        UserContext.clear();
    }
}
