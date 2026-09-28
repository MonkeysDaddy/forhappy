import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../../api/api_client.dart';
import '../../core/theme.dart';
import '../shared/widgets.dart';
import '../../state/providers.dart';
import 'blacklist_page.dart';

/// 账号与安全：黑名单入口 / 退出登录 / 注销账号（设计 4.7、6.4）
/// 隐藏距离开关在途防抖旗标（单实例页面，库级变量即可）
bool _hideSwitchBusy = false;

class AccountSecurityPage extends ConsumerWidget {
  const AccountSecurityPage({super.key});

  bool _hideDistanceOf(WidgetRef ref) {
    final user = ref.read(myProfileProvider)?['user'];
    return user is Map && user['hideDistance'] == 1;
  }

  /// 切换距离可见性：全量合并资料后提交（后端 PUT /me 为整行更新）
  /// 在途防抖 + 失败提示（开关受控于 provider，失败自动弹回）
  Future<void> _toggleHideDistance(
      bool v, WidgetRef ref, BuildContext context) async {
    if (_hideSwitchBusy) return;
    _hideSwitchBusy = true;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final profile = Map<String, dynamic>.from(
        (ref.read(myProfileProvider)?['user'] as Map?)?.cast<String, dynamic>() ??
            {},
      );
      profile['hideDistance'] = v ? 1 : 0;
      await Api.updateProfile(profile);
      final me = await Api.myProfile();
      ApiClient.myProfile = me;
      ref.read(myProfileProvider.notifier).state = me;
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('设置失败，请重试')));
    } finally {
      _hideSwitchBusy = false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hideDistance = _hideDistanceOf(ref);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const GradientAppBar(title: '账号与安全'),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // 隐私：距离可见性（女性用户核心关注）
          Container(
            decoration: cardDecoration(),
            child: Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                secondary: const Icon(
                  LucideIcons.locateOff,
                  size: 22,
                  color: Colors.black54,
                ),
                title: const Text('隐藏我的精确距离', style: TextStyle(fontSize: 14.5)),
                subtitle: Text(
                  hideDistance ? '其他人看不到你和 Ta 的距离' : '其他人可以看到精确距离',
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
                value: hideDistance,
                activeThumbColor: brandColor,
                onChanged: (v) => _toggleHideDistance(v, ref, context),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: cardDecoration(),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      LucideIcons.ban,
                      size: 22,
                      color: Colors.black54,
                    ),
                    title: const Text(
                      '黑名单管理',
                      style: TextStyle(fontSize: 14.5),
                    ),
                    trailing: const Icon(
                      LucideIcons.chevronRight,
                      size: 19,
                      color: Colors.black26,
                    ),
                    onTap: () => Navigator.push(
                      context,
                      AppPageRoute(builder: (_) => const BlacklistPage()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: cardDecoration(),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      LucideIcons.logOut,
                      size: 22,
                      color: AppColors.textSecondary,
                    ),
                    title: const Text('退出登录', style: TextStyle(fontSize: 14.5)),
                    onTap: () => _logout(context, ref),
                  ),
                  Divider(
                    height: 1,
                    indent: 52,
                    color: AppColors.divider,
                  ),
                  ListTile(
                    leading: const Icon(
                      LucideIcons.userX,
                      size: 22,
                      color: Color(0xFFDC2626),
                    ),
                    title: const Text(
                      '注销账号',
                      style: TextStyle(
                        fontSize: 14.5,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    subtitle: const Text(
                      '提交后进入 7 天冷静期，期间无法登录',
                      style: TextStyle(fontSize: 11.5, color: Colors.black38),
                    ),
                    onTap: () => _deactivate(context, ref),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              '如遇紧急安全问题，请通过"帮助与反馈"联系客服',
              style: TextStyle(fontSize: 11, color: Colors.black26),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('退出登录？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    freshLogin = false;
    await logout(ref);
    ref.read(authedProvider.notifier).state = false;
    messenger.showSnackBar(const SnackBar(content: Text('已退出登录')));
  }

  Future<void> _deactivate(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('确认注销账号？'),
        content: const Text(
          '注销后你的资料将不再对任何人可见，进入 7 天冷静期。'
          '冷静期内重新注册同号码将无法登录，期满后个人信息将被删除。',
          style: TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('再想想'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认注销'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.deactivate();
      await ApiClient.clearSession();
      freshLogin = false;
      ref.read(authInfoProvider.notifier).state = null;
      ref.read(authedProvider.notifier).state = false;
      messenger.showSnackBar(
        const SnackBar(content: Text('注销申请已提交，7 天冷静期后生效')),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.msg)));
    }
  }
}
