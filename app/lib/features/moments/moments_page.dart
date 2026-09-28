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
import '../discover/city_sheet.dart';
import '../discover/user_detail_page.dart';
import '../shared/widgets.dart';
import 'moment_publish_page.dart';

/// Tab2 动态：按距离查看周围用户的动态（后端 /moments），支持点赞/评论
class MomentsPage extends ConsumerWidget {
  const MomentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final city = ref.watch(cityProvider);
    final located = ref.watch(locatedCityProvider);
    final momentsAsync = ref.watch(momentsProvider);

    return Stack(
      children: [
        Column(
          children: [
            GradientPageHeader(
              bottom: 12,
              child: Row(
                children: [
                  const Text(
                    '动态',
                    style: TextStyle(
                      fontFamily: brandDisplayFont,
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '按距离排序',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                  const Spacer(),
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
                            AppPageRoute(
                              builder: (_) => const CitySelectPage(),
                            ),
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
            ),
            Expanded(
              child: momentsAsync.when(
                loading: () => const MomentsSkeleton(),
                error: (e, _) => EmptyState(
                  icon: LucideIcons.cloudOff,
                  title: e is ApiException ? e.msg : '动态加载失败',
                  subtitle: '检查后端服务后重试',
                  actionLabel: '重试',
                  onAction: () => ref.invalidate(momentsProvider),
                ),
                data: (items) => items.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.only(bottom: 110),
                        child: EmptyState(
                          image: 'assets/images/guide_discover.png',
                          icon: LucideIcons.layers,
                          title: '附近还没有动态',
                          subtitle: '换个城市看看大家都在分享什么',
                        ),
                      )
                    : ListView.separated(
                        controller: TabScrollRegistry.controllerFor(1),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => _MomentCard(
                          key: ValueKey(items[i].momentId),
                          item: items[i],
                        ),
                      ),
              ),
            ),
          ],
        ),
        // 发布动态入口（悬浮，避开 Dock）
        Positioned(
          right: 20,
          bottom: 130,
          child: FloatingActionButton(
            backgroundColor: brandColor,
            foregroundColor: Colors.white,
            elevation: 4,
            heroTag: 'publishMoment',
            onPressed: () => Navigator.push(
              context,
              AppPageRoute(builder: (_) => const MomentPublishPage()),
            ),
            child: const Icon(LucideIcons.notebookPen, size: 26),
          ),
        ),
      ],
    );
  }
}

class _MomentCard extends ConsumerStatefulWidget {
  const _MomentCard({super.key, required this.item});

  final ApiMoment item;

  @override
  ConsumerState<_MomentCard> createState() => _MomentCardState();
}

class _MomentCardState extends ConsumerState<_MomentCard> {
  final TextEditingController _commentController = TextEditingController();
  bool _showInput = false;
  bool _likeBusy = false;
  bool _commentBusy = false;
  bool _showComments = false;
  bool _loadingComments = false;
  List<MomentComment> _comments = const [];
  late bool _liked = widget.item.likedByMe;
  late int _likeCount = widget.item.likeCount;
  late int _commentCount = widget.item.commentCount;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String get _distanceText {
    final d = widget.item.distanceKm;
    if (d == null) return '距离隐藏';
    if (d < 1) return '${(d * 1000).round()}m';
    return '${d.toStringAsFixed(1)}km';
  }

  Future<void> _toggleLike() async {
    if (_likeBusy) return; // 双击防抖
    _likeBusy = true;
    final next = !_liked;
    HapticFeedback.lightImpact();
    setState(() {
      _liked = next;
      _likeCount += next ? 1 : -1;
    });
    try {
      await Api.toggleMomentLike(widget.item.momentId);
    } catch (_) {
      if (mounted) {
        setState(() {
          _liked = !next;
          _likeCount += next ? -1 : 1;
        });
      }
    } finally {
      _likeBusy = false;
    }
  }

  Future<void> _loadComments() async {
    if (_showComments) {
      setState(() => _showComments = false);
      return;
    }
    setState(() {
      _showComments = true;
      _loadingComments = true;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final list = await Api.momentComments(widget.item.momentId);
      if (mounted) setState(() => _comments = list);
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('评论加载失败，请重试')));
    } finally {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _commentBusy) return;
    _commentBusy = true;
    try {
      await Api.addMomentComment(widget.item.momentId, text);
      if (!mounted) return;
      setState(() {
        _comments = [
          ..._comments,
          MomentComment(
            author: ApiClient.myNickname ?? '我',
            text: text,
            timeLabel: '刚刚',
          ),
        ];
        _commentCount += 1;
        _showComments = true;
        _showInput = false;
      });
      _commentController.clear(); // 成功后再清空：失败不丢用户输入
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.msg)));
      }
    } finally {
      _commentBusy = false;
    }
  }

  void _openDetail() {
    Navigator.push(
      context,
      AppPageRoute(
        builder: (_) => UserDetailPage(
          personId: widget.item.author.id,
          seed: widget.item.author,
          distanceKm: widget.item.distanceKm,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.item.author;
    final m = widget.item.moment;

    return Container(
      decoration: cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 发布者
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openDetail,
            child: Row(
              children: [
                PersonAvatar(
                  url: p.photos.isNotEmpty ? p.photos.first : null,
                  size: 44,
                  fallbackText: p.nickname.characters.first,
                  onlineMinutes: p.lastActiveMinutes,
                  verified: p.verified,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              p.nickname,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GenderIcon(gender: p.gender, size: 12),
                          if (p.verified) ...[
                            const SizedBox(width: 4),
                            const VerifiedBadge(size: 16),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$_distanceText · ${m.timeLabel}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                MemberBadge(tier: p.memberTier),
              ],
            ),
          ),
          // 文案
          if (m.caption.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              m.caption,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          // 照片
          if (m.photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < m.photos.length && i < 2; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedPhoto(url: m.photos[i]),
                            if (i == 1 && m.photos.length > 2)
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppColors.photoScrim
                                      .withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    '+${m.photos.length - 2}',
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 10),
          // 点赞 / 评论
          Row(
            children: [
              _actionButton(
                icon: _liked ? Icons.favorite : Icons.favorite_border,
                color: _liked ? brandColor : AppColors.textSecondary,
                label: '$_likeCount',
                onTap: _toggleLike,
              ),
              const SizedBox(width: 20),
              _actionButton(
                icon: LucideIcons.messageCircle,
                color: AppColors.textSecondary,
                label: '$_commentCount',
                onTap: _loadComments,
              ),
              const SizedBox(width: 12),
              _actionButton(
                icon: LucideIcons.penLine,
                color: AppColors.textSecondary,
                label: '评论',
                onTap: () => setState(() => _showInput = !_showInput),
              ),
              const Spacer(),
              Icon(
                LucideIcons.moreHorizontal,
                size: 18,
                color: AppColors.textDisabled,
              ),
            ],
          ),
          // 评论列表（展开时从后端加载）
          if (_showComments) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.fill,
                borderRadius: BorderRadius.circular(10),
              ),
              child: _loadingComments
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
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
                  : _comments.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '还没有评论，说点什么吧～',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final c in _comments)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${c.author}：',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  TextSpan(
                                    text: c.text,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.4,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
          // 评论输入
          if (_showInput) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    autofocus: true,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submitComment(),
                    decoration: InputDecoration(
                      hintText: '说点什么…',
                      hintStyle: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: AppColors.fill,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _submitComment,
                  style: IconButton.styleFrom(
                    backgroundColor: brandColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(38, 38),
                  ),
                  icon: const Icon(LucideIcons.send, size: 17),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
        ),
      ),
    );
  }
}
