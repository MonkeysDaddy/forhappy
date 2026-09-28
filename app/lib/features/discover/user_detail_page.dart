import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../../api/api_client.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/providers.dart';
import '../member/checkout_page.dart';
import '../shared/report_sheet.dart';
import '../shared/widgets.dart';
import 'discover_actions.dart';

/// 资料详情页：从后端 /users/{id} 拉取全量资料 + 动态；联系方式仅配对后可见
class UserDetailPage extends ConsumerStatefulWidget {
  const UserDetailPage({
    super.key,
    required this.personId,
    this.seed,
    this.distanceKm,
  });

  final int personId;

  /// 列表页带过来的卡片信息（加载完成前的占位展示）
  final PersonCard? seed;
  final double? distanceKm;

  @override
  ConsumerState<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends ConsumerState<UserDetailPage> {
  final PageController _photoController = PageController();
  int _photoIndex = 0;
  UserDetail? _detail;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _photoController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _error = null);
    try {
      final detail = await Api.userDetail(widget.personId);
      if (mounted) setState(() => _detail = detail);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.msg);
    } catch (_) {
      if (mounted) setState(() => _error = '加载失败，请检查后端服务');
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final p = detail?.user ?? widget.seed;
    final liked = ref.watch(likedUsersProvider).contains(widget.personId);

    // 照片区高度随屏高自适应（小屏不溢出、大屏不局促）
    final photoHeight = (MediaQuery.of(context).size.height * 0.58).clamp(
      380.0,
      520.0,
    );

    final photos = detail != null && detail.photoUrls.isNotEmpty
        ? detail.photoUrls
        : (widget.seed?.photos ?? const <String>[]);

    // 照片铺到状态栏底下：声明本页用浅色状态栏图标（时间/信号在深色照片上可见）
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leadingWidth: 56,
          leading: Builder(
            builder: (ctx) => Padding(
              padding: const EdgeInsets.all(12),
              child: _glassCircle(
                child: IconButton(
                  icon: const Icon(LucideIcons.arrowLeft, size: 20),
                  color: Colors.white,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: _glassCircle(
                child: IconButton(
                  icon: const Icon(LucideIcons.flag, size: 18),
                  color: Colors.white,
                  tooltip: '举报',
                  onPressed: () => showReportSheet(
                    context,
                    ref,
                    userId: widget.personId,
                    name: p?.nickname ?? '对方',
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 12, right: 8),
              child: _glassCircle(
                child: IconButton(
                  icon: const Icon(LucideIcons.ban, size: 18),
                  color: Colors.white,
                  tooltip: '拉黑',
                  onPressed: () => confirmAndBlock(
                    context,
                    ref,
                    userId: widget.personId,
                    name: p?.nickname ?? '对方',
                  ),
                ),
              ),
            ),
          ],
        ),
        body: p == null
            ? Center(
                child: _error != null
                    ? EmptyState(
                        icon: LucideIcons.cloudOff,
                        title: _error!,
                        actionLabel: '重试',
                        onAction: _fetch,
                      )
                    : const CircularProgressIndicator(color: brandColor),
              )
            : ListView(
                children: [
                  SizedBox(
                    height: photoHeight,
                    child: Stack(
                      children: [
                        PageView.builder(
                          controller: _photoController,
                          itemCount: photos.length,
                          onPageChanged: (i) => setState(() => _photoIndex = i),
                          itemBuilder: (context, i) =>
                              CachedPhoto(url: photos[i]),
                        ),
                        // 顶部压暗，保证毛玻璃按钮可见
                        const Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 96,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0x59000000), Color(0x00000000)],
                              ),
                            ),
                          ),
                        ),
                        // 底部 scrim + 姓名大字浮层（杂志式排版）
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _photoNameOverlay(p),
                        ),
                        if (photos.length > 1)
                          Positioned(
                            right: 12,
                            bottom: 14,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 12,
                                  sigmaY: 12,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  color: const Color(0x40000000),
                                  child: Text(
                                    '${_photoIndex + 1} / ${photos.length}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (photos.length > 1)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 12,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var i = 0; i < photos.length; i++)
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    width: i == _photoIndex ? 18 : 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: i == _photoIndex
                                          ? brandColor
                                          : const Color(0x66FFFFFF),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildBody(detail, p),
                  ),
                ],
              ),
        bottomNavigationBar: p == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(56, 48),
                            foregroundColor: AppColors.textSecondary,
                            side: BorderSide(color: AppColors.divider),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: () {
                            DiscoverActions.hide(ref, p.id);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('已隐藏 ${p.nickname}'),
                                action: SnackBarAction(
                                  label: '撤销',
                                  textColor: AppColors.onDarkAccent,
                                  onPressed: () {
                                    ref
                                        .read(hiddenUsersProvider.notifier)
                                        .state = {
                                      ...ref.read(hiddenUsersProvider),
                                    }..remove(p.id);
                                  },
                                ),
                              ),
                            );
                          },
                          icon: const Icon(LucideIcons.eyeOff, size: 18),
                          label: const Text('隐藏'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: liked
                            ? OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(64, 48),
                                  foregroundColor: brandColor,
                                  side: BorderSide(
                                    color: brandColor.withValues(alpha: 0.5),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                // 反悔（撤销喜欢）：VIP 权益（设计 4.8），免费用户引导开通
                                onPressed: () => _confirmUndoLike(p),
                                icon: const Icon(LucideIcons.heart, size: 18),
                                label: const Text('已喜欢'),
                              )
                            : GradientButton(
                                onPressed: () => performLike(
                                  context,
                                  ref,
                                  p,
                                  popOnSuccess: true,
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(LucideIcons.heart, size: 18),
                                    SizedBox(width: 6),
                                    Text('喜欢'),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  /// 撤销喜欢（反悔）：免费用户 4003 引导开通 VIP，VIP 每日 5 次 / SVIP 不限
  Future<void> _confirmUndoLike(PersonCard p) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('撤销对 ${p.nickname} 的喜欢？'),
        content: const Text(
          '撤销后 Ta 将不再出现在你的喜欢列表，你也会重新出现在 Ta 的信息流中。\n（VIP 每日 5 次，SVIP 不限）',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('撤销'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final r = await Api.undoLike(p.id);
      if (!mounted) return;
      ref.read(likedUsersProvider.notifier).state = {
        ...ref.read(likedUsersProvider),
      }..remove(p.id);
      ref.read(hiddenUsersProvider.notifier).state = {
        ...ref.read(hiddenUsersProvider),
      }..remove(p.id);
      ref.invalidate(feedProvider);
      final remaining = (r['undoRemaining'] as num?)?.toInt();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            remaining == null || remaining < 0
                ? '已撤销喜欢'
                : '已撤销喜欢，今日还可反悔 $remaining 次',
          ),
        ),
      );
      nav.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 4003) {
        // 反悔是 VIP 权益：弹开通引导
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text('反悔是 VIP 权益'),
            content: const Text('开通 VIP 可撤销喜欢与隐藏（每日 5 次，SVIP 不限），还能查看谁喜欢了你。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('暂不开通'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.push(
                    context,
                    AppPageRoute(
                      builder: (_) =>
                          const CheckoutPage(initialTier: MemberTier.vip),
                    ),
                  );
                },
                child: const Text('开通 VIP'),
              ),
            ],
          ),
        );
      } else {
        messenger.showSnackBar(SnackBar(content: Text(e.msg)));
      }
    }
  }

  Widget _buildBody(UserDetail? detail, PersonCard p) {
    // 共同点：对方标签 ∩ 我的标签（我的标签来自后端 /profile/me）
    final tags = myTags(ref.watch(myProfileProvider));
    final commonTags = p.tags.where(tags.contains).toList();
    final distanceKm = detail?.distanceKm ?? widget.distanceKm;
    final matched = detail?.matched ?? false;
    final moments = detail?.moments ?? const <Moment>[];
    final weightKg = detail?.user.weightKg ?? 0;
    final income = detail?.user.income;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 数据行：大数字 + 小标签（杂志内页式），比胶囊墙更有排版张力
        if (p.age > 0 || p.heightCm > 0 || distanceKm != null)
          Row(
            children: [
              if (p.age > 0) _stat('${p.age}', '岁'),
              if (p.heightCm > 0) _stat('${p.heightCm}', 'cm'),
              if (distanceKm != null)
                _stat(
                  distanceKm < 1
                      ? '${(distanceKm * 1000).round()}'
                      : distanceKm.toStringAsFixed(1),
                  'km',
                ),
            ],
          ),
        if (p.age > 0 || p.heightCm > 0 || distanceKm != null)
          const SizedBox(height: 14),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (p.city.isNotEmpty) _infoItem(LucideIcons.building2, p.city),
            if (p.heightCm > 0) _infoItem(LucideIcons.ruler, '${p.heightCm}cm'),
            if (weightKg > 0) _infoItem(LucideIcons.scale, '${weightKg}kg'),
            if (p.education.isNotEmpty)
              _infoItem(LucideIcons.school, p.education),
            if (p.occupation.isNotEmpty)
              _infoItem(LucideIcons.briefcase, p.occupation),
            if (income != null)
              _infoItem(LucideIcons.wallet, '年收入 ${income.label}'),
          ],
        ),
        if (commonTags.isNotEmpty) ...[
          const SizedBox(height: 22),
          _sectionTitle('你们的共同点'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: commonTags
                .map((t) => TagChip(t, highlight: true))
                .toList(),
          ),
        ],
        if (p.tags.isNotEmpty) ...[
          const SizedBox(height: 22),
          _sectionTitle('兴趣爱好'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: p.tags.map((t) => TagChip(t)).toList(),
          ),
        ],
        if (moments.isNotEmpty) ...[
          const SizedBox(height: 22),
          _sectionTitle(p.gender == Gender.female ? '她的动态' : '他的动态'),
          const SizedBox(height: 8),
          for (final m in moments) _momentCard(m),
        ],
        const SizedBox(height: 22),
        _sectionTitle('关于我'),
        const SizedBox(height: 6),
        Text(
          p.bio.isEmpty ? '这个人很懒，什么都没写～' : p.bio,
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 22),
        // 社交账号展示（对方购买「社交展示卡」后主动公开，订阅到期即隐藏）
        if ((detail?.socialShowcase ?? const []).isNotEmpty) ...[
          _sectionTitle('社交账号'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final it in detail!.socialShowcase)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.brandWash,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    border: Border.all(
                        color: brandColor.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(it['platform'] ?? '',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary)),
                      const SizedBox(width: 6),
                      Text(it['account'] ?? '',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        const SizedBox(height: 22),
        Row(
          children: [
            _sectionTitle('联系方式'),
            if (!matched) ...[
              const SizedBox(width: 8),
              Text(
                '互相喜欢配对后可查看',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (!matched) ...[
          // 未配对：联系方式锁定（产品红线：先配对后聊天）
          if (p.wechat?.isNotEmpty ?? false) _lockedContactRow('微信号'),
          if (p.instagram?.isNotEmpty ?? false) _lockedContactRow('Instagram'),
          if (p.facebook?.isNotEmpty ?? false) _lockedContactRow('Facebook'),
          if (p.wechat == null && p.instagram == null && p.facebook == null)
            const Text(
              'Ta 还没有填写联系方式',
              style: TextStyle(fontSize: 13, color: Colors.black38),
            ),
        ] else ...[
          if (p.wechat != null && p.wechat!.isNotEmpty)
            _contactRow('微信号', p.wechat!, '微', AppColors.wechatGreen),
          if (p.instagram != null && p.instagram!.isNotEmpty)
            _contactRow(
              'Instagram',
              p.instagram!,
              'Ins',
              AppColors.instagramPink,
            ),
          if (p.facebook != null && p.facebook!.isNotEmpty)
            _contactRow('Facebook', p.facebook!, 'f', AppColors.facebookBlue),
          if ((p.wechat == null || p.wechat!.isEmpty) &&
              (p.instagram == null || p.instagram!.isEmpty) &&
              (p.facebook == null || p.facebook!.isEmpty))
            const Text(
              'Ta 还没有填写联系方式',
              style: TextStyle(fontSize: 13, color: Colors.black38),
            ),
        ],
      ],
    );
  }

  /// 照片底部姓名浮层：大字昵称 + 年龄/性别/认证，第二行城市·职业
  Widget _photoNameOverlay(PersonCard p) {
    final secondLine = [
      if (p.city.isNotEmpty) p.city,
      if (p.occupation.isNotEmpty) p.occupation,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 44, 18, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xB31A1216), Color(0x4D1A1216), Color(0x001A1216)],
          stops: [0, 0.55, 1],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  p.age > 0 ? '${p.nickname}，${p.age}' : p.nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: brandDisplayFont,
                    fontSize: 31,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                    shadows: [Shadow(color: Color(0x66000000), blurRadius: 12)],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                p.gender == Gender.male ? Icons.male : Icons.female,
                size: 20,
                color: Colors.white,
              ),
              if (p.verified) ...[
                const SizedBox(width: 6),
                const VerifiedBadge(size: 18),
              ],
            ],
          ),
          if (secondLine.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              secondLine,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 数据大字项：数值 + 单位小标签
  Widget _stat(String value, String unit) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.1,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 18,
            height: 3,
            decoration: BoxDecoration(
              gradient: brandGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  /// 章节标题：品牌竖条 + 小节名，全页统一节奏
  Widget _sectionTitle(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 3.5,
          height: 14,
          decoration: BoxDecoration(
            gradient: brandGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  /// 毛玻璃圆钮（透明 AppBar 上的返回/举报）
  Widget _glassCircle({required Widget child}) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: const Color(0x33FFFFFF),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }

  /// 动态卡片：图片（1-2 张）+ 文案 + 时间/点赞数
  Widget _momentCard(Moment m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (m.photos.isNotEmpty)
            Row(
              children: [
                for (var i = 0; i < m.photos.length && i < 2; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: CachedPhoto(url: m.photos[i]),
                    ),
                  ),
                ],
              ],
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (m.caption.isNotEmpty)
                  Text(
                    m.caption,
                    style: const TextStyle(fontSize: 13.5, height: 1.5),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      m.timeLabel,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.black38,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      LucideIcons.heart,
                      size: 13,
                      color: Colors.black38,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${m.likes}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 未配对时的锁定行（模糊 + 锁图标）
  Widget _lockedContactRow(String label) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.lock, size: 14, color: AppColors.textTertiary),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
          const Spacer(),
          Text(
            '配对后解锁',
            style: TextStyle(fontSize: 11, color: AppColors.textDisabled),
          ),
        ],
      ),
    );
  }

  Widget _contactRow(
    String label,
    String value,
    String badgeText,
    Color badgeColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.fillCold,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              badgeText,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: '复制',
            icon: const Icon(LucideIcons.copy, size: 15, color: Colors.black38),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已复制：$value'),
                  duration: const Duration(milliseconds: 900),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.fillCold,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(fontSize: 12.5, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
