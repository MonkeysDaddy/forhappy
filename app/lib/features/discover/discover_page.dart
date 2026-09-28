import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dicts.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/providers.dart';
import '../member/checkout_page.dart';
import '../shared/widgets.dart';
import '../me/notifications_page.dart';
import 'city_sheet.dart';
import 'feed_views.dart';

/// Tab1 发现：人员卡片瀑布流/列表（可切换），位置排序，城市/年龄/距离筛选，搜索，游标分页
class DiscoverPage extends ConsumerWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewMode = ref.watch(viewModeProvider);
    final feedState = ref.watch(feedProvider);
    final hidden = ref.watch(hiddenUsersProvider);
    final query = ref.watch(searchQueryProvider).trim();
    final searching = query.isNotEmpty;

    // 搜索走服务端（searchQueryProvider 300ms 防抖 → feed reload），
    // 不再对已加载条目做本地过滤
    final items = feedState.items
        .where((e) => !hidden.contains(e.person.id))
        .toList();

    final loadingFirst =
        feedState.refreshing && items.isEmpty && feedState.error == null;

    return Column(
      children: [
        const _TopBar(),
        if (!searching) const _ControlsRow(),
        if (!searching) const _FeedAdBanner(),
        if (searching)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Row(
              children: [
                Icon(LucideIcons.search, size: 14, color: Colors.black38),
                const SizedBox(width: 4),
                Text(
                  '为你找到 ${items.length} 位相关用户（已加载范围）',
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ],
            ),
          ),
        Expanded(
          child: loadingFirst
              ? const FeedSkeleton()
              : feedState.error != null && items.isEmpty
              ? _FeedError(
                  message: feedState.error!,
                  onRetry: () => ref.read(feedProvider.notifier).reload(),
                )
              : RefreshIndicator(
                  color: brandColor,
                  backgroundColor: AppColors.surface,
                  displacement: 28,
                  onRefresh: () => ref.read(feedProvider.notifier).reload(),
                  // 触底前预加载下一页（设计 4.3）
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n.metrics.extentAfter < 300 &&
                          feedState.error == null) {
                        ref.read(feedProvider.notifier).loadMore();
                      }
                      return false;
                    },
                    child: items.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(
                                height: 480,
                                child: _EmptyState(
                                  query: searching ? query : null,
                                ),
                              ),
                            ],
                          )
                        : viewMode == ViewMode.swipe
                        ? SwipeCardView(entries: items)
                        : viewMode == ViewMode.waterfall
                        ? WaterfallView(
                            entries: items,
                            leftController:
                                TabScrollRegistry.controllerFor(0),
                            rightController:
                                TabScrollRegistry.controllerFor(0, slot: 1),
                          )
                        : CardListView(
                            entries: items,
                            controller: TabScrollRegistry.controllerFor(0),
                          ),
                  ),
                ),
        ),
        // 分页状态条：loading 转圈 / 失败可重试（不再恒显示转圈）
        if (!searching &&
            items.isNotEmpty &&
            feedState.nextCursor >= 0 &&
            feedState.loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: brandColor,
                ),
              ),
            ),
          )
        else if (!searching &&
            items.isNotEmpty &&
            feedState.nextCursor >= 0 &&
            feedState.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: GestureDetector(
                onTap: () => ref.read(feedProvider.notifier).loadMore(),
                child: Text(
                  '${feedState.error} · 点按重试',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ),
          )
        else if (!searching && items.length >= 20 && feedState.nextCursor < 0)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              '没有更多了',
              style: TextStyle(fontSize: 11.5, color: Colors.black26),
            ),
          ),
      ],
    );
  }
}

/// 顶栏：品牌 logo + 搜索 + 定位/城市选择
class _TopBar extends ConsumerStatefulWidget {
  const _TopBar();

  @override
  ConsumerState<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends ConsumerState<_TopBar> {
  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    // 输入变化即时重建，保证清除按钮随输入出现
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _closeSearch() {
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).state = '';
    setState(() => _searching = false);
  }

  @override
  Widget build(BuildContext context) {
    final city = ref.watch(cityProvider);
    final located = ref.watch(locatedCityProvider);

    if (_searching) {
      final topInset = MediaQuery.of(context).padding.top;
      return Padding(
        padding: EdgeInsets.fromLTRB(12, topInset + 12, 16, 2),
        child: Row(
          children: [
            IconButton(
              onPressed: _closeSearch,
              icon: const Icon(LucideIcons.arrowLeft, size: 22),
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (v) =>
                    ref.read(searchQueryProvider.notifier).state = v,
                decoration: InputDecoration(
                  hintText: '搜索昵称 / 城市 / 职业 / 标签',
                  hintStyle: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    LucideIcons.search,
                    size: 20,
                    color: AppColors.textTertiary,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            ref.read(searchQueryProvider.notifier).state = '';
                          },
                          icon: Icon(
                            LucideIcons.circleX,
                            size: 18,
                            color: AppColors.textTertiary,
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GradientPageHeader(
      bottom: 12,
      child: Row(
        children: [
          const Text(
            'ForHappy',
            style: TextStyle(
              fontFamily: brandDisplayFont,
              fontSize: 27,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          Stack(
            children: [
              IconButton(
                onPressed: () async {
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const NotificationsPage()));
                  ref.invalidate(notificationsUnreadProvider);
                },
                icon: const Icon(LucideIcons.bell, size: 22, color: Colors.white),
                tooltip: '通知',
              ),
              Consumer(builder: (context, ref, _) {
                final unread = ref.watch(notificationsUnreadProvider).valueOrNull ?? 0;
                if (unread == 0) return const SizedBox.shrink();
                return Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    constraints:
                        const BoxConstraints(minWidth: 14, minHeight: 14),
                    child: Text('$unread',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 8.5,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            color: brandColor)),
                  ),
                );
              }),
            ],
          ),
          IconButton(
            onPressed: () => setState(() => _searching = true),
            icon: const Icon(LucideIcons.search, size: 23, color: Colors.white),
            tooltip: '搜索',
          ),
          const SizedBox(width: 2),
          ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Material(
                color: const Color(0x33FFFFFF),
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => Navigator.push(
                    context,
                    AppPageRoute(builder: (_) => const CitySelectPage()),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          city == located
                              ? LucideIcons.locateFixed
                              : LucideIcons.mapPin,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          city,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const Icon(
                          LucideIcons.chevronDown,
                          size: 18,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 排序切换 + 筛选 + 瀑布流/列表切换（喜欢配额由后端管控，4001 触发付费墙）
class _ControlsRow extends ConsumerWidget {
  const _ControlsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(sortModeProvider);
    final viewMode = ref.watch(viewModeProvider);
    final ageMin = ref.watch(ageMinProvider);
    final ageMax = ref.watch(ageMaxProvider);
    final maxDist = ref.watch(maxDistProvider);
    final filterActive = ageMin != 20 || ageMax != 32 || maxDist != 0;
    // 今日剩余喜欢次数（会员 -1 = 无限）
    final quota = ref.watch(memberStatusDetailProvider).valueOrNull;
    final remaining = quota?.likesRemaining ?? -1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          // 分段式排序控件：整组一体、滑动指示（v3，替代散点 ChoiceChip）
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.fill,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  for (final mode in SortMode.values)
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            ref.read(sortModeProvider.notifier).state = mode,
                        child: AnimatedContainer(
                          duration: AppMotion.normal,
                          curve: AppMotion.easeOut,
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: sort == mode
                                ? AppColors.surface
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: sort == mode ? AppShadows.sm : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            mode.label,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: sort == mode
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: sort == mode
                                  ? brandColor
                                  : AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 剩余喜欢配额（设计 4.3：免费 30/日）
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.heart,
                  size: 13,
                  color: remaining == 0
                      ? Colors.black26
                      : brandColor.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 3),
                Text(
                  remaining < 0 ? '∞' : '$remaining',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: remaining == 0
                        ? Colors.black26
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 筛选（年龄/距离，免费权益）
          GestureDetector(
            onTap: () => _openFilterSheet(context, ref),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: filterActive
                    ? brandColor.withValues(alpha: 0.12)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(
                LucideIcons.slidersHorizontal,
                size: 18,
                color: filterActive ? brandColor : AppColors.textTertiary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(999),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                _viewToggle(
                  icon: LucideIcons.layoutGrid,
                  selected: viewMode == ViewMode.waterfall,
                  onTap: () => ref.read(viewModeProvider.notifier).state =
                      ViewMode.waterfall,
                ),
                _viewToggle(
                  icon: LucideIcons.layers,
                  selected: viewMode == ViewMode.swipe,
                  onTap: () => ref.read(viewModeProvider.notifier).state =
                      ViewMode.swipe,
                ),
                _viewToggle(
                  icon: LucideIcons.rows2,
                  selected: viewMode == ViewMode.list,
                  onTap: () =>
                      ref.read(viewModeProvider.notifier).state = ViewMode.list,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openFilterSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _FilterSheet(),
    );
  }

  Widget _viewToggle({
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? brandColor.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(
          icon,
          size: 18,
          color: selected ? brandColor : AppColors.textTertiary,
        ),
      ),
    );
  }
}

/// 发现页广告横幅（管理后台投放，position=feed；无广告时不占位）
class _FeedAdBanner extends ConsumerWidget {
  const _FeedAdBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adsAsync = ref.watch(feedAdsProvider);
    final ad = adsAsync.valueOrNull?.firstOrNull;
    if (ad == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: GestureDetector(
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(ad['title']?.toString() ?? '广告'),
            content: Text(ad['content']?.toString() ?? ''),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: SizedBox(
            height: 72,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedPhoto(url: ad['imageUrl']?.toString() ?? ''),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0x991A1216),
                        const Color(0x001A1216),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
                Positioned(left: 14, top: 0, bottom: 0,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ad['title']?.toString() ?? '',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(ad['content']?.toString() ?? '',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.85))),
                    ],
                  ),
                ),
                const Positioned(
                  right: 6,
                  top: 4,
                  child: Text('广告',
                      style: TextStyle(fontSize: 9, color: Colors.white60)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 筛选弹层：年龄区间 + 距离上限（变更即时生效，重置回默认 20-32 / 不限）
class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  /// 拖动中的本地预览值（避免每个 tick 触发 feed reload）
  final _draftAgeMin = ValueNotifier<int?>(null);
  final _draftAgeMax = ValueNotifier<int?>(null);
  final _draftDist = ValueNotifier<int?>(null);
  bool _draftVerifiedOnly = false;
  String? _draftEducation;
  String? _draftOccupation;

  @override
  void initState() {
    super.initState();
    _draftVerifiedOnly = ref.read(verifiedOnlyProvider);
    _draftEducation = ref.read(educationFilterProvider);
    _draftOccupation = ref.read(occupationFilterProvider);
  }

  @override
  void dispose() {
    _draftAgeMin.dispose();
    _draftAgeMax.dispose();
    _draftDist.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membership = ref.watch(membershipProvider);
    final ageMin = ref.watch(ageMinProvider);
    final ageMax = ref.watch(ageMaxProvider);
    final maxDist = ref.watch(maxDistProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.slidersHorizontal,
                  size: 20,
                  color: brandColor,
                ),
                const SizedBox(width: 8),
                const Text(
                  '筛选',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    ref.read(ageMinProvider.notifier).state = 20;
                    ref.read(ageMaxProvider.notifier).state = 32;
                    ref.read(maxDistProvider.notifier).state = 0;
                    setState(() {
                      _draftAgeMin.value = null;
                      _draftAgeMax.value = null;
                      _draftDist.value = null;
                      _draftVerifiedOnly = false;
                      _draftEducation = null;
                      _draftOccupation = null;
                    });
                  },
                  child: Text('重置',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _sliderSection(
              title: '年龄区间',
              valueLabel: '$ageMin - $ageMax 岁',
              child: Column(
                children: [
                  _labeledSlider(
                    label: '最小 ${_draftAgeMin.value ?? ageMin} 岁',
                    value: (_draftAgeMin.value ?? ageMin).toDouble(),
                    min: 18,
                    max: 60,
                    onChanged: (v) => setState(
                      () =>
                          _draftAgeMin.value = v.round().clamp(18, ageMax - 1),
                    ),
                    onChangeEnd: (v) =>
                        ref.read(ageMinProvider.notifier).state = v
                            .round()
                            .clamp(18, ageMax - 1),
                  ),
                  _labeledSlider(
                    label: '最大 ${_draftAgeMax.value ?? ageMax} 岁',
                    value: (_draftAgeMax.value ?? ageMax).toDouble(),
                    min: 19,
                    max: 60,
                    onChanged: (v) => setState(
                      () =>
                          _draftAgeMax.value = v.round().clamp(ageMin + 1, 60),
                    ),
                    onChangeEnd: (v) =>
                        ref.read(ageMaxProvider.notifier).state = v
                            .round()
                            .clamp(ageMin + 1, 60),
                  ),
                ],
              ),
            ),
            // 权益筛选（设计 4.8）：只看已认证（VIP）
            _sliderSection(
              title: '权益筛选',
              valueLabel: membership.isMember
                  ? (membership.tier == MemberTier.svip ? 'SVIP' : 'VIP')
                  : '未开通',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (!membership.isMember) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('只看已认证是会员权益，正在为你开通…')),
                        );
                        Navigator.push(
                          context,
                          AppPageRoute(
                            builder: (_) => const CheckoutPage(
                                initialTier: MemberTier.vip),
                          ),
                        );
                        return;
                      }
                      setState(() =>
                          _draftVerifiedOnly = !_draftVerifiedOnly);
                      ref.read(verifiedOnlyProvider.notifier).state =
                          _draftVerifiedOnly;
                    },
                    child: Row(
                      children: [
                        Icon(
                          _draftVerifiedOnly
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 20,
                          color: _draftVerifiedOnly
                              ? brandColor
                              : AppColors.textTertiary,
                        ),
                        const SizedBox(width: 8),
                        const Text('只看已认证用户',
                            style: TextStyle(fontSize: 13)),
                        const Spacer(),
                        if (!membership.isMember)
                          const Text('VIP',
                              style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.svipGold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _filterDropdown(
                          hint: '学历（SVIP）',
                          value: _draftEducation,
                          locked: membership.tier != MemberTier.svip,
                          options: educationOptions,
                          onChanged: (v) {
                            setState(() => _draftEducation = v);
                            ref.read(educationFilterProvider.notifier).state =
                                v ?? '';
                          },
                          onLockedTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              AppPageRoute(
                                builder: (_) => const CheckoutPage(
                                    initialTier: MemberTier.svip),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _filterDropdown(
                          hint: '职业（SVIP）',
                          value: _draftOccupation,
                          locked: membership.tier != MemberTier.svip,
                          options: occupationPresets,
                          onChanged: (v) {
                            setState(() => _draftOccupation = v);
                            ref.read(occupationFilterProvider.notifier).state =
                                v ?? '';
                          },
                          onLockedTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              AppPageRoute(
                                builder: (_) => const CheckoutPage(
                                    initialTier: MemberTier.svip),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _sliderSection(
              title: '距离上限',
              valueLabel: maxDist == 0 ? '不限' : '$maxDist km 内',
              child: _labeledSlider(
                label: (_draftDist.value ?? maxDist) == 0
                    ? '不限'
                    : '${_draftDist.value ?? maxDist} km',
                value: (_draftDist.value ?? maxDist).toDouble(),
                min: 0,
                max: 100,
                divisions: 20,
                onChanged: (v) => setState(() => _draftDist.value = v.round()),
                onChangeEnd: (v) =>
                    ref.read(maxDistProvider.notifier).state = v.round(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('完成'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sliderSection({
    required String title,
    required String valueLabel,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                valueLabel,
                style: const TextStyle(
                  fontSize: 13,
                  color: brandColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }

  /// 高级筛选下拉（SVIP 权益）：锁定态点击 → 付费引导
  Widget _filterDropdown({
    required String hint,
    required String? value,
    required bool locked,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    required VoidCallback onLockedTap,
  }) {
    return GestureDetector(
      onTap: locked ? onLockedTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: locked ? AppColors.fill : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(
            color: locked ? AppColors.divider : brandColor.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: locked
                  ? Text('$hint 🔒',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textTertiary))
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: (value == null || value.isEmpty) ? null : value,
                        isExpanded: true,
                        hint: Text(hint,
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary)),
                        items: [
                          for (final o in options)
                            DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 12.5))),
                        ],
                        onChanged: onChanged,
                      ),
                    ),
            ),
            if (value != null && value.isNotEmpty && !locked)
              GestureDetector(
                onTap: () => onChanged(null),
                child: Icon(LucideIcons.x, size: 13, color: AppColors.textTertiary),
              ),
          ],
        ),
      ),
    );
  }

  Widget _labeledSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required ValueChanged<double> onChanged,
    ValueChanged<double>? onChangeEnd,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: Colors.black45),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: brandColor,
              inactiveTrackColor: AppColors.divider,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState({this.query});

  /// 非空 = 搜索无结果
  final String? query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final city = ref.watch(cityProvider);
    if (query != null) {
      return EmptyState(
        icon: LucideIcons.searchX,
        title: '未找到与「$query」相关的用户',
        subtitle: '换个关键词，或切换城市试试',
        actionLabel: '清除搜索',
        onAction: () => ref.read(searchQueryProvider.notifier).state = '',
      );
    }
    return EmptyState(
      icon: LucideIcons.userSearch,
      title: '$city暂时没有符合筛选的人',
      subtitle: '放宽筛选，或看看推荐排序',
      actionLabel: '试试推荐排序',
      onAction: () =>
          ref.read(sortModeProvider.notifier).state = SortMode.recommend,
    );
  }
}

/// 后端不可用/请求失败时的重试视图
class _FeedError extends StatelessWidget {
  const _FeedError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: LucideIcons.cloudOff,
      title: message,
      subtitle: '检查后端服务后下拉或点重试',
      actionLabel: '重试',
      onAction: onRetry,
    );
  }
}
