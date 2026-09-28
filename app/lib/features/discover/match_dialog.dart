import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/api_client.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../shared/widgets.dart';

/// 配对成功弹窗：全产品最重要的 3 秒——暗场沉浸 + 发光标题 + 头像入场动画
/// [commonTags]/[icebreakers] 由后端配对时计算（设计 4.6），本地生成作为兜底
class MatchDialog extends StatefulWidget {
  const MatchDialog({
    super.key,
    required this.person,
    this.commonTags = const [],
    this.icebreakers = const [],
  });

  final PersonCard person;
  final List<String> commonTags;
  final List<String> icebreakers;

  @override
  State<MatchDialog> createState() => _MatchDialogState();
}

class _MatchDialogState extends State<MatchDialog>
    with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  late final Animation<double> _myScale = CurvedAnimation(
    parent: _enter,
    curve: const Interval(0.05, 0.5, curve: Curves.easeOutBack),
  );
  late final Animation<double> _peerScale = CurvedAnimation(
    parent: _enter,
    curve: const Interval(0.25, 0.7, curve: Curves.easeOutBack),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _enter,
    curve: const Interval(0.3, 1, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _enter.forward();
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.person;
    // 透明 Material：弹窗内 TextButton/InkWell 需要 Material 祖先
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          const Positioned.fill(child: _ConfettiOverlay()),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 顶部光晕 + 发光标题
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [AppColors.glowLight, Color(0x00C96F87)],
                        center: Alignment.topCenter,
                        radius: 0.9,
                      ),
                    ),
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => brandGradient
                              .createShader(Offset.zero & bounds.size),
                          child: Text(
                            '配对成功！',
                            style: TextStyle(
                              fontFamily: brandDisplayFont,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: AppColors.glowText,
                                  blurRadius: 24,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '你和 ${p.nickname} 互相喜欢',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  // 双头像 + 心形圆章，错帧入场
                  SizedBox(
                    width: 168,
                    height: 96,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          child: ScaleTransition(
                            scale: _myScale,
                            child: PersonAvatar(
                              url: ApiClient.myAvatar,
                              size: 96,
                              fallbackText: '我',
                            ),
                          ),
                        ),
                        Positioned(
                          left: 72,
                          child: ScaleTransition(
                            scale: _peerScale,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 4,
                                ),
                              ),
                              child: PersonAvatar(
                                url: p.photos.first,
                                size: 96,
                                fallbackText: p.nickname.characters.first,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 72,
                          top: 36,
                          child: ScaleTransition(
                            scale: _peerScale,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                gradient: brandGradient,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x80E8456F),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                LucideIcons.heart,
                                size: 13,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 共同点胶囊（后端配对时计算）
                  if (widget.commonTags.isNotEmpty)
                    FadeTransition(
                      opacity: _fade,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final t in widget.commonTags)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0x1FFFFFFF),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  t,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  // 破冰话题：点击直接发送并进入聊天（暗场下的白色 6% 容器）
                  FadeTransition(
                    opacity: _fade,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0x0FFFFFFF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '破冰话题 · 点击直接发送',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 4),
                          for (final ice in widget.icebreakers)
                            InkWell(
                              onTap: () => Navigator.pop(context, ice),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 5,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '· $ice',
                                        style: TextStyle(
                                          fontSize: 13,
                                          height: 1.5,
                                          color: Colors.white.withValues(
                                            alpha: 0.85,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      LucideIcons.arrowRight,
                                      size: 12,
                                      color: Colors.white.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeTransition(
                    opacity: _fade,
                    child: SizedBox(
                      width: double.infinity,
                      child: GradientButton(
                        onPressed: () => Navigator.pop(context, ''),
                        child: const Text('发消息'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FadeTransition(
                    opacity: _fade,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        '继续逛',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
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

/// 配对成功的全屏彩带（约 2.6s 后自然结束）：品牌色系纸屑
class _ConfettiOverlay extends StatefulWidget {
  const _ConfettiOverlay();

  @override
  State<_ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<_ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  static const _colors = [
    Color(0xFFFF8E7A), // 蜜桃
    Color(0xFFFF5A76), // 珊瑚
    Color(0xFFFFD3C2), // 浅杏
    Color(0xFFE0BE8C), // 香槟金
    Color(0xFFFFFFFF), // 白
  ];

  final _particles = List.generate(
    90,
    (i) => (
      x: (i * 0.618) % 1.0, // 黄金散布，避免聚团
      delay: (i % 7) * 0.035,
      size: 5.0 + (i % 5),
      speed: 0.55 + (i % 6) * 0.09,
      drift: ((i % 11) - 5) * 0.02,
      color: _colors[i % _colors.length],
    ),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _ConfettiPainter(_controller.value, _particles),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t, this.particles);

  final double t;
  final List<
    ({
      double x,
      double delay,
      double size,
      double speed,
      double drift,
      Color color,
    })
  >
  particles;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final local = (t - p.delay) / (1 - p.delay);
      if (local <= 0 || local > 1) continue;
      final px = (p.x + local * p.drift) * size.width;
      final py = local * local * p.speed * size.height * 1.25 - 40;
      if (py > size.height + 20) continue;
      final opacity = local < 0.75 ? 1 : (1 - local) / 0.25;
      final paint = Paint()..color = p.color.withValues(alpha: opacity * 0.95);
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(local * 6.28 * p.speed + p.x * 6.28);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 1.7,
          ),
          Radius.circular(p.size * 0.3),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
