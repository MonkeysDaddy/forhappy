package com.forhappy.ws;

import com.forhappy.common.JwtUtil;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.server.ServerHttpRequest;
import org.springframework.http.server.ServerHttpResponse;
import org.springframework.http.server.ServletServerHttpRequest;
import org.springframework.lang.NonNull;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;
import org.springframework.web.socket.server.HandshakeInterceptor;

/**
 * WS 端点注册。鉴权采用"首帧认证"：握手不携带 token（避免 JWT 进入网关访问日志），
 * 客户端连接后须在 5 秒内发送 {"type":"auth","token":"<JWT>"}，超时或校验失败即断开。
 */
@Configuration
@EnableWebSocket
@RequiredArgsConstructor
public class WsConfig implements WebSocketConfigurer {

    private final ChatWsHandler chatWsHandler;

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        registry.addHandler(chatWsHandler, "/ws/chat")
                .setAllowedOrigins("*");
    }
}
