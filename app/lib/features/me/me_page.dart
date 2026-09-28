import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/providers.dart';
import '../member/member_center_page.dart';
import '../shared/widgets.dart';
import 'account_security_page.dart';
import 'blacklist_page.dart';
import 'edit_profile_page.dart';
import 'photo_manager_page.dart';
import 'verify_center_page.dart';

/// Tab4 我的
class MePage extends ConsumerWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(membershipProvider);
    final authInfo = ref.watch(authInfoProvider);
    final completeness =
        _profileCompleteness(ref.watch(myProfileProvider));

    return ListView(
      controller: TabScrollRegistry.controllerFor(4),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
      children: [
        const GradientPageHeader(
          bottom: 14,
          child: SizedBox(
            width: double.infinity,
            child: Text(
              '我的',
              style: TextStyle(
                fontFamily: brandDisplayFont,
                fontSize: 27,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        // 个人资料卡（整卡进入编辑）
        GestureDetector(
          onTap: () => _push(context, const EditProfilePage()),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: cardDecoration(),
            child: Row(
              children: [
                PersonAvatar(
                  url: ApiClient.myAvatar,
                  size: 64,
                  fallbackText: '我',
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              authInfo?.nickname ?? '我',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (membership.isMember) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                gradient: AppColors.goldGradient,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                membership.tier.label,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ApiClient.myCity ?? '',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.fill,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.penLine,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        // 资料完成度（中国交友产品最重要的新用户激活手段）
        if (completeness < 100) ...[
          GestureDetector(
            onTap: () => _push(context, const EditProfilePage()),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: cardDecoration(),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: completeness / 100,
                          strokeWidth: 3.5,
                          backgroundColor: AppColors.divider,
                          valueColor: const AlwaysStoppedAnimation(brandColor),
                        ),
                        Text(
                          '$completeness%',
                          style: const TextStyle(
                            fontFamily: brandDisplayFont,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: brandColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '完善资料，被喜欢的概率翻倍',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _missingItems(ref.read(myProfileProvider)),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        // 会员横幅
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            AppPageRoute(builder: (_) => const MemberCenterPage()),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: membership.isMember
                  ? AppColors.goldGradient
                  : brandGradient,
              borderRadius: BorderRadius.circular(cardRadius),
            ),
            child: Row(
              children: [
                Icon(
                  membership.isMember ? LucideIcons.crown : LucideIcons.crown,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    membership.isMember
                        ? '${membership.tier.label} 生效中，${_fmt(membership.expireAt)} 到期'
                        : '开通 VIP / SVIP · 解锁无限喜欢与更多权益',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  LucideIcons.chevronRight,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        // 功能菜单
        Container(
          decoration: cardDecoration(),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                _menuTile(
                  context,
                  LucideIcons.user,
                  '编辑资料',
                  const EditProfilePage(),
                ),
                Divider(height: 1, indent: 52, color: AppColors.divider),
                _menuTile(
                  context,
                  LucideIcons.images,
                  '照片墙',
                  const PhotoManagerPage(),
                ),
                Divider(height: 1, indent: 52, color: AppColors.divider),
                _menuTile(
                  context,
                  LucideIcons.badgeCheck,
                  '真人认证',
                  const VerifyCenterPage(),
                ),
                Divider(height: 1, indent: 52, color: AppColors.divider),
                _menuTile(
                  context,
                  LucideIcons.shieldCheck,
                  '账号与安全',
                  const AccountSecurityPage(),
                ),
                Divider(height: 1, indent: 52, color: AppColors.divider),
                _menuTile(
                  context,
                  LucideIcons.ban,
                  '黑名单管理',
                  const BlacklistPage(),
                ),
                Divider(height: 1, indent: 52, color: AppColors.divider),
                _menuTile(context, LucideIcons.circleHelp, '帮助与反馈'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            'ForHappy · 已连接后端（localhost:8080）',
            style: TextStyle(fontSize: 11, color: AppColors.textDisabled),
          ),
        ),
      ],
    );
  }

  /// 资料完成度：照片/头像、简介、标签、身高、职业、学历 各占一定权重
  int _profileCompleteness(Map<String, dynamic>? profile) {
    if (profile == null) return 0;
    final user = profile['user'] is Map
        ? Map<String, dynamic>.from(profile['user'] as Map)
        : <String, dynamic>{};
    final photos = profile['photos'] is List
        ? profile['photos'] as List
        : const [];
    var score = 0;
    if (photos.isNotEmpty) score += 30; // 照片是核心资产
    if ((user['bio']?.toString() ?? '').isNotEmpty) score += 20;
    if (user['tags'] is List && (user['tags'] as List).isNotEmpty) score += 20;
    if ((user['occupation']?.toString() ?? '').isNotEmpty) score += 10;
    if ((user['education']?.toString() ?? '').isNotEmpty) score += 10;
    if (user['heightCm'] != null) score += 10;
    return score;
  }

  /// 缺失项明细（横幅副标题）：告诉用户"补什么"而不只是"没满"
  String _missingItems(Map<String, dynamic>? profile) {
    if (profile == null) return '照片、简介、兴趣标签';
    final user = profile['user'] is Map
        ? Map<String, dynamic>.from(profile['user'] as Map)
        : <String, dynamic>{};
    final photos = profile['photos'] is List
        ? profile['photos'] as List
        : const [];
    final missing = <String>[
      if (photos.isEmpty) '照片',
      if ((user['bio']?.toString() ?? '').isEmpty) '简介',
      if (user['tags'] is! List || (user['tags'] as List).isEmpty) '兴趣标签',
      if ((user['occupation']?.toString() ?? '').isEmpty) '职业',
      if ((user['education']?.toString() ?? '').isEmpty) '学历',
      if (user['heightCm'] == null) '身高',
    ];
    return '还差：${missing.take(3).join(' · ')}${missing.length > 3 ? ' 等' : ''}';
  }

  String _fmt(DateTime? t) => t == null
      ? ''
      : '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  Widget _menuTile(
    BuildContext context,
    IconData icon,
    String title, [
    Widget? page,
  ]) {
    return ListTile(
      leading: Icon(icon, size: 22, color: AppColors.textSecondary),
      title: Text(title, style: const TextStyle(fontSize: 14.5)),
      trailing: Icon(
        LucideIcons.chevronRight,
        size: 19,
        color: AppColors.textDisabled,
      ),
      onTap: () {
        if (page != null) {
          _push(context, page);
        } else {
          _todo(context);
        }
      },
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.push(context, AppPageRoute(builder: (_) => page));
  }

  void _todo(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('演示版暂未实现'),
        duration: Duration(milliseconds: 800),
      ),
    );
  }
}
