enum Gender { male, female }

/// 年收入区间（真实工程由用户填写后按区间展示）
enum IncomeRange { below5, w5to10, w10to20, w20to50, above50 }

extension IncomeRangeLabel on IncomeRange {
  String get label => switch (this) {
    IncomeRange.below5 => '5万以下',
    IncomeRange.w5to10 => '5-10万',
    IncomeRange.w10to20 => '10-20万',
    IncomeRange.w20to50 => '20-50万',
    IncomeRange.above50 => '50万以上',
  };
}

/// 用户动态（图文）
class Moment {
  const Moment({
    required this.photos,
    this.caption = '',
    required this.timeLabel,
    this.likes = 0,
  });

  final List<String> photos;
  final String caption;
  final String timeLabel; // "2小时前" / "3天前"
  final int likes;
}

/// 动态评论
class MomentComment {
  const MomentComment({
    required this.author,
    required this.text,
    this.timeLabel = '刚刚',
  });

  final String author;
  final String text;
  final String timeLabel;
}

enum ViewMode { waterfall, list, swipe }

enum SortMode { distance, recommend, active }

extension SortModeLabel on SortMode {
  String get label => switch (this) {
    SortMode.distance => '距离优先',
    SortMode.recommend => '推荐优先',
    SortMode.active => '最近活跃',
  };
}

enum MemberTier { none, vip, svip }

extension MemberTierLabel on MemberTier {
  String get label => switch (this) {
    MemberTier.none => '免费用户',
    MemberTier.vip => 'VIP',
    MemberTier.svip => 'SVIP',
  };
}

/// 人员卡片（发现信息流的一条数据）
class PersonCard {
  const PersonCard({
    required this.id,
    required this.nickname,
    required this.gender,
    required this.age,
    required this.city,
    required this.photos,
    this.heightCm = 165,
    this.education = '本科',
    this.occupation = '',
    this.bio = '',
    this.tags = const [],
    this.verified = false,
    this.likesYou = false,
    this.lastActiveMinutes = 30,
    this.memberTier = MemberTier.none,
    this.wechat,
    this.instagram,
    this.facebook,
    this.weightKg,
    this.income,
    this.moments = const [],
  });

  final int id;
  final String nickname;
  final Gender gender;
  final int age;
  final String city;
  final List<String> photos;
  final int heightCm;
  final String education;
  final String occupation;
  final String bio;
  final List<String> tags;

  /// mock：是否完成真人认证
  final bool verified;

  /// mock：对方是否已喜欢我（用于模拟配对命中与"喜欢我的人"墙）
  final bool likesYou;

  /// 最后活跃距今分钟数（"最近活跃"排序用）
  final int lastActiveMinutes;

  /// 对方自身的会员档位（卡片展示用）
  final MemberTier memberTier;

  /// 联系方式（为空 = 未填写；卡片上仅展示"是否有微信号"）
  final String? wechat;
  final String? instagram;
  final String? facebook;

  /// 体重（kg，可未填写）
  final int? weightKg;

  /// 年收入区间
  final IncomeRange? income;

  /// 个人动态（图文）
  final List<Moment> moments;

  bool get hasWechat => wechat != null && wechat!.isNotEmpty;
}

/// 信息流条目 = 人员卡片 + 按当前城市计算出的距离
/// [remote] = 浏览城市 ≠ 我的定位城市（距离语义为"距市中心"）
class FeedEntry {
  const FeedEntry({
    required this.person,
    required this.distanceKm,
    this.remote = false,
  });

  final PersonCard person;
  final double? distanceKm;
  final bool remote;

  String get distanceText {
    final d = distanceKm;
    if (d == null) return '距离隐藏';
    if (d < 1) return '${(d * 1000).round()}m';
    return '${d.toStringAsFixed(1)}km';
  }

  String get distanceLabel => remote ? '距市中心 $distanceText' : distanceText;
}

/// 会话（消息 Tab；peer 字段由后端会话接口下发）
class Conversation {
  Conversation({
    required this.personId,
    required this.lastMessage,
    required this.lastTime,
    this.unread = 0,
    this.matchId,
    this.convId,
  });

  final int personId;
  final String lastMessage;
  final String lastTime;
  final int unread;
  final int? matchId;
  final int? convId;

  // 对方信息（列表/聊天页展示用）
  String? peerNickname;
  String? peerAvatarUrl;
  int? peerGender;
  int? peerVerified;
}

/// 聊天消息
class ChatMessage {
  ChatMessage({
    required this.fromMe,
    required this.text,
    this.type = 1,
    DateTime? time,
    this.serverId,
    this.failed = false,
    this.readAt,
  }) : localKey =
           DateTime.now().microsecondsSinceEpoch.toString() +
           (fromMe ? 'm' : 'p'),
       time = time ?? DateTime.now();

  /// 服务端消息 id（去重键；WS 帧与 HTTP 列表共用）
  final int? serverId;

  /// 本地唯一键（列表 key / 去重兜底）
  final String localKey;

  /// 发送失败标记：气泡显示失败态而非伪装成功
  final bool failed;

  /// 我发出的消息被对方阅读的时间（已读回执，VIP 权益）
  final DateTime? readAt;

  final bool fromMe;
  final String text;

  /// 1文本 2图片（text=图片URL）
  final int type;
  final DateTime time;

  bool get isImage => type == 2;

  /// 3语音（text=/files/ 录音路径）
  bool get isVoice => type == 3;

  /// 已读副本（收到 read 事件时更新）
  ChatMessage withRead(DateTime at) => ChatMessage(
        fromMe: fromMe,
        text: text,
        type: type,
        time: time,
        serverId: serverId,
        readAt: at,
      );

  /// 发送失败态副本（保留 serverId 为 null，重发时走新消息）
  ChatMessage failedCopy() => ChatMessage(
    fromMe: fromMe,
    text: text,
    type: type,
    time: time,
    failed: true,
  );
}

/// 会员商品（模拟后台配置，金额单位：分）
class MemberProduct {
  const MemberProduct({
    required this.id,
    required this.tier,
    this.tierRaw = 0,
    required this.durationDays,
    required this.priceCents,
    this.originalCents,
    this.firstPriceCents,
    this.badge,
  });

  final int id;
  final MemberTier tier;

  /// 原始档位（3 = 社交展示卡）
  final int tierRaw;
  final int durationDays;
  final int priceCents;
  final int? originalCents;
  final int? firstPriceCents;
  final String? badge;

  int get effectivePriceCents => firstPriceCents ?? priceCents;

  String get durationLabel => switch (durationDays) {
    30 => '月卡',
    90 => '季卡',
    365 => '年卡',
    _ => '$durationDays天',
  };
}

String yuan(int cents) =>
    (cents / 100).toStringAsFixed(cents % 100 == 0 ? 0 : 2);
