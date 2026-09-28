import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../api/api_client.dart';

/// 长连接服务（后端 /ws/chat，设计 9.4）：
/// 登录后建立连接，25s 心跳；断线指数退避重连；帧以广播流分发给各页面。
class WsService {
  WsService._();

  static final WsService instance = WsService._();

  WebSocketChannel? _channel;
  Timer? _heartbeat;
  Timer? _reconnect;
  int _retry = 0;
  bool _manualClose = false;
  bool _connecting = false;
  String? _token;

  final _frames = StreamController<Map<String, dynamic>>.broadcast();

  /// 所有下行帧（{"type":"message"|"match"|"pong"|...}）
  Stream<Map<String, dynamic>> get frames => _frames.stream;

  bool get connected => _channel != null;

  /// 幂等；退避窗口内重复调用直接返回（UI build 频繁触发也不会造成重连风暴）
  void ensureConnected(String? token) {
    if (token == null || token.isEmpty) return;
    if (_token != token) {
      _switchToken(token);
    }
    _token = token;
    if (_channel != null || _connecting || _reconnect != null) return;
    _connect();
  }

  /// 换 token（重新登录）：闭包捕获旧 channel，异步 onDone 不会误杀新连接
  void _switchToken(String token) {
    final old = _channel;
    _manualClose = true;
    old?.sink.close();
    _channel = null;
    _connecting = false;
    _reconnect?.cancel();
    _reconnect = null;
    _manualClose = false;
    _retry = 0;
  }

  void _connect() {
    if (_connecting) return;
    _connecting = true;
    final origin = ApiClient.baseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '');
    final wsUrl = Uri.parse(origin).replace(
      scheme: Uri.parse(origin).scheme == 'https' ? 'wss' : 'ws',
      path: '/ws/chat',
    );
    try {
      final channel = WebSocketChannel.connect(wsUrl);
      _channel = channel;
      var authenticated = false;
      channel.stream.listen(
        (data) {
          if (!authenticated) {
            // 首帧认证：服务端回 pong 即认证通过
            authenticated = true;
            _connecting = false;
            _retry = 0;
            _startHeartbeat();
            _onData(data);
            return;
          }
          _onData(data);
        },
        onError: (_) => _onDown(channel),
        onDone: () => _onDown(channel),
      );
      channel.ready
          .then((_) {
            // 连接建立即发 auth 帧（token 不进 URL，避免网关日志泄露）
            channel.sink.add('{"type":"auth","token":"${_token ?? ''}"}');
          })
          .catchError((_) => _onDown(channel));
    } catch (_) {
      _connecting = false;
      _onDown(_channel);
    }
  }

  void _onData(dynamic data) {
    if (data is! String) return;
    try {
      final j = jsonDecode(data);
      if (j is Map<String, dynamic>) {
        _frames.add(j);
      }
    } catch (_) {}
  }

  /// 连接断开。只清理"当前"连接：换 token 场景下旧连接的延迟 onDone
  /// 到达时 _channel 已是新连接，直接忽略
  void _onDown(WebSocketChannel? dead) {
    if (dead != null && _channel != dead) return;
    _stopHeartbeat();
    if (identical(_channel, dead)) _channel = null;
    _connecting = false;
    if (_manualClose || _token == null) return;
    // 指数退避重连：1s,2s,4s... 上限 30s（_retry 只在收到首帧时清零）
    _retry++;
    final delay = Duration(seconds: (_retry > 5 ? 30 : 1 << (_retry - 1)));
    _reconnect?.cancel();
    _reconnect = Timer(delay, () {
      _reconnect = null;
      if (_token != null && _channel == null) _connect();
    });
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeat = Timer.periodic(const Duration(seconds: 25), (_) {
      _sendRaw('{"type":"ping"}');
    });
  }

  void _stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  void _sendRaw(String payload) {
    try {
      _channel?.sink.add(payload);
    } catch (_) {
      _onDown(_channel);
    }
  }

  /// 退出登录时调用
  void close() {
    _manualClose = true;
    _token = null;
    _stopHeartbeat();
    _reconnect?.cancel();
    _reconnect = null;
    _channel?.sink.close();
    _channel = null;
    _connecting = false;
    _manualClose = false;
  }
}
