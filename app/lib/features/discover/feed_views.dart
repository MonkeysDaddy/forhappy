import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/providers.dart';
import '../shared/widgets.dart';
import 'discover_actions.dart';
import 'user_detail_page.dart';

/// ============================================================
/// 发现页卡片（v3 · Photo First）：
/// 瀑布流——图片即卡片，信息以浮层压在渐变 scrim 上；
/// 错落宽高比制造节奏，按压缩放 + 入场渐入上浮。
/// ============================================================

/// 瀑布流：双列错落卡片
class WaterfallView extends StatelessWidget {
  const WaterfallView({
    super.key,
    required this.entries,
    this.leftController,
    this.rightController,
  });

  final List<FeedEntry> entries;
  final ScrollController? leftController;
  final ScrollController? rightController;

  /// 懒加载双列：左右各一条 ListView（卡片等高 3:4，交替均分不塌列），
  /// 只构建可见卡片；入场动画只给首屏（index < 20），翻页新卡不重播。
  @override
  Widget build(BuildContext context) {
    final left = <FeedEntry>[];
    final right = <FeedEntry>[];
    for (var i = 0; i < entries.length; i++) {
      (i.isEven ? left : right).add(entries[i]);
    }
    Widget column(List<FeedEntry> list, bool isLeft) {
      return Expanded(
        child: ListView.builder(
          controller: isLeft ? leftController : rightController,
          padding: EdgeInsets.only(
              left: isLeft ? 0 : 5, right: isLeft ? 5 : 0, top: 4, bottom: 110),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final globalIndex = isLeft ? i * 2 : i * 2 + 1;
            return _WaterfallCard(
              entry: list[i],
              index: globalIndex,
              animate: globalIndex < 20,
            );
          },
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        column(left, true),
        column(right, false),
      ],
    );
  }
}

/// 统一宽高比：所有卡片等大（3:4），照片 BoxFit.cover 自适应裁切
double _aspectFor(int index) => 3 / 4;

class _WaterfallCard extends ConsumerStatefulWidget {
  const _WaterfallCard({
    required this.entry,
    required this.index,
    this.animate = true,
  });

  final FeedEntry entry;
  final int index;

  /// 是否播放入场动画（首屏 true；翻页新卡 false 不重播）
  final bool animate;

  @override
  ConsumerState<_WaterfallCard> createState() => _WaterfallCardState();
}

class _WaterfallCardState extends ConsumerState<_WaterfallCard> {
  /// 推荐理由：兴趣交集的第一个标签（让推荐分"可解释"）
  String? get _reasonTag {
    final tags = widget.entry.person.tags;
    if (tags.isEmpty) return null;
    final myTags = myTagsOf(ref);
    for (final t in tags) {
      if (myTags.contains(t)) return t;
    }
    return null;
  }

  bool _pressed = false;

  void _open() {
    Navigator.push(
      context,
      AppPageRoute(
        builder: (_) => UserDetailPage(
          personId: widget.entry.person.id,
          seed: widget.entry.person,
          distanceKm: widget.entry.distanceKm,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.entry.person;
    final liked = ref.watch(likedUsersProvider).contains(p.id);
    // 入场：渐入上浮（首屏播一次；翻页新卡直接呈现不重播）
    final card = GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: _open,
        child: AnimatedScale(
          scale: _pressed ? 0.965 : 1,
          duration: AppMotion.fast,
          curve: AppMotion.easeOut,
          child: AnimatedContainer(
            duration: AppMotion.normal,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: _pressed ? AppShadows.card : AppShadows.md,
              border: AppColors.isDark
                  ? Border.all(color: Colors.white.withValues(alpha: 0.09))
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: AspectRatio(
                aspectRatio: _aspectFor(widget.index),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedPhoto(url: p.photos.first),
                    // 底部信息 scrim：更深、起点更低，文字如悬浮在照片上
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment(0, -0.35),
                          colors: [
                            Color(0xC21A1216),
                            Color(0x661A1216),
                            Color(0x001A1216),
                          ],
                          stops: [0, 0.42, 0.75],
                        ),
                      ),
                    ),
                    // 顶部轻压暗：保证徽章可读
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment(0, 0.4),
                          colors: [Color(0x40000000), Color(0x00000000)],
                        ),
                      ),
                    ),
                    // 认证 / 会员 / 微信标识：右上角收敛为一组
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (p.verified) ...[
                            const VerifiedBadge(size: 20),
                            if (p.memberTier != MemberTier.none || p.hasWechat)
                              const SizedBox(width: 4),
                          ],
                          if (p.memberTier != MemberTier.none) ...[
                            MemberBadge(tier: p.memberTier),
                            if (p.hasWechat) const SizedBox(width: 4),
                          ],
                          if (p.hasWechat) const WeChatFlag(),
                        ],
                      ),
                    ),
                    // 左下：距离 + 推荐理由（兴趣交集时展示"懂我"的理由）
                    Positioned(
                      left: 10,
                      bottom: 12,
                      child: Row(
                        children: [
                          DistanceChip(text: entryDistance(widget.entry)),
                          if (_reasonTag != null) ...[
                            const SizedBox(width: 6),
                            Flexible(child: ReasonChip(tag: _reasonTag!)),
                          ],
                        ],
                      ),
                    ),
                    // 右下：喜欢 + 超级喜欢（毛玻璃圆钮）
                    Positioned(
                      right: 6,
                      bottom: 8,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(
                              child: SuperLikeButton(
                                onTap: () => performLike(
                                  context,
                                  ref,
                                  p,
                                  superLike: true,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(
                              child: LikeButton(
                                size: 32,
                                glass: true,
                                liked: liked,
                                onTap: () => performLike(context, ref, p),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 底部信息浮层：昵称·年龄 + 一行职业
                    Positioned(
                      left: 12,
                      right: 52,
                      bottom: 48,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '${p.nickname}，${p.age}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                    shadows: [
                                      Shadow(
                                        color: Color(0x66000000),
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              GenderIcon(gender: p.gender, size: 12),
                              const SizedBox(width: 5),
                              OnlineDot(lastActiveMinutes: p.lastActiveMinutes, compact: true),
                            ],
                          ),
                          if (p.occupation.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${p.city} · ${p.occupation}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.white.withValues(alpha: 0.82),
                                shadows: const [
                                  Shadow(
                                    color: Color(0x66000000),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    );
    // 入场：渐入上浮 + 右列错帧（首屏播一次；翻页新卡直接呈现不重播）
    if (!widget.animate) return card;
    final delay = widget.index.isOdd ? 0.18 : 0.0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.slow + Duration(milliseconds: (delay * 400).round()),
      curve: AppMotion.easeOut,
      builder: (context, raw, child) {
        // 错帧：把动画时间轴右移，右列延迟起播
        final t =
            ((raw - delay) / (1 - delay)).clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 14),
            child: child,
          ),
        );
      },
      child: card,
    );
  }
}

String entryDistance(FeedEntry e) => e.distanceLabel;

/// 列表：单列大卡片，信息更全（简介 + 标签）——v3 精修版
class CardListView extends ConsumerWidget {
  const CardListView({super.key, required this.entries, this.controller});

  final List<FeedEntry> entries;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 110),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _ListCard(entry: entries[i]),
    );
  }
}

class _ListCard extends ConsumerStatefulWidget {
  const _ListCard({required this.entry});

  final FeedEntry entry;

  @override
  ConsumerState<_ListCard> createState() => _ListCardState();
}

class _ListCardState extends ConsumerState<_ListCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.entry.person;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () => Navigator.push(
        context,
        AppPageRoute(
          builder: (_) => UserDetailPage(
            personId: p.id,
            seed: p,
            distanceKm: widget.entry.distanceKm,
          ),
        ),
      ),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: AppMotion.fast,
        curve: AppMotion.easeOut,
        child: Container(
          decoration: cardDecoration(),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头图：圆角随主题，与卡片形成"圆中圆"层次
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 98,
                  height: 132,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedPhoto(url: p.photos.first),
                      // 图上在线状态：一眼可见的"活跃感"
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: OnlineDot(
                          lastActiveMinutes: p.lastActiveMinutes,
                        ),
                      ),
                    ],
                  ),
                ),
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
                            '${p.nickname}，${p.age}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        GenderIcon(gender: p.gender, size: 14),
                        if (p.verified) ...[
                          const SizedBox(width: 4),
                          const VerifiedBadge(size: 17),
                        ],
                        if (p.memberTier != MemberTier.none) ...[
                          const SizedBox(width: 5),
                          MemberBadge(tier: p.memberTier, fontSize: 10),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          LucideIcons.mapPin,
                          size: 13,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            '${p.city} · ${widget.entry.distanceLabel}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                        if (p.hasWechat) const WeChatFlag(),
                      ],
                    ),
                    if (p.bio.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        p.bio,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (p.tags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: p.tags
                            .take(3)
                            .map((t) => TagChip(t))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 2),
              Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: LikeButton(
                      liked: ref.watch(likedUsersProvider).contains(p.id),
                      onTap: () => performLike(context, ref, p),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 探探式滑动卡片：右滑喜欢（配对弹窗照常弹出）、左滑跳过
/// 与瀑布流/列表并列的第三种浏览形态（手势是中国用户的肌肉记忆）
class SwipeCardView extends ConsumerStatefulWidget {
  const SwipeCardView({super.key, required this.entries});

  final List<FeedEntry> entries;

  @override
  ConsumerState<SwipeCardView> createState() => _SwipeCardViewState();
}

class _SwipeCardViewState extends ConsumerState<SwipeCardView> {
  int _top = 0; // 当前卡顶（已处理的卡片逻辑下移）
  Offset _drag = Offset.zero;
  bool _locked = false; // 动画执行中禁止再次拖动

  static const _threshold = 110.0;

  void _onDragEnd(FeedEntry entry) {
    if (_locked) return;
    final dx = _drag.dx;
    if (dx > _threshold) {
      _flyOut(entry, Offset(600, 0), like: true);
    } else if (dx < -_threshold) {
      _flyOut(entry, Offset(-600, 0), like: false);
    } else {
      setState(() => _drag = Offset.zero);
    }
  }

  /// 飞出动画完整播放后（240ms）才切换到下一张：期间 _locked 冻结手势。
  /// 左滑隐藏会把卡片从列表剔除（父级过滤），因此不推进 _top；右滑列表不变需 _top++。
  void _flyOut(FeedEntry entry, Offset target, {required bool like}) {
    _locked = true;
    setState(() => _drag = target);
    if (like) {
      HapticFeedback.mediumImpact();
      performLike(context, ref, entry.person);
    }
    Future.delayed(const Duration(milliseconds: 240), () {
      if (mounted) {
        setState(() {
          _drag = Offset.zero;
          if (like) {
            _top++;
          } else {
            DiscoverActions.hide(ref, entry.person.id);
          }
          _locked = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.entries.skip(_top).take(3).toList();
    if (visible.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/guide_match.png',
              width: 150,
              height: 150,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 8),
            Text(
              '这批都看完啦，换批推荐再来看',
              style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ref.invalidate(feedProvider),
              child: const Text('刷新推荐'),
            ),
          ],
        ),
      );
    }
    // 底下垫的卡片依次缩小（从第 1 张开始；顶层卡由下方手势层渲染）
    final cards = <Widget>[];
    for (var i = visible.length - 1; i >= 1; i--) {
      final scale = 1 - i * 0.04;
      final top = i * 10.0;
      cards.add(
        Positioned(
          left: 24,
          right: 24,
          top: 20 + top,
          bottom: 120,
          child: Transform.scale(
            scale: scale,
            child: IgnorePointer(
              ignoring: i > 0,
              child: _SwipeCard(entry: visible[i]),
            ),
          ),
        ),
      );
    }
    // 顶层卡片接管手势
    final topEntry = visible.first;
    cards.add(
      Positioned(
        left: 24,
        right: 24,
        top: 20,
        bottom: 0,
        child: GestureDetector(
          onPanUpdate: _locked ? null : (d) => setState(() => _drag += d.delta),
          onPanEnd: _locked ? null : (_) => _onDragEnd(topEntry),
          child: Transform.translate(
            offset: _drag,
            child: Transform.rotate(
              angle: _drag.dx / 1200,
              child: _SwipeCard(entry: topEntry, isTop: true),
            ),
          ),
        ),
      ),
    );
    return Stack(children: cards);
  }
}

class _SwipeCard extends ConsumerWidget {
  const _SwipeCard({required this.entry, this.isTop = false});

  final FeedEntry entry;
  final bool isTop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = entry.person;
    final liked = ref.watch(likedUsersProvider).contains(p.id);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.lg,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedPhoto(url: p.photos.first),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              top: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      AppColors.photoScrim.withValues(alpha: 0.7),
                      AppColors.photoScrim.withValues(alpha: 0),
                    ],
                    stops: [0, 0.55],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.age > 0 ? '${p.nickname}，${p.age}' : p.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (p.city.isNotEmpty) p.city,
                      if (p.occupation.isNotEmpty) p.occupation,
                    ].join(' · '),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      DistanceChip(text: entryDistance(entry)),
                      const Spacer(),
                      if (liked)
                        const Icon(
                          LucideIcons.heart,
                          size: 22,
                          color: AppColors.svipGold,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
