import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../core/theme.dart';
import '../../core/ws_service.dart';
import '../../state/providers.dart';
import '../auth/login_page.dart';
import '../auth/onboarding_questions.dart';
import '../discover/discover_page.dart';
import '../matches/matches_page.dart';
import '../me/me_page.dart';
import '../messages/messages_page.dart';
import '../moments/moments_page.dart';
import '../shared/widgets.dart';

/// 每次运行只展示一次玩法引导（演示版用内存标志位）
bool _tourShown = false;

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  StreamSubscription<Map<String, dynamic>>? _wsSub;

  late final AnimationController _tabFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    value: 1,
  );

  static const _pages = [
    DiscoverPage(),
    MomentsPage(),
    MatchesPage(),
    MessagesPage(),
    MePage(),
  ];

  @override
  void initState() {
    super.initState();
    // 长连接帧路由：新消息→会话列表未读；配对→配对列表/喜欢我的人
    _wsSub = WsService.instance.frames.listen((frame) {
      if (!mounted) return;
      switch (frame['type']) {
        case 'message':
          ref.invalidate(conversationsProvider);
          ref.invalidate(notificationsUnreadProvider);
        case 'match':
          ref.invalidate(conversationsProvider);
          ref.invalidate(matchesProvider);
          ref.invalidate(likedMeProvider);
          ref.invalidate(notificationsUnreadProvider);
        default:
          break;
      }
    });
    // WS 连接管理与会员同步都是副作用，放这里而非 build（build 应保持纯函数）
    if (ApiClient.token != null) {
      // 会话恢复路径（重启免登录）也要同步会员状态，否则 VIP 重启后显示免费
      ref.read(membershipProvider.notifier).syncFromServer();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) WsService.instance.ensureConnected(ApiClient.token);
      });
    }
  }

  @override
  void dispose() {
    _tabFade.dispose();
    _wsSub?.cancel();
    super.dispose();
  }

  void _showTour() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _OnboardingSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 未登录先进登录页
    final authed = ref.watch(authedProvider);
    // 首次登录后的引导：未完成三问 → 问卷（必答）；完成后 → 玩法引导
    ref.listen(authedProvider, (prev, next) {
      if (prev == false && next == true && freshLogin) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          final info = ref.read(authInfoProvider);
          if (info != null && !info.onboarded) {
            await Navigator.of(context).push(
              AppPageRoute(
                builder: (_) => const OnboardingQuestionsPage(),
              ),
            );
          }
          if (mounted && !_tourShown) {
            _tourShown = true;
            _showTour();
          }
        });
      }
      // 登录/登出切换时管理长连接（副作用收口在监听里，不放 build 主体）
      if (prev != next) {
        if (next) {
          WsService.instance.ensureConnected(ApiClient.token);
          ref.read(membershipProvider.notifier).syncFromServer();
        } else {
          WsService.instance.close();
        }
      }
    });
    if (!authed) {
      return const LoginPage();
    }
    final unread = ref
        .watch(conversationsProvider)
        .maybeWhen(
          data: (list) => list.fold<int>(0, (sum, c) => sum + c.unread),
          orElse: () => 0,
        );

    return Scaffold(
      backgroundColor: AppColors.appBg,
      // 内容延伸到 Dock 底下，滚动时从悬浮胶囊后穿过
      extendBody: true,
      // 顶部 SafeArea 交给各页的 GradientPageHeader（渐变要一直铺到状态栏底下）
      body: Material(
        color: AppColors.appBg,
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.35, end: 1).animate(
            CurvedAnimation(parent: _tabFade, curve: Curves.easeOut),
          ),
          child: IndexedStack(index: _index, children: _pages),
        ),
      ),
      // 浮动胶囊 Dock：键盘弹出时自动收起（不顶在键盘上沿遮挡输入）
      bottomNavigationBar: AnimatedSlide(
        duration: AppMotion.fast,
        curve: AppMotion.easeOut,
        offset: MediaQuery.of(context).viewInsets.bottom > 0
            ? const Offset(0, 1.6)
            : Offset.zero,
        child: _FloatingDock(
          index: _index,
          unread: unread,
          onSelect: (i) {
        if (i == _index) {
          return;
        }
        setState(() => _index = i);
        _tabFade.forward(from: 0); // 切换淡入
        // 切「我的」Tab 时同步会员状态：管理端手动开通/取消即时生效
        if (i == 4) {
          ref.read(membershipProvider.notifier).syncFromServer();
        }
      },
        ),
      ),
    );
  }
}

/// 浮动胶囊底部导航（iOS 时代感件）：悬浮 + 毛玻璃 + 激活胶囊
class _FloatingDock extends StatelessWidget {
  const _FloatingDock({
    required this.index,
    required this.unread,
    required this.onSelect,
  });

  final int index;
  final int unread;
  final ValueChanged<int> onSelect;

  static const _items = [
    (LucideIcons.compass, LucideIcons.compass, '发现'),
    (LucideIcons.layers, LucideIcons.layers, '动态'),
    (LucideIcons.heart, LucideIcons.heart, '配对'),
    (LucideIcons.messageCircle, LucideIcons.messageCircle, '消息'),
    (LucideIcons.user, LucideIcons.user, '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.isDark
              ? const Color(0xEB232022)
              : const Color(0xE6FFFFFF),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: const Color(0x1A2A2225),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(child: _dockItem(i, i == 3 && unread > 0)),
          ],
        ),
      ),
    );
  }

  Widget _dockItem(int i, bool hasUnread) {
    final selected = index == i;
    final (outline, filled, label) = _items[i];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        // 重复点击当前 Tab：主列表回顶部（iOS 惯例）
        if (i == index) {
          TabScrollRegistry.scrollToTop(i);
          return;
        }
        onSelect(i);
      },
      child: AnimatedContainer(
        duration: AppMotion.normal,
        curve: AppMotion.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 14 : 6,
          vertical: selected ? 7 : 7,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    selected ? filled : outline,
                    size: 23,
                    color: selected ? brandColor : AppColors.textTertiary,
                  ),
                  if (hasUnread)
                    Positioned(
                      right: -3,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3.5,
                          vertical: 1,
                        ),
                        decoration: const BoxDecoration(
                          color: brandColor,
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                        ),
                        child: Text(
                          unread > 99 ? '99+' : '$unread',
                          style: const TextStyle(
                            fontSize: 8.5,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              // 激活时胶囊里带出文字，收起时只留图标
              AnimatedSize(
                duration: AppMotion.normal,
                curve: AppMotion.easeOut,
                alignment: Alignment.centerLeft,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 5),
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: brandColor,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 首次进入的三屏玩法引导（互相喜欢才能聊天是核心差异点）
class _OnboardingSheet extends StatefulWidget {
  const _OnboardingSheet();

  @override
  State<_OnboardingSheet> createState() => _OnboardingSheetState();
}

class _OnboardingSheetState extends State<_OnboardingSheet> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _slides = [
    (
      image: 'assets/images/guide_discover.png',
      title: '浏览附近的人',
      desc: '位置优先排序，打开就是离你最近的心动',
    ),
    (
      image: 'assets/images/guide_match.png',
      title: '互相喜欢即配对',
      desc: '喜欢是双向的，彼此心动才会配对',
    ),
    (
      image: 'assets/images/guide_chat.png',
      title: '配对后免费开聊',
      desc: '破冰话题帮你开口，第一句不再尴尬',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(
              height: 300,
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      _slides[i].image,
                      width: 210,
                      height: 210,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _slides[i].title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _slides[i].desc,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _page ? brandColor : AppColors.divider,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_page == _slides.length - 1 ? '开始发现' : '下一步'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '跳过',
                style: TextStyle(color: AppColors.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
