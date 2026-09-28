import 'dart:convert';

import '../models/models.dart';

import 'package:dio/dio.dart';

import 'api_client.dart';

/// 后端用户详情（含配对锁与动态）
class UserDetail {
  const UserDetail({
    required this.user,
    required this.photoUrls,
    required this.moments,
    required this.matched,
    required this.distanceKm,
    this.socialShowcase = const [],
  });

  final PersonCard user;
  final List<String> photoUrls;
  final List<Moment> moments;
  final bool matched;
  final double distanceKm;

  /// 对方的社交账号展示（对方持有有效社交展示卡时下发）
  final List<Map<String, String>> socialShowcase;
}

/// 动态流条目（后端口径：计数以服务端为准）
class ApiMoment {
  const ApiMoment({
    required this.momentId,
    required this.moment,
    required this.author,
    this.distanceKm,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
  });

  final int momentId;
  final Moment moment;
  final PersonCard author;
  final double? distanceKm;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
}

/// 后端接口封装（与设计文档第 9 章一致）
abstract final class Api {
  // ---------- 映射工具 ----------

  /// 图片消息等后端下发的 /files/** 相对路径 → 完整 URL
  static String fileUrl(String path) {
    if (path.startsWith('http')) return path;
    final origin = ApiClient.baseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '');
    return '$origin$path';
  }

  static List<String> _decodePhotos(dynamic raw) {
    if (raw is String) {
      try {
        return (jsonDecode(raw) as List).map((e) => e.toString()).toList();
      } catch (_) {
        return const [];
      }
    }
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
  }

  static List<String> _decodeTags(dynamic raw) {
    if (raw is String && raw.isNotEmpty) {
      try {
        return (jsonDecode(raw) as List).map((e) => e.toString()).toList();
      } catch (_) {
        return const [];
      }
    }
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
  }

  /// 会话列表时间：今天 HH:mm / 昨天 / 周X / MM-DD
  static String _chatTime(dynamic iso) {
    if (iso == null) return '';
    final t = DateTime.tryParse(iso.toString());
    if (t == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    if (diff == 1) return '昨天';
    if (diff < 7) return '周${'一二三四五六日'[t.weekday - 1]}';
    return '${t.month}/${t.day}';
  }

  static String _timeAgo(dynamic iso) {
    if (iso == null) return '刚刚';
    final t = DateTime.tryParse(iso.toString());
    if (t == null) return '刚刚';
    final minutes = DateTime.now().difference(t).inMinutes;
    if (minutes < 1) return '刚刚';
    if (minutes < 60) return '$minutes分钟前';
    if (minutes < 24 * 60) return '${minutes ~/ 60}小时前';
    return '${minutes ~/ (24 * 60)}天前';
  }

  static MemberTier _tier(int v) => switch (v) {
    1 => MemberTier.vip,
    2 => MemberTier.svip,
    _ => MemberTier.none,
  };

  static IncomeRange? _income(dynamic raw) => switch (raw?.toString()) {
    'below5' => IncomeRange.below5,
    'w5to10' => IncomeRange.w5to10,
    'w10to20' => IncomeRange.w10to20,
    'w20to50' => IncomeRange.w20to50,
    'above50' => IncomeRange.above50,
    _ => null,
  };

  /// 后端 UserCardVO / 用户详情 user 节点 → PersonCard
  static PersonCard personFromJson(
    Map<String, dynamic> j, {
    String? fallbackPhoto,
  }) {
    return PersonCard(
      id: (j['id'] as num).toInt(),
      nickname: j['nickname']?.toString() ?? '',
      gender: (j['gender'] as num?)?.toInt() == 1 ? Gender.male : Gender.female,
      age: (j['age'] as num?)?.toInt() ?? 0,
      city: j['city']?.toString() ?? '',
      photos: [j['avatarUrl']?.toString() ?? fallbackPhoto ?? ''],
      heightCm: (j['heightCm'] as num?)?.toInt() ?? 0,
      education: j['education']?.toString() ?? '',
      occupation: j['occupation']?.toString() ?? '',
      income: _income(j['income']),
      bio: j['bio']?.toString() ?? '',
      tags: _decodeTags(j['tags']),
      verified: (j['verified'] as num?)?.toInt() == 1,
      memberTier: _tier((j['memberTier'] as num?)?.toInt() ?? 0),
      wechat: j['wechat']?.toString(),
      instagram: j['instagram']?.toString(),
      facebook: j['facebook']?.toString(),
      lastActiveMinutes: (j['lastActiveMinutes'] as num?)?.toInt() ?? 999,
    );
  }

  static Moment momentFromJson(Map<String, dynamic> j) => Moment(
    photos: _decodePhotos(j['photos']),
    caption: j['caption']?.toString() ?? '',
    timeLabel: _timeAgo(j['createdAt']),
    likes: (j['likesBase'] as num?)?.toInt() ?? 0,
  );

  // ---------- 认证 ----------

  static Future<Map<String, dynamic>> login(String phone, String code) async {
    final d = await ApiClient.unwrap(
      ApiClient.dio.post('/auth/login', data: {'phone': phone, 'code': code}),
    );
    ApiClient.token = d['token']?.toString();
    ApiClient.myId = (d['userId'] as num?)?.toInt();
    ApiClient.onboarded = d['onboarded'] == true;
    return d;
  }

  /// 发送验证码（演示环境固定 123456，后端不做真实下发）
  static Future<void> smsCode(String phone) => ApiClient.unwrap(
    ApiClient.dio.post('/auth/sms-code', data: {'phone': phone}),
  );

  /// 注销账号（7 天冷静期，设计 6.4）
  static Future<void> deactivate() =>
      ApiClient.unwrap(ApiClient.dio.post('/auth/deactivate'));

  static Future<Map<String, dynamic>> myProfile() async {
    final d = await ApiClient.unwrap(ApiClient.dio.get('/profile/me'));
    return ApiClient.mapOf(d['user']);
  }

  static Future<void> onboarding({
    required int gender,
    required int preferGender,
    required int birthYear,
    required String city,
  }) async {
    await ApiClient.unwrap(
      ApiClient.dio.post(
        '/auth/onboarding',
        data: {
          'gender': gender,
          'preferGender': preferGender,
          'birthYear': birthYear,
          'city': city,
        },
      ),
    );
  }

  // ---------- 发现 / 用户 ----------

  /// 发现页信息流（游标分页 + 年龄/距离筛选，设计 9.3）
  static Future<FeedPage> feed({
    String? city,
    String sort = 'distance',
    int ageMin = 20,
    int ageMax = 32,
    int maxDist = 0,
    String q = '',
    bool verifiedOnly = false,
    String? education,
    String? occupation,
    int limit = 20,
    int cursor = 0,
  }) async {
    final d = await ApiClient.unwrap(
      ApiClient.dio.get(
        '/discover/feed',
        queryParameters: {
          if (city != null && city.isNotEmpty) 'city': city,
          'sort': sort,
          'ageMin': ageMin,
          'ageMax': ageMax,
          'maxDist': maxDist,
          if (q.isNotEmpty) 'q': q,
          if (verifiedOnly) 'verifiedOnly': true,
          if (education != null && education.isNotEmpty) 'education': education,
          if (occupation != null && occupation.isNotEmpty) 'occupation': occupation,
          'limit': limit,
          'cursor': cursor,
        },
      ),
    );
    return FeedPage(
      items: ApiClient.listOf(d['items'])
          .map(
            (j) => FeedEntry(
              person: personFromJson(j),
              distanceKm: (j['distanceKm'] as num?)?.toDouble(),
              remote: false,
            ),
          )
          .toList(),
      nextCursor: (d['nextCursor'] as num?)?.toInt() ?? -1,
    );
  }

  static Future<UserDetail> userDetail(int userId) async {
    final d = await ApiClient.unwrap(ApiClient.dio.get('/users/$userId'));
    final userJson = ApiClient.mapOf(d['user']);
    final photos = ApiClient.listOf(d['photos']);
    final photoUrls = photos.map((p) => p['url']?.toString() ?? '').toList();
    final moments = ApiClient.listOf(d['moments']).map(momentFromJson).toList();
    return UserDetail(
      user: personFromJson(
        userJson,
        fallbackPhoto: photoUrls.isNotEmpty ? photoUrls.first : null,
      ),
      photoUrls: photoUrls,
      moments: moments,
      matched: d['matched'] == true,
      distanceKm: (d['distanceKm'] as num?)?.toDouble() ?? 0,
      socialShowcase: ApiClient.listOf(d['socialShowcase'])
          .map((j) => Map<String, String>.from(j))
          .toList(),
    );
  }

  static Future<List<FeedEntry>> matches() async {
    final list = await ApiClient.unwrapList(
      ApiClient.dio.get('/discover/matches'),
    );
    return list
        .map(
          (j) => FeedEntry(
            person: personFromJson(j),
            distanceKm: (j['distanceKm'] as num?)?.toDouble(),
          ),
        )
        .toList();
  }

  // ---------- 喜欢 / 社交 ----------

  /// 返回 {matched, matchId?, commonTags[], icebreakers[], already?, hidden?}；
  /// 配额用尽抛 ApiException(4001)
  static Future<Map<String, dynamic>> like(int toUser, {int action = 1}) {
    return ApiClient.unwrap(
      ApiClient.dio.post('/likes', data: {'toUser': toUser, 'action': action}),
    );
  }

  /// 喜欢我的人：非会员 blurred=true（头像模糊墙），会员完整列表
  static Future<LikedMeData> likedMe() async {
    final d = await ApiClient.unwrap(ApiClient.dio.get('/likes/me'));
    return LikedMeData(
      blurred: d['blurred'] == true,
      items: ApiClient.listOf(d['items'])
          .map(
            (j) => FeedEntry(
              person: personFromJson(j),
              distanceKm: (j['distanceKm'] as num?)?.toDouble(),
            ),
          )
          .toList(),
    );
  }

  /// 反悔：返回 {undone, undoRemaining}；免费用户抛 ApiException(4003)
  static Future<Map<String, dynamic>> undoLike(int toUser) =>
      ApiClient.unwrap(ApiClient.dio.delete('/likes/$toUser'));

  /// 文件上传（演示环境后端本地存储，返回可直接访问的 URL）
  static Future<String> uploadFile(String filePath) async {
    final d = await ApiClient.unwrap(
      ApiClient.dio.post(
        '/upload',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(filePath),
        }),
      ),
    );
    return d['url']?.toString() ?? '';
  }

  /// 登记资料照片（isAvatar=true 时同步为头像）
  static Future<void> addPhoto(String url, {bool isAvatar = false}) =>
      ApiClient.unwrap(
        ApiClient.dio.post(
          '/profile/photos',
          data: {'url': url, 'isAvatar': isAvatar},
        ),
      );

  static Future<void> setAvatarPhoto(int photoId) => ApiClient.unwrap(
    ApiClient.dio.put('/profile/photos/$photoId', data: {'isAvatar': true}),
  );

  static Future<void> deletePhoto(int photoId) =>
      ApiClient.unwrap(ApiClient.dio.delete('/profile/photos/$photoId'));

  static Future<void> unmatch(int matchId) =>
      ApiClient.unwrap(ApiClient.dio.post('/matches/$matchId/unmatch'));

  /// 提交举报（类目见设计 6.3：1虚假 2诈骗 3骚扰 4色情 5未成年 6其他）
  static Future<void> report(
    int reportedUser,
    int category,
    String description,
  ) => ApiClient.unwrap(
    ApiClient.dio.post(
      '/reports',
      data: {
        'reportedUser': reportedUser,
        'category': category,
        'description': description,
      },
    ),
  );

  static Future<void> block(int blockedUser) => ApiClient.unwrap(
    ApiClient.dio.post('/blocks', data: {'blockedUser': blockedUser}),
  );

  static Future<void> unblock(int blockedUser) =>
      ApiClient.unwrap(ApiClient.dio.delete('/blocks/$blockedUser'));

  /// 黑名单（含昵称/头像，管理页展示用）
  static Future<List<PersonCard>> blocks() async {
    final list = await ApiClient.unwrapList(ApiClient.dio.get('/blocks'));
    return list.map(personFromJson).toList();
  }

  /// 更新资料（后端为全量更新，需先合并我的资料再提交）
  static Future<void> updateProfile(Map<String, dynamic> fields) =>
      ApiClient.unwrap(ApiClient.dio.put('/profile/me', data: fields));

  /// 上报 GPS 定位：后端更新坐标并反解最近城市（演示环境无逆地理服务）
  static Future<String> reportLocation(double lat, double lng) async {
    final d = await ApiClient.unwrap(
      ApiClient.dio.post('/profile/location', data: {'lat': lat, 'lng': lng}),
    );
    return d['city']?.toString() ?? '';
  }

  // ---------- 聊天 ----------

  static Future<List<Conversation>> conversations() async {
    final list = await ApiClient.unwrapList(
      ApiClient.dio.get('/conversations'),
    );
    return list.map((j) {
      final c = Conversation(
        personId: (j['peerId'] as num).toInt(),
        lastMessage: j['lastMessage']?.toString() ?? '',
        lastTime: _chatTime(j['updatedAt']),
        unread: (j['unread'] as num?)?.toInt() ?? 0,
        matchId: (j['matchId'] as num?)?.toInt(),
        convId: (j['id'] as num?)?.toInt(),
      );
      c
        ..peerNickname = j['peerNickname']?.toString()
        ..peerAvatarUrl = j['peerAvatarUrl']?.toString()
        ..peerGender = (j['peerGender'] as num?)?.toInt()
        ..peerVerified = (j['peerVerified'] as num?)?.toInt();
      return c;
    }).toList();
  }

  static Future<List<ChatMessage>> messages(int convId, {int myId = 0}) async {
    final list = await ApiClient.unwrapList(
      ApiClient.dio.get('/conversations/$convId/messages'),
    );
    return list
        .map(
          (j) => ChatMessage(
            fromMe: (j['fromUser'] as num?)?.toInt() == myId,
            text: j['content']?.toString() ?? '',
            type: (j['type'] as num?)?.toInt() ?? 1,
            time: DateTime.tryParse(j['createdAt']?.toString() ?? ''),
            serverId: (j['id'] as num?)?.toInt(),
          ),
        )
        .toList();
  }

  static Future<void> sendMessage(int convId, String content, {int type = 1}) =>
      ApiClient.unwrap(
        ApiClient.dio.post(
          '/conversations/$convId/messages',
          data: {'content': content, 'type': type},
        ),
      );

  /// AI 回复建议：{replies: [...], source: llm|fallback}；超次数抛 ApiException(4002)
  static Future<AiReplySuggestion> aiReply(int convId) async {
    final d = await ApiClient.unwrap(
      ApiClient.dio.post('/conversations/$convId/ai-reply'),
    );
    final raw = d['replies'];
    return AiReplySuggestion(
      replies: raw is List ? raw.map((e) => e.toString()).toList() : const [],
      source: d['source']?.toString() ?? 'fallback',
    );
  }

  // ---------- 动态 ----------

  static Future<List<ApiMoment>> moments({String? city, int limit = 50}) async {
    final list = await ApiClient.unwrapList(
      ApiClient.dio.get(
        '/moments',
        queryParameters: {
          if (city != null && city.isNotEmpty) 'city': city,
          'limit': limit,
        },
      ),
    );
    return list
        .map(
          (j) => ApiMoment(
            momentId: (j['id'] as num).toInt(),
            moment: momentFromJson(j),
            author: personFromJson(j),
            distanceKm: (j['distanceKm'] as num?)?.toDouble(),
            likeCount: (j['likeCount'] as num?)?.toInt() ?? 0,
            commentCount: (j['commentCount'] as num?)?.toInt() ?? 0,
            likedByMe: j['likedByMe'] == true,
          ),
        )
        .toList();
  }

  static Future<bool> toggleMomentLike(int momentId) async {
    final d = await ApiClient.unwrap(
      ApiClient.dio.post('/moments/$momentId/like'),
    );
    return d['liked'] == true;
  }

  static Future<List<MomentComment>> momentComments(int momentId) async {
    final list = await ApiClient.unwrapList(
      ApiClient.dio.get('/moments/$momentId/comments'),
    );
    return list
        .map(
          (j) => MomentComment(
            author: j['author']?.toString() ?? '',
            text: j['content']?.toString() ?? '',
            timeLabel: _timeAgo(j['createdAt']),
          ),
        )
        .toList();
  }

  static Future<void> addMomentComment(int momentId, String content) =>
      ApiClient.unwrap(
        ApiClient.dio.post(
          '/moments/$momentId/comments',
          data: {'content': content},
        ),
      );

  /// 发布动态（照片须先经 uploadFile 上传为 /files/ 路径）
  static Future<void> publishMoment(String caption, List<String> photos) =>
      ApiClient.unwrap(
        ApiClient.dio.post(
          '/moments',
          data: {'caption': caption, 'photos': photos},
        ),
      );

  /// 已读回执：标记会话内对方消息为已读
  static Future<void> markRead(int convId) =>
      ApiClient.unwrap(ApiClient.dio.post('/conversations/$convId/read'));

  // ---------- 通知中心 / 广告 / 社交展示卡 ----------

  /// 通知列表（含未读数）
  static Future<Map<String, dynamic>> notifications() => ApiClient.unwrap(
        ApiClient.dio.get('/notifications'),
      );

  static Future<void> readAllNotifications() => ApiClient.unwrap(
        ApiClient.dio.post('/notifications/read-all'),
      );

  /// 按位置拉取在投广告（发现页横幅）
  static Future<List<Map<String, dynamic>>> ads(String position) =>
      ApiClient.unwrapList(
        ApiClient.dio.get('/ads', queryParameters: {'position': position}),
      );

  /// 我的社交展示配置 + 订阅状态
  static Future<Map<String, dynamic>> socialShowcase() => ApiClient.unwrap(
        ApiClient.dio.get('/social-showcase'),
      );

  static Future<List<Map<String, dynamic>>> saveSocialShowcase(
          List<Map<String, String>> items) =>
      ApiClient.unwrap(
        ApiClient.dio.put('/social-showcase', data: {'items': items}),
      ).then((d) => ApiClient.listOf(d['items']));

  /// 购买社交展示卡（月订）：取 tier=3 商品直接下单支付
  static Future<bool> buySocialShowcase() async {
    final products = await memberProducts();
    final plan = products.where((p) => p.tierRaw == 3).toList();
    if (plan.isEmpty) return false;
    final orderNo = await createOrder(plan.first.id, channel: 1);
    await payOrder(orderNo);
    return true;
  }

  /// 真人认证（演示：上传自拍照即自动通过）
  static Future<void> verify(String photo) => ApiClient.unwrap(
    ApiClient.dio.post('/profile/verify', data: {'photo': photo}),
  );

  // ---------- 会员 ----------

  static Future<List<MemberProduct>> memberProducts() async {
    final list = await ApiClient.unwrapList(
      ApiClient.dio.get('/member/products'),
    );
    return list
        .map(
          (j) => MemberProduct(
            id: (j['id'] as num?)?.toInt() ?? 0,
            tier: _tier((j['tier'] as num?)?.toInt() ?? 1),
            tierRaw: (j['tier'] as num?)?.toInt() ?? 0,
            durationDays: (j['durationDays'] as num?)?.toInt() ?? 30,
            priceCents: (j['priceCents'] as num?)?.toInt() ?? 0,
            originalCents: (j['originalCents'] as num?)?.toInt(),
            firstPriceCents: (j['firstPriceCents'] as num?)?.toInt(),
            badge: j['badge']?.toString(),
          ),
        )
        .toList();
  }

  static Future<MembershipStateLite> memberStatus() async {
    final d = await ApiClient.unwrap(ApiClient.dio.get('/member/status'));
    return MembershipStateLite(
      tier: _tier((d['tier'] as num?)?.toInt() ?? 0),
      expireAt: d['expireAt'] != null
          ? DateTime.tryParse(d['expireAt'].toString())
          : null,
      likesRemaining: (d['likesRemaining'] as num?)?.toInt() ?? -1,
    );
  }

  static Future<String> createOrder(int productId, {int channel = 1}) async {
    final d = await ApiClient.unwrap(
      ApiClient.dio.post(
        '/member/orders',
        data: {'productId': productId, 'channel': channel},
      ),
    );
    return d['orderNo']?.toString() ?? '';
  }

  static Future<Map<String, dynamic>> payOrder(String orderNo) =>
      ApiClient.unwrap(ApiClient.dio.post('/member/orders/$orderNo/pay'));
}

/// 会员状态（后端口径）
class MembershipStateLite {
  const MembershipStateLite({
    required this.tier,
    this.expireAt,
    this.likesRemaining = -1,
  });

  final MemberTier tier;
  final DateTime? expireAt;

  /// 今日剩余喜欢次数，-1 表示无限（会员）
  final int likesRemaining;
}

/// 发现页一屏（游标分页）
class FeedPage {
  const FeedPage({required this.items, required this.nextCursor});

  final List<FeedEntry> items;

  /// -1 表示没有更多
  final int nextCursor;

  bool get hasMore => nextCursor >= 0;
}

/// "喜欢我的人"数据（blurred=免费用户模糊墙）
class LikedMeData {
  const LikedMeData({required this.blurred, required this.items});

  final bool blurred;
  final List<FeedEntry> items;
}

/// AI 回复建议（source: llm=大模型生成 / fallback=未接入时的本地模板）
class AiReplySuggestion {
  const AiReplySuggestion({required this.replies, required this.source});

  final List<String> replies;
  final String source;
}
