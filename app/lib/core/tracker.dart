import 'dart:async';

import '../api/api_client.dart';

/// 埋点上报（设计 10.4 最小集）：内存缓冲 + 定时批量上报，
/// 任何失败静默丢弃——埋点绝不影响主流程。
abstract final class Tracker {
  static final List<Map<String, dynamic>> _buffer = [];
  static Timer? _timer;

  /// 最小事件集：app_open / card_like / card_hide / match_success /
  /// message_send / report_submit / unmatch / member_paid
  static void log(String event, [Map<String, dynamic>? props]) {
    if (ApiClient.token == null) return;
    _buffer.add({'event': event, 'props': ?props});
    if (_buffer.length >= 10) {
      flush();
    }
    _timer ??= Timer.periodic(const Duration(seconds: 5), (_) => flush());
  }

  static Future<void> flush() async {
    if (_buffer.isEmpty) return;
    final batch = List.of(_buffer);
    _buffer.clear();
    try {
      await ApiClient.dio.post('/events', data: {'events': batch});
    } catch (_) {
      // 静默：埋点失败不重试不打扰
    }
  }
}
