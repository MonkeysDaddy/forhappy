import 'dart:ui';

import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../models/models.dart';

/// 头像（圆形，网络图失败时降级为渐变占位）
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    super.key,
    required this.url,
    this.size = 52,
    this.fallbackText = '🙂',
    this.onlineMinutes,
    this.verified = false,
  });

  final String? url;
  final double size;
  final String fallbackText;

  /// 距最后活跃分钟数（≤30 在线 → 绿色状态环）
  final int? onlineMinutes;

  /// 已认证 → 珊瑚渐变环
  final bool verified;

  bool get _online => (onlineMinutes ?? 999) <= 30;

  @override
  Widget build(BuildContext context) {
    final ring = verified || _online;
    final avatar = ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url == null
            ? _fallback()
            : Image.network(
                url!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(),
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : _fallback(),
              ),
      ),
    );
    if (!ring) return avatar;
    // 状态环：认证渐变环 > 在线绿环，白色分隔 2px（Story 环语言）
    final ringWidth = (size * 0.045).clamp(1.8, 3.2);
    return Container(
      padding: EdgeInsets.all(ringWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: verified ? brandGradient : null,
        color: verified ? null : AppColors.wechatGreen,
      ),
      child: Container(
        padding: const EdgeInsets.all(1.8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.appBg,
        ),
        child: avatar,
      ),
    );
  }

  Widget _fallback() => Container(
    decoration: const BoxDecoration(gradient: brandGradient),
    alignment: Alignment.center,
    child: Text(
      fallbackText,
      style: TextStyle(fontSize: size * 0.4, color: Colors.white),
    ),
  );
}

/// 卡片主图（3:4，圆角，带加载占位与失败降级；[scrim] 加底部压暗渐变）
class PersonPhoto extends StatelessWidget {
  const PersonPhoto({
    super.key,
    required this.url,
    this.radius = cardRadius,
    this.scrim = false,
  });

  final String url;
  final double radius;
  final bool scrim;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(radius),
      ),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                decoration: const BoxDecoration(gradient: brandGradient),
                alignment: Alignment.center,
                child: const Icon(
                  LucideIcons.user,
                  size: 64,
                  color: Colors.white70,
                ),
              ),
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : Container(color: AppColors.brand50),
            ),
            if (scrim)
              DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.center,
                    colors: [Color(0x59000000), Color(0x00000000)],
                    stops: [0.0, 0.45],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 真人认证角标（白圆底 + 微阴影，全工程统一形态）
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '已真人认证',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          boxShadow: AppShadows.sm,
        ),
        alignment: Alignment.center,
        child: Icon(
          LucideIcons.badgeCheck,
          size: size * 0.68,
          color: AppColors.verifiedBlue,
        ),
      ),
    );
  }
}

/// 距离气泡（毛玻璃胶囊，稳定压在任意照片上）
class DistanceChip extends StatelessWidget {
  const DistanceChip({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0x47000000),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.mapPin, size: 12, color: Colors.white),
              const SizedBox(width: 3),
              Text(
                text,
                style: const TextStyle(fontSize: 11, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ❤ 喜欢按钮：点击弹性回弹；[glass] 毛玻璃形态用于压在照片上
class LikeButton extends StatefulWidget {
  const LikeButton({
    super.key,
    required this.onTap,
    this.liked = false,
    this.size = 40,
    this.glass = false,
  });

  final VoidCallback onTap;
  final bool liked;
  final double size;
  final bool glass;

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton>
    with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 1.18)
          .chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.18, end: 1.0)
          .chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 65,
    ),
  ]).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    _burst.dispose();
    super.dispose();
  }

  /// 粒子爆发层：8 颗小圆点呈放射状飞散并淡出
  Widget _burstLayer() {
    return AnimatedBuilder(
      animation: _burst,
      builder: (context, _) {
        final t = _burst.value;
        if (t == 0 || t >= 1) return const SizedBox.shrink();
        return IgnorePointer(
          child: CustomPaint(painter: _BurstPainter(t), size: Size.infinite),
        );
      },
    );
  }

  void _handleTap() {
    _controller.forward(from: 0);
    _burst.forward(from: 0);
    // 触觉反馈（设计 7.6）：喜欢是最高频动作，轻触感强化"心动"的物理确认
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      widget.liked ? Icons.favorite : Icons.favorite_border,
      color: widget.glass && !widget.liked ? Colors.white : brandColor,
      size: widget.size * 0.55,
    );
    return ScaleTransition(
      scale: Tween<double>(begin: 1, end: 1.18).animate(_scale),
      child: Stack(
        fit: StackFit.passthrough,
        alignment: Alignment.center,
        children: [
          _burstLayer(),
          widget.glass
              ? ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        color: const Color(0x33FFFFFF),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0x4DFFFFFF),
                          width: 0.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _handleTap,
                        child: icon,
                      ),
                    ),
                  ),
                )
              : Material(
                  color: AppColors.surface,
                  shape: const CircleBorder(),
                  elevation: 0,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _handleTap,
                    child: SizedBox(
                      width: widget.size,
                      height: widget.size,
                      child: icon,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

/// 点赞粒子：8 颗品牌色/金色圆点放射飞散
class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t);

  final double t;

  static const _colors = [
    Color(0xFFFF5A76),
    Color(0xFFFF8E7A),
    Color(0xFFE0BE8C),
    Color(0xFFFFC3C9),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * (0.5 + t * 0.85);
    final opacity = (1 - t).clamp(0.0, 1.0);
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 + 0.4;
      final pos =
          center + Offset(radius * math.cos(angle), radius * math.sin(angle));
      final paint = Paint()
        ..color = _colors[i % _colors.length].withValues(alpha: opacity * 0.9);
      canvas.drawCircle(pos, 2.6 * (1 - t * 0.4), paint);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

/// 性别图标（♂ 蓝 / ♀ 粉）
class GenderIcon extends StatelessWidget {
  const GenderIcon({super.key, required this.gender, this.size = 13});

  final Gender gender;
  final double size;

  @override
  Widget build(BuildContext context) {
    final male = gender == Gender.male;
    return Text(
      male ? '♂' : '♀',
      style: TextStyle(
        fontSize: size,
        height: 1.1,
        fontWeight: FontWeight.w700,
        color: male ? AppColors.maleBlue : AppColors.femalePink,
      ),
    );
  }
}

/// 会员徽章（VIP 金 / SVIP 黑金），非会员不显示
class MemberBadge extends StatelessWidget {
  const MemberBadge({super.key, required this.tier, this.fontSize = 9});

  final MemberTier tier;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    if (tier == MemberTier.none) return const SizedBox.shrink();
    final isSvip = tier == MemberTier.svip;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        gradient: isSvip ? AppColors.svipGradient : AppColors.goldGradient,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        tier.label,
        style: TextStyle(
          fontSize: fontSize,
          height: 1.1,
          fontWeight: FontWeight.w800,
          color: isSvip ? AppColors.svipGold : Colors.white,
        ),
      ),
    );
  }
}

/// "已绑定微信"小标识（绿色圆角方块 + 微）
class WeChatFlag extends StatelessWidget {
  const WeChatFlag({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '已绑定微信',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.wechatGreen,
          borderRadius: BorderRadius.circular(size * 0.28),
        ),
        alignment: Alignment.center,
        child: Text(
          '微',
          style: TextStyle(
            fontSize: size * 0.6,
            height: 1,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// 活跃状态（<10 分钟"在线"绿点 / <60 分钟"刚刚活跃"灰点 / 更久不显示）
class OnlineDot extends StatelessWidget {
  const OnlineDot({
    super.key,
    required this.lastActiveMinutes,
    this.compact = false,
  });

  final int lastActiveMinutes;

  /// 紧凑形态（照片卡上）：只显示"在线"，离线不占位——把宽度让给昵称
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (lastActiveMinutes >= 60) return const SizedBox.shrink();
    final online = lastActiveMinutes < 10;
    if (compact && !online) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: online ? AppColors.wechatGreen : AppColors.textTertiary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          online ? '在线' : '刚刚活跃',
          style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
        ),
      ],
    );
  }
}

/// 兴趣标签胶囊
class TagChip extends StatelessWidget {
  const TagChip(this.tag, {super.key, this.highlight = false});

  final String tag;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlight ? AppColors.brand100 : AppColors.fill,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 12,
          color: highlight ? brandColor : AppColors.textSecondary,
          fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}

/// 渐变文字（品牌 logo / 页标题 / 庆祝标题）
class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) =>
          brandGradient.createShader(Offset.zero & bounds.size),
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}

/// 渐变主 CTA（带柔光阴影；[gradient]/[glowColor] 可换 SVIP 黑金等）
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.height = 48,
    this.width,
    this.gradient = brandGradient,
    this.glowColor,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final double height;
  final double? width;
  final Gradient gradient;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: glowColor ?? AppColors.brandGlow,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onPressed,
          child: Container(
            height: height,
            width: width,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: DefaultTextStyle(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// 统一空态：品牌色圆底图标 + 两级文案 + 可选 CTA
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.image,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// 品牌插画（提供时优先于图标圆底）
  final String? image;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (image != null)
            Image.asset(image!, width: 150, height: 150, fit: BoxFit.contain)
          else
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.brand50,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 48, color: brandColor),
            ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: brandColor,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 品牌渐变导航条：珊瑚渐变一直延伸到状态栏（电池条）底下，白字白钮。
/// 需要特殊场景（如详情页照片沉浸）时仍直接用透明 AppBar。
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GradientAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.leading,
  });

  final String? title;

  /// 自定义标题（如聊天页的头像+昵称），优先于 [title]
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title:
          titleWidget ??
          (title == null
              ? null
              : Text(
                  title!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                )),
      actions: actions,
      leading: leading,
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: headerGradientForNow(dark: AppColors.isDark),
        ),
      ),
      systemOverlayStyle: SystemUiOverlayStyle.light,
    );
  }
}

/// 导航 push 防抖：快速双击不会压入两个相同页面
final _lastPushAt = <String, DateTime>{};

Future<void> pushThrottled(
  BuildContext context,
  Widget page, {
  String tag = 'default',
}) async {
  final now = DateTime.now();
  final last = _lastPushAt[tag];
  if (last != null &&
      now.difference(last) < const Duration(milliseconds: 600)) {
    return;
  }
  _lastPushAt[tag] = now;
  await Navigator.push(context, AppPageRoute(builder: (_) => page));
}

/// 主页面渐变头部：品牌渐变一直延伸到状态栏（电池条）底下，
/// 内部自动留出状态栏高度，标题/图标一律白色。
class GradientPageHeader extends StatelessWidget {
  const GradientPageHeader({super.key, required this.child, this.bottom = 14});

  final Widget child;

  /// 底部内边距（默认 14，可按页面调节）
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, top + 12, 16, bottom),
      decoration: BoxDecoration(
        gradient: headerGradientForNow(dark: AppColors.isDark),
      ),
      child: child,
    );
  }
}

/// 缓存图片：磁盘缓存 + 加载占位 + 失败降级（全工程照片统一入口）
class CachedPhoto extends StatelessWidget {
  const CachedPhoto({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.placeholderColor,
  });

  final String url;
  final BoxFit fit;
  final Color? placeholderColor;

  @override
  Widget build(BuildContext context) {
    // golden 测试环境（无平台通道）退回 Image.network，配合测试 HTTP 桩
    final inTest = Platform.environment.containsKey('FLUTTER_TEST');
    if (inTest) {
      return Image.network(url, fit: fit);
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      fadeInDuration: AppMotion.fast,
      placeholder: (_, _) =>
          Container(color: placeholderColor ?? AppColors.brand50),
      errorWidget: (_, _, _) => Container(
        decoration: const BoxDecoration(gradient: brandGradient),
        alignment: Alignment.center,
        child: const Icon(LucideIcons.user, size: 48, color: Colors.white70),
      ),
    );
  }
}

/// 推荐理由胶囊："都喜欢 徒步"——把推荐分变成用户看得懂的语言
class ReasonChip extends StatelessWidget {
  const ReasonChip({super.key, required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x66FF5A76),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white38, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.sparkles, size: 10, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            '都喜欢 $tag',
            style: const TextStyle(fontSize: 10.5, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// 超级喜欢按钮：金星，点击走会员权益链路
class SuperLikeButton extends StatelessWidget {
  const SuperLikeButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: const Icon(
            LucideIcons.star,
            size: 30,
            color: AppColors.svipGold,
            shadows: [Shadow(color: Color(0x66000000), blurRadius: 8)],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 骨架屏（Shimmer）——加载态不再转圈，用"内容形状呼吸"
// ============================================================

/// 基础骨架块：暖灰底 + 高光扫过
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.radius});

  final double? width;
  final double height;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.isDark
          ? const Color(0xFF322D2F)
          : const Color(0xFFEFE9E6),
      highlightColor: AppColors.isDark
          ? const Color(0xFF3F393B)
          : const Color(0xFFF8F4F2),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius ?? AppRadius.chip),
        ),
      ),
    );
  }
}

/// 骨架圆（头像占位）
class SkeletonCircle extends StatelessWidget {
  const SkeletonCircle({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(width: size, height: size, radius: 999);
  }
}

/// 发现页骨架：两列照片卡 × 4 行
class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var col = 0; col < 2; col++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: col == 1 ? 8 : 0,
                  right: col == 0 ? 8 : 0,
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < 3; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(
                              width: double.infinity,
                              height: (i + col) % 2 == 0 ? 210 : 180,
                            ),
                            const SizedBox(height: 8),
                            SkeletonBox(width: 110, height: 14),
                            const SizedBox(height: 6),
                            SkeletonBox(width: 80, height: 12),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 列表行骨架（消息/配对/黑名单通用）：头像 + 两行字
class ListRowSkeleton extends StatelessWidget {
  const ListRowSkeleton({super.key, this.rows = 6});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      child: Column(
        children: [
          for (var i = 0; i < rows; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                children: [
                  const SkeletonCircle(size: 54),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 120, height: 14),
                        const SizedBox(height: 8),
                        SkeletonBox(width: double.infinity, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 动态页骨架：发布者行 + 文案两行 + 大图块
class MomentsSkeleton extends StatelessWidget {
  const MomentsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      child: Column(
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SkeletonCircle(size: 44),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(width: 90, height: 13),
                            const SizedBox(height: 6),
                            SkeletonBox(width: 60, height: 11),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SkeletonBox(width: double.infinity, height: 13),
                    const SizedBox(height: 6),
                    SkeletonBox(width: 220, height: 13),
                    const SizedBox(height: 12),
                    SkeletonBox(width: double.infinity, height: 150),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 金卡流光：一道高光每 ~3.2s 斜向扫过（中国会员 UI 经典语言）
class SheenOverlay extends StatefulWidget {
  const SheenOverlay({super.key, required this.child, this.borderRadius});

  final Widget child;
  final double? borderRadius;

  @override
  State<SheenOverlay> createState() => _SheenOverlayState();
}

class _SheenOverlayState extends State<SheenOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(
        widget.borderRadius ?? AppRadius.card,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          // 高光带：从左上扫到右下，占周期前 55%，其余时间休眠
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              final x = -0.6 + t * 2.2; // 扫过区间
              return Transform.translate(
                offset: Offset(x * MediaQuery.of(context).size.width, 0),
                child: Transform.rotate(
                  angle: 0.35,
                  child: Opacity(
                    opacity: t < 0.55 ? 1 : 0,
                    child: Container(
                      width: 60,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x00FFFFFF),
                            Color(0x4DFFFFFF),
                            Color(0x00FFFFFF),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Tab 主列表滚动注册表：Dock 重复点击同一 Tab → 回到顶部
/// 一个 Tab 可注册多个控制器（如瀑布流左右两列）
class TabScrollRegistry {
  static final _controllers = <String, ScrollController>{};

  static ScrollController controllerFor(int tab, {int slot = 0}) =>
      _controllers.putIfAbsent('$tab-$slot', () => ScrollController());

  static void scrollToTop(int tab) {
    for (final c in _controllers.values) {
      if (c.hasClients) {
        c.animateTo(0, duration: AppMotion.slow, curve: AppMotion.easeOut);
      }
    }
  }
}
