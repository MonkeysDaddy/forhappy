import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../../api/api_client.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/providers.dart';
import '../chat/chat_page.dart';
import '../discover/discover_actions.dart';
import '../discover/user_detail_page.dart';
import '../member/checkout_page.dart';
import '../shared/widgets.dart';

/// Tab 配对：互相配对列表（直达聊天）+ "喜欢我的人"模糊墙（VIP 解锁，设计 4.8/9.3）
class MatchesPage extends ConsumerWidget {
  const MatchesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchesProvider);
    final likedMeAsync = ref.watch(likedMeProvider);

    return ListView(
      controller: TabScrollRegistry.controllerFor(2),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
      children: [
        const GradientPageHeader(
          bottom: 14,
          child: SizedBox(
            width: double.infinity,
            child: Text(
              '配对',
              style: TextStyle(
                fontFamily: brandDisplayFont,
                fontSize: 27,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        // ---------- 互相配对 ----------
        Text(
          '互相喜欢 · ${matchesAsync.asData?.value.length ?? 0}',
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        matchesAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              children: [
                for (var i = 0; i < 5; i++)
                  const Padding(
                    padding: EdgeInsets.only(right: 14),
                    child: SkeletonCircle(size: 68),
                  ),
              ],
            ),
          ),
          error: (e, _) => EmptyState(
            icon: LucideIcons.cloudOff,
            title: e is ApiException ? e.msg : '配对加载失败',
            actionLabel: '重试',
            onAction: () => ref.invalidate(matchesProvider),
          ),
          data: (list) => list.isEmpty
              ? const EmptyState(
                  image: 'assets/images/guide_match.png',
                  icon: LucideIcons.heart,
                  title: '还没有互相配对',
                  subtitle: '去发现页右滑喜欢的人，彼此心动即可配对',
                )
              : SizedBox(
                  height: 116,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (context, i) => _MatchAvatar(entry: list[i]),
                  ),
                ),
        ),
        const SizedBox(height: 22),
        // ---------- 喜欢我的人 ----------
        likedMeAsync.when(
          loading: () => const SizedBox(height: 120),
          error: (e, _) => EmptyState(
            icon: LucideIcons.cloudOff,
            title: e is ApiException ? e.msg : '加载失败',
          ),
          data: (data) => _LikedMeSection(data: data),
        ),
      ],
    );
  }
}

/// 互相配对头像卡（点击直达聊天）
class _MatchAvatar extends ConsumerWidget {
  const _MatchAvatar({required this.entry});

  final FeedEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = entry.person;
    return GestureDetector(
      onTap: () async {
        // 找到对应会话（配对必有会话；找不到时兜底进资料页）
        Conversation? conv;
        try {
          final list = await ref.read(conversationsProvider.future);
          for (final c in list) {
            if (c.personId == p.id) {
              conv = c;
              break;
            }
          }
        } catch (_) {}
        if (!context.mounted) return;
        if (conv != null) {
          Navigator.push(
            context,
            AppPageRoute(builder: (_) => ChatPage(conversation: conv!)),
          );
        } else {
          Navigator.push(
            context,
            AppPageRoute(
              builder: (_) => UserDetailPage(personId: p.id, seed: p),
            ),
          );
        }
      },
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                PersonAvatar(
                  url: p.photos.isNotEmpty ? p.photos.first : null,
                  size: 68,
                  fallbackText: p.nickname.characters.first,
                ),
                if (p.verified)
                  const Positioned(
                    right: -2,
                    bottom: -2,
                    child: VerifiedBadge(size: 18),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              p.nickname,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// 喜欢我的人：非会员模糊墙 + 开通引导；会员完整列表（可快捷喜欢）
class _LikedMeSection extends ConsumerWidget {
  const _LikedMeSection({required this.data});

  final LikedMeData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = data.items.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '喜欢我的人',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: brandColor,
                ),
              ),
            ),
            const Spacer(),
            if (data.blurred)
              GestureDetector(
                onTap: () => pushThrottled(
                  context,
                  const CheckoutPage(initialTier: MemberTier.vip),
                  tag: 'checkout-vip',
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.crown,
                      size: 15,
                      color: AppColors.svipGold,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'VIP 查看',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.svipGold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (count == 0)
          const EmptyState(
            image: 'assets/images/guide_match.png',
            icon: LucideIcons.heart,
            title: '暂时还没有人喜欢你',
            subtitle: '完善资料和照片，能大幅提升被喜欢的概率',
          )
        else if (data.blurred)
          _BlurredWall(entries: data.items)
        else
          ...data.items.map((e) => _LikedMeTile(entry: e)),
      ],
    );
  }
}

/// 模糊墙：马赛克头像 + 模糊昵称（免费用户视角）
class _BlurredWall extends StatelessWidget {
  const _BlurredWall({required this.entries});

  final List<FeedEntry> entries;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        AppPageRoute(
          builder: (_) => const CheckoutPage(initialTier: MemberTier.vip),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(),
        child: Column(
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final e in entries.take(12))
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                    child: PersonAvatar(
                      url: e.person.photos.isNotEmpty
                          ? e.person.photos.first
                          : null,
                      size: 56,
                      fallbackText: e.person.nickname.characters.first,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.lock, size: 14, color: AppColors.svipGold),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    '${entries.length} 人喜欢了你，开通 VIP 立即查看',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.svipGold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 完整列表条目（会员）：头像 + 资料 + 距离 + 快捷喜欢
class _LikedMeTile extends ConsumerWidget {
  const _LikedMeTile({required this.entry});

  final FeedEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = entry.person;
    final liked = ref.watch(likedUsersProvider).contains(p.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: cardDecoration(),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: PersonAvatar(
          url: p.photos.isNotEmpty ? p.photos.first : null,
          size: 54,
          fallbackText: p.nickname.characters.first,
          onlineMinutes: p.lastActiveMinutes,
          verified: p.verified,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                p.age > 0 ? '${p.nickname}，${p.age}' : p.nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (p.verified) ...[
              const SizedBox(width: 4),
              const VerifiedBadge(size: 15),
            ],
          ],
        ),
        subtitle: Text(
          [
            p.city,
            if (entry.distanceKm != null && entry.distanceKm! > 0)
              entry.distanceText,
          ].where((s) => s.isNotEmpty).join(' · '),
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
        trailing: liked
            ? const Icon(LucideIcons.heart, size: 22, color: brandColor)
            : IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: brandColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => performLike(context, ref, p),
                icon: const Icon(LucideIcons.heart, size: 20),
              ),
        onTap: () => Navigator.push(
          context,
          AppPageRoute(
            builder: (_) => UserDetailPage(
              personId: p.id,
              seed: p,
              distanceKm: entry.distanceKm,
            ),
          ),
        ),
      ),
    );
  }
}
