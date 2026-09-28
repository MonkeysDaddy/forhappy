import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../../api/api_client.dart';
import '../../core/theme.dart';
import '../../core/tracker.dart';
import '../../state/providers.dart';
import '../shared/widgets.dart';
import 'agreement_page.dart';

/// 登录页：手机号 + 验证码（演示环境固定 123456）
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _phoneController = TextEditingController(text: '13800000100');
  final _codeController = TextEditingController(text: '123456');
  bool _loading = false;
  bool _sending = false;
  bool _agreed = false;
  int _countdown = 0;
  Timer? _timer;
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_countdown > 0 || _sending) return;
    final phone = _phoneController.text.trim();
    if (!RegExp(r'^1\d{10}$').hasMatch(phone)) {
      setState(() => _error = '请输入正确的手机号');
      return;
    }
    setState(() => _sending = true);
    try {
      await Api.smsCode(phone);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('验证码已发送（演示环境固定 123456）')));
      // 60s 防重发（设计 4.1）
      setState(() {
        _countdown = 60;
        _sending = false;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() => _countdown--);
        if (_countdown <= 0) t.cancel();
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.msg);
    } catch (_) {
      if (mounted) setState(() => _error = '无法连接服务器，请确认后端已启动');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await Api.login(
        _phoneController.text.trim(),
        _codeController.text.trim(),
      );
      // 拉取我的资料：昵称/头像/城市/标签（城市作为发现页默认筛选）
      final me = await Api.myProfile();
      ApiClient.myProfile = me;
      ApiClient.myNickname = me['nickname']?.toString();
      ApiClient.myAvatar = me['avatarUrl']?.toString();
      ApiClient.myCity = me['city']?.toString();
      ref.read(myProfileProvider.notifier).state = me;
      if (ApiClient.myCity != null && ApiClient.myCity!.isNotEmpty) {
        ref.read(cityProvider.notifier).state = ApiClient.myCity!;
        ref.read(locatedCityProvider.notifier).state = ApiClient.myCity!;
      }
      ref.read(authInfoProvider.notifier).state = AuthInfo(
        userId: ApiClient.myId ?? 0,
        nickname: ApiClient.myNickname ?? '我',
        onboarded: d['onboarded'] == true,
      );
      await ApiClient.saveSession();
      await ref.read(membershipProvider.notifier).syncFromServer();
      freshLogin = true;
      Tracker.log('app_open');
      if (!mounted) return;
      ref.read(authedProvider.notifier).state = true;
    } on ApiException catch (e) {
      setState(() => _error = e.msg);
    } catch (_) {
      setState(() => _error = '无法连接服务器，请确认后端已启动');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 背景柔光晕：蜜桃/珊瑚双色，营造"遇见"的暖意
      body: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _glow(const Color(0x2EFF8E7A), 260),
          ),
          Positioned(
            bottom: -40,
            left: -70,
            child: _glow(const Color(0x24FF5A76), 230),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const SizedBox(height: 28),
                    // 品牌图形标志：渐变圆角方块 + 微笑爱心（与 App 图标同源）
                    _BrandMark(size: 84),
                    const SizedBox(height: 20),
                    const GradientText(
                      'ForHappy',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '简单、快速、靠谱地遇见心动',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 44),
                    SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 无图标下划线式输入：安静、聚焦内容
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            cursorColor: brandColor,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: _inputDecoration('手机号'),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _codeController,
                            keyboardType: TextInputType.number,
                            cursorColor: brandColor,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: _inputDecoration('验证码（演示固定 123456）')
                                .copyWith(
                                  suffixIcon: Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: TextButton(
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        foregroundColor: brandColor,
                                      ),
                                      onPressed: (_countdown > 0 || _sending)
                                          ? null
                                          : _sendCode,
                                      child: Text(
                                        _countdown > 0
                                            ? '${_countdown}s后重发'
                                            : _sending
                                            ? '发送中…'
                                            : '获取验证码',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                          ),
                          // 错误提示：轻红色胶囊，不打断布局节奏
                          AnimatedSize(
                            duration: AppMotion.fast,
                            curve: AppMotion.easeOut,
                            alignment: Alignment.topCenter,
                            child: _error == null
                                ? const SizedBox(width: double.infinity)
                                : Padding(
                                    padding: const EdgeInsets.only(top: 14),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.error.withValues(
                                          alpha: 0.05,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            LucideIcons.alertCircle,
                                            size: 15,
                                            color: Color(0xFFDC2626),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              _error!,
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                color: Color(0xFFDC2626),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: GradientButton(
                              onPressed: _loading ? null : _login,
                              child: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      '登录',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: Checkbox(
                                  value: _agreed,
                                  activeColor: brandColor,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  onChanged: (v) =>
                                      setState(() => _agreed = v ?? false),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '我已阅读并同意',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AgreementPage(
                                      title: '用户协议',
                                      body: AgreementPage.userAgreement,
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  '《用户协议》',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: brandColor,
                                  ),
                                ),
                              ),
                              Text(
                                '和',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AgreementPage(
                                      title: '隐私政策',
                                      body: AgreementPage.privacyPolicy,
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  '《隐私政策》',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: brandColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 背景柔光晕圆
  Widget _glow(Color color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Color(0x00000000)]),
        ),
      ),
    );
  }

  /// 下划线式输入框：品牌色聚焦线 + 安静的提示文字
  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.textTertiary,
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: Colors.transparent,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.divider, width: 1.6),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: brandColor, width: 1.6),
      ),
    );
  }
}

/// 品牌图形标志：珊瑚渐变圆角方块 + 白色微笑爱心（与 App 图标同源）
class _BrandMark extends StatelessWidget {
  const _BrandMark({this.size = 84});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: brandGradient,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: const Color(0x33FF4F6E),
            blurRadius: 24,
            offset: Offset(0, size * 0.09),
          ),
        ],
      ),
      child: Center(
        child: Icon(LucideIcons.heart, size: size * 0.46, color: Colors.white),
      ),
    );
  }
}
