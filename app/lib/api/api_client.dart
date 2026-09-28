import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 后端接口异常（携带业务 code，如 4001=配额用尽）
class ApiException implements Exception {
  ApiException(this.code, this.msg);

  final int code;
  final String msg;

  @override
  String toString() => 'ApiException($code, $msg)';
}

/// 本次运行内是否发生过"真实登录"（区分会话恢复，用于首次引导只弹一次）
bool freshLogin = false;

/// Dio 单例 + JWT 持有
abstract final class ApiClient {
  /// iOS 模拟器/macOS 共享宿主网络，localhost 即本机 8080
  static const baseUrl = 'http://localhost:8080/api/v1';

  static String? token;
  static int? myId;
  static String? myNickname;
  static String? myAvatar;
  static String? myCity;
  static bool onboarded = false;

  /// 我的资料原文（tags/city 等，共同点计算用）
  static Map<String, dynamic>? myProfile;

  /// 401 统一踢出回调：main 里挂到 authedProvider，触发即清会话回登录页
  static void Function()? onUnauthorized;

  // ---------- 会话持久化（重启免登录） ----------
  // token 存 Keychain/Keystore（flutter_secure_storage），非会话偏好走 SharedPreferences

  static const _secure = FlutterSecureStorage();

  static Future<void> saveSession() async {
    final sp = await SharedPreferences.getInstance();
    await _secure.write(key: 'token', value: token ?? '');
    await sp.setInt('userId', myId ?? 0);
    await sp.setString('nickname', myNickname ?? '');
    await sp.setString('avatar', myAvatar ?? '');
    await sp.setString('city', myCity ?? '');
    await sp.setBool('onboarded', onboarded);
  }

  /// 启动时恢复上次会话；token 有效（存在且未过期由后端校验）返回 true
  static Future<bool> restoreSession() async {
    final sp = await SharedPreferences.getInstance();
    var t = await _secure.read(key: 'token');
    // 旧版本明文 token 一次性迁移：读出后立即删除明文
    t ??= sp.getString('token');
    if (t != null) {
      final legacy = sp.getString('token');
      if (legacy != null) await sp.remove('token');
    }
    if (t == null || t.isEmpty) return false;
    token = t;
    myId = sp.getInt('userId');
    myNickname = sp.getString('nickname');
    myAvatar = sp.getString('avatar');
    myCity = sp.getString('city');
    onboarded = sp.getBool('onboarded') ?? false;
    return true;
  }

  static Future<void> clearSession() async {
    token = null;
    myId = null;
    myNickname = null;
    myAvatar = null;
    myCity = null;
    onboarded = false;
    myProfile = null;
    await _secure.delete(key: 'token');
    final sp = await SharedPreferences.getInstance();
    // 只清会话相关 key，不动其他偏好
    await sp.remove('userId');
    await sp.remove('nickname');
    await sp.remove('avatar');
    await sp.remove('city');
    await sp.remove('onboarded');
  }

  static final Dio dio =
      Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 12),
          ),
        )
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (token != null) {
                options.headers['Authorization'] = 'Bearer $token';
              }
              handler.next(options);
            },
          ),
        );

  /// 拆统一响应包 {code, msg, data}；code!=0 抛 ApiException
  static Future<Map<String, dynamic>> unwrap(
    Future<Response<dynamic>> f,
  ) async {
    Response resp;
    try {
      resp = await f;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['code'] != null) {
        _guard401((data['code'] as num).toInt());
        throw ApiException(
          (data['code'] as num).toInt(),
          (data['msg'] ?? '请求失败').toString(),
        );
      }
      if (e.response?.statusCode == 401) _guard401(401);
      throw ApiException(e.response?.statusCode ?? -1, '网络异常，请检查后端服务');
    }
    final data = resp.data;
    if (data is! Map || data['code'] != 0) {
      final code = data is Map ? (data['code'] as num?)?.toInt() ?? -1 : -1;
      _guard401(code);
      throw ApiException(
        code,
        data is Map ? (data['msg'] ?? '请求失败').toString() : '响应格式错误',
      );
    }
    final inner = data['data'];
    if (inner is Map<String, dynamic>) return inner;
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return {};
  }

  /// 拆返回列表型响应
  static Future<List<Map<String, dynamic>>> unwrapList(
    Future<Response<dynamic>> f,
  ) async {
    Response resp;
    try {
      resp = await f;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['code'] != null) {
        _guard401((data['code'] as num).toInt());
        throw ApiException(
          (data['code'] as num).toInt(),
          (data['msg'] ?? '请求失败').toString(),
        );
      }
      if (e.response?.statusCode == 401) _guard401(401);
      throw ApiException(e.response?.statusCode ?? -1, '网络异常，请检查后端服务');
    }
    final data = resp.data;
    if (data is! Map || data['code'] != 0) {
      final code = data is Map ? (data['code'] as num?)?.toInt() ?? -1 : -1;
      _guard401(code);
      throw ApiException(
        code,
        data is Map ? (data['msg'] ?? '请求失败').toString() : '响应格式错误',
      );
    }
    final inner = data['data'];
    return inner is List
        ? inner.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : const [];
  }

  /// 业务 401（token 过期/无效）：清会话并通知 UI 回登录页（幂等）
  static void _guard401(int code) {
    if (code != 401) return;
    if (token == null) return; // 未登录状态下避免重复触发
    clearSession();
    onUnauthorized?.call();
  }

  static Map<String, dynamic> mapOf(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  static List<Map<String, dynamic>> listOf(dynamic v) => v is List
      ? v.map((e) => Map<String, dynamic>.from(e as Map)).toList()
      : const [];
}
