import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api.dart';
import '../api/api_client.dart';
import '../core/tracker.dart';
import '../models/models.dart';

/// 登录态（登录后置 true）
final authedProvider = StateProvider<bool>((ref) => ApiClient.token != null);

/// 登录用户基础信息
class AuthInfo {
  const AuthInfo({
    required this.userId,
    required this.nickname,
    this.onboarded = true,
  });

  final int userId;
  final String nickname;

  /// 是否已完成引导三问（性别/想看谁/出生年份）
  final bool onboarded;

  AuthInfo copyWith({String? nickname, bool? onboarded}) => AuthInfo(
    userId: userId,
    nickname: nickname ?? this.nickname,
    onboarded: onboarded ?? this.onboarded,
  );
}

final authInfoProvider = StateProvider<AuthInfo?>(
  (ref) => ApiClient.myId == null
      ? null
      : AuthInfo(
          userId: ApiClient.myId!,
          nickname: ApiClient.myNickname ?? '我',
          onboarded: ApiClient.onboarded,
        ),
);

/// 我的资料原文（后端 /profile/me；登录/编辑资料后更新）
final myProfileProvider = StateProvider<Map<String, dynamic>?>(
  (ref) => ApiClient.myProfile,
);

/// 我的兴趣标签（共同点计算用）
List<String> myTags(Map<String, dynamic>? profile) {
  final raw = profile?['tags'];
  if (raw is List) return raw.map((e) => e.toString()).toList();
  if (raw is String && raw.isNotEmpty) {
    try {
      // dart:convert 延迟导入开销可忽略，直接解码
      return (jsonDecode(raw) as List).map((e) => e.toString()).toList();
    } catch (_) {}
  }
  return const [];
}

/// 便捷读取：当前登录用户的兴趣标签
List<String> myTagsOf(WidgetRef ref) => myTags(ref.read(myProfileProvider));

/// 发现页：展示形态（瀑布流/列表）
final viewModeProvider = StateProvider<ViewMode>((ref) => ViewMode.waterfall);

/// 发现页：排序方式（位置优先/推荐优先/最近活跃）
final sortModeProvider = StateProvider<SortMode>((ref) => SortMode.distance);

/// 发现页：当前筛选城市（登录后由我的城市覆盖）
final cityProvider = StateProvider<String>((ref) => '杭州');

/// 当前定位城市
final locatedCityProvider = StateProvider<String>((ref) => '杭州');

/// 发现页：搜索关键词（对已加载信息流做本地过滤：昵称/城市/职业/简介/标签）
final searchQueryProvider = StateProvider<String>((ref) => '');

/// 发现页筛选（设计 4.3 免费权益）：年龄区间 + 距离上限（0=不限）
final ageMinProvider = StateProvider<int>((ref) => 20);
final ageMaxProvider = StateProvider<int>((ref) => 32);
final maxDistProvider = StateProvider<int>((ref) => 0);

/// 权益筛选（设计 4.8）：只看已认证（VIP）/ 学历与职业（SVIP）
final verifiedOnlyProvider = StateProvider<bool>((ref) => false);
final educationFilterProvider = StateProvider<String>((ref) => '');
final occupationFilterProvider = StateProvider<String>((ref) => '');

/// 已喜欢/已隐藏的用户集合（本地即时反馈；服务端同步过滤隐藏）
final likedUsersProvider = StateProvider<Set<int>>((ref) => {});
final hiddenUsersProvider = StateProvider<Set<int>>((ref) => {});

/// 信息流分页状态
class FeedPagerState {
  const FeedPagerState({
    this.items = const [],
    this.nextCursor = -1,
    this.loading = false,
    this.refreshing = false,
    this.error,
  });

  final List<FeedEntry> items;

  /// -1 = 没有更多
  final int nextCursor;
  final bool loading;
  final bool refreshing;
  final String? error;
}

/// 信息流分页器：城市/排序/筛选变化自动回到第一页，触底加载下一页（游标，设计 9.3）
class FeedPager extends StateNotifier<FeedPagerState> {
  Timer? _searchDebounce;

  FeedPager(this._ref) : super(const FeedPagerState(refreshing: true)) {
    _ref.listen<String>(cityProvider, (_, _) => reload());
    _ref.listen<SortMode>(sortModeProvider, (_, _) => reload());
    _ref.listen<int>(ageMinProvider, (_, _) => reload());
    _ref.listen<int>(ageMaxProvider, (_, _) => reload());
    _ref.listen<int>(maxDistProvider, (_, _) => reload());
    _ref.listen<bool>(verifiedOnlyProvider, (_, _) => reload());
    _ref.listen<String>(educationFilterProvider, (_, _) => reload());
    _ref.listen<String>(occupationFilterProvider, (_, _) => reload());
    // 搜索关键词 300ms 防抖后服务端查询
    _ref.listen<String>(searchQueryProvider, (_, next) {
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 300), reload);
    });
    reload();
  }

  final Ref _ref;
  static const _pageSize = 20;

  /// 请求序号：筛选快速变化时旧响应后到直接丢弃，防止旧数据覆盖新筛选
  int _seq = 0;

  Future<void> reload() async {
    final seq = ++_seq;
    state = FeedPagerState(refreshing: true, items: state.items);
    try {
      final page = await _fetch(cursor: 0);
      if (seq != _seq || !mounted) return;
      state = FeedPagerState(items: page.items, nextCursor: page.nextCursor);
    } on ApiException catch (e) {
      if (seq != _seq || !mounted) return;
      state = FeedPagerState(error: e.msg);
    } catch (_) {
      if (seq != _seq || !mounted) return;
      state = const FeedPagerState(error: '加载失败，请检查后端服务');
    }
  }

  Future<void> loadMore() async {
    if (state.loading || state.refreshing || state.nextCursor < 0) return;
    final seq = _seq;
    state = FeedPagerState(
      items: state.items,
      nextCursor: state.nextCursor,
      loading: true,
    );
    try {
      final page = await _fetch(cursor: state.nextCursor);
      if (seq != _seq || !mounted) return;
      // 去重合并（隐藏/拉黑可能在翻页间生效）
      final seen = state.items.map((e) => e.person.id).toSet();
      final merged = [...state.items];
      for (final e in page.items) {
        if (seen.add(e.person.id)) merged.add(e);
      }
      state = FeedPagerState(items: merged, nextCursor: page.nextCursor);
    } on ApiException catch (e) {
      if (seq != _seq || !mounted) return;
      state = FeedPagerState(
        items: state.items,
        nextCursor: state.nextCursor,
        error: e.msg,
      );
    } catch (_) {
      if (seq != _seq || !mounted) return;
      state = FeedPagerState(
        items: state.items,
        nextCursor: state.nextCursor,
        error: '加载更多失败',
      );
    }
  }

  Future<FeedPage> _fetch({required int cursor}) {
    return Api.feed(
      city: _ref.read(cityProvider),
      sort: switch (_ref.read(sortModeProvider)) {
        SortMode.active => 'active',
        SortMode.recommend => 'reco', // 推荐分：距离/兴趣/活跃/Elo（后端 RecommendService）
        _ => 'distance',
      },
      ageMin: _ref.read(ageMinProvider),
      ageMax: _ref.read(ageMaxProvider),
      maxDist: _ref.read(maxDistProvider),
      q: _ref.read(searchQueryProvider),
      verifiedOnly: _ref.read(verifiedOnlyProvider),
      education: _ref.read(educationFilterProvider),
      occupation: _ref.read(occupationFilterProvider),
      limit: _pageSize,
      cursor: cursor,
    );
  }
}

final feedProvider = StateNotifierProvider<FeedPager, FeedPagerState>(
  (ref) => FeedPager(ref),
);

/// 会员状态详情（含今日剩余喜欢次数，顶栏 ❤ 计数用；会员态变化自动刷新）
final memberStatusDetailProvider = FutureProvider<MembershipStateLite>((ref) {
  ref.watch(membershipProvider);
  return Api.memberStatus();
});

/// 会话列表（后端 /conversations）
final conversationsProvider = FutureProvider<List<Conversation>>(
  (ref) => Api.conversations(),
);

/// 互相配对列表（后端 /discover/matches）
final matchesProvider = FutureProvider<List<FeedEntry>>((ref) => Api.matches());

/// 喜欢我的人（后端 /likes/me；会员状态变化后自动重算——付费解锁完整列表）
final likedMeProvider = FutureProvider<LikedMeData>((ref) async {
  ref.watch(membershipProvider);
  return Api.likedMe();
});

/// 黑名单（后端 /blocks）
final blacklistProvider = FutureProvider<List<PersonCard>>(
  (ref) => Api.blocks(),
);

/// 动态流（后端 /moments，按距离排序）
final momentsProvider = FutureProvider<List<ApiMoment>>((ref) {
  final city = ref.watch(cityProvider);
  return Api.moments(city: city);
});

/// 会员状态（登录后从后端同步，支付成功后本地更新）
class MembershipState {
  const MembershipState({this.tier = MemberTier.none, this.expireAt});

  final MemberTier tier;
  final DateTime? expireAt;

  bool get isMember => tier != MemberTier.none;
}

class MembershipNotifier extends StateNotifier<MembershipState> {
  MembershipNotifier() : super(const MembershipState());

  Future<void> syncFromServer() async {
    try {
      final s = await Api.memberStatus();
      if (mounted) {
        state = MembershipState(tier: s.tier, expireAt: s.expireAt);
      }
    } catch (_) {
      // 后端不可用时保持免费态，不打断使用
    }
  }

  void activate(MemberTier tier, DateTime? expireAt) {
    state = MembershipState(tier: tier, expireAt: expireAt);
  }

  /// 登出时重置为免费态
  void reset() {
    state = const MembershipState();
  }
}

final membershipProvider =
    StateNotifierProvider<MembershipNotifier, MembershipState>(
      (ref) => MembershipNotifier(),
    );

/// 会员商品（后端 /member/products，价格后台配置）
final memberProductsProvider = FutureProvider<List<MemberProduct>>(
  (ref) => Api.memberProducts(),
);

/// 喜欢动作的结果
enum LikeResult { liked, matched, alreadyLiked, processing, quotaExceeded }

/// 喜欢动作的完整结果（配对时携带后端计算的共同点与破冰话术）
class LikeOutcome {
  const LikeOutcome(
    this.result, {
    this.commonTags = const [],
    this.icebreakers = const [],
  });

  final LikeResult result;
  final List<String> commonTags;
  final List<String> icebreakers;
}

/// 社交动作封装（对接后端 /likes /matches）
class DiscoverActions {
  /// 点赞在途集合：双击/连点防重（同一人请求未返回前不重复发）
  static final _pendingLikes = <int>{};

  static Future<LikeOutcome> like(
    WidgetRef ref,
    PersonCard p, {
    bool superLike = false,
  }) async {
    if (ref.read(likedUsersProvider).contains(p.id)) {
      return const LikeOutcome(LikeResult.alreadyLiked);
    }
    if (_pendingLikes.contains(p.id)) {
      return const LikeOutcome(LikeResult.processing);
    }
    _pendingLikes.add(p.id);
    try {
      final r = await Api.like(p.id, action: superLike ? 3 : 1);
      Tracker.log('card_like', {'toUser': p.id});
      ref.read(likedUsersProvider.notifier).state = {
        ...ref.read(likedUsersProvider),
        p.id,
      };
      // 点赞消耗配额，顶栏 ❤ 计数刷新
      ref.invalidate(memberStatusDetailProvider);
      if (r['matched'] == true) {
        // 后端已建配对+会话，刷新会话列表让消息 Tab 留痕
        ref.invalidate(conversationsProvider);
        Tracker.log('match_success', {'peer': p.id});
        return LikeOutcome(
          LikeResult.matched,
          commonTags: _strList(r['commonTags']),
          icebreakers: _strList(r['icebreakers']),
        );
      }
      return const LikeOutcome(LikeResult.liked);
    } on ApiException catch (e) {
      if (e.code == 4001) {
        // 配额耗尽同步刷新计数
        ref.invalidate(memberStatusDetailProvider);
        return const LikeOutcome(LikeResult.quotaExceeded);
      }
      rethrow;
    } finally {
      _pendingLikes.remove(p.id);
    }
  }

  static List<String> _strList(dynamic raw) =>
      raw is List ? raw.map((e) => e.toString()).toList() : const <String>[];

  static void hide(WidgetRef ref, int personId) {
    ref.read(hiddenUsersProvider.notifier).state = {
      ...ref.read(hiddenUsersProvider),
      personId,
    };
    Tracker.log('card_hide', {'toUser': personId});
    // 服务端记录隐藏（action=2），失败不影响本地体验
    Api.like(personId, action: 2).then<void>((_) {}).catchError((_) {});
  }

  static Future<void> unmatch(WidgetRef ref, int matchId) async {
    await Api.unmatch(matchId);
    ref.invalidate(conversationsProvider);
    ref.invalidate(matchesProvider);
  }
}

/// 登出统一收口：清会话 + 重置全部用户级状态（防止换账号后串号）
/// 调用方随后把 authedProvider 置 false 即可
Future<void> logout(WidgetRef ref) async {
  await ApiClient.clearSession();
  ref.read(authInfoProvider.notifier).state = null;
  ref.read(myProfileProvider.notifier).state = null;
  ref.read(likedUsersProvider.notifier).state = {};
  ref.read(hiddenUsersProvider.notifier).state = {};
  ref.invalidate(conversationsProvider);
  ref.invalidate(matchesProvider);
  ref.invalidate(likedMeProvider);
  ref.invalidate(blacklistProvider);
  ref.invalidate(momentsProvider);
  ref.invalidate(memberStatusDetailProvider);
  ref.invalidate(memberProductsProvider);
  ref.read(membershipProvider.notifier).reset();
}

/// 通知未读数（发现页铃铛角标）
final notificationsUnreadProvider = FutureProvider<int>((ref) async {
  final d = await Api.notifications();
  return (d['unread'] as num?)?.toInt() ?? 0;
});

/// 发现页广告（position=feed）
final feedAdsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) => Api.ads('feed'));
