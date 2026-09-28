import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../../api/api_client.dart';
import '../../models/models.dart';
import '../../state/providers.dart';
import '../../core/theme.dart';
import '../shared/widgets.dart';

/// 黑名单管理（后端 /blocks）：列表 + 移除（设计 4.7 P0）
class BlacklistPage extends ConsumerWidget {
  const BlacklistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(blacklistProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const GradientAppBar(title: '黑名单管理'),
      body: async.when(
        loading: () => const ListRowSkeleton(),
        error: (e, _) => EmptyState(
          icon: LucideIcons.cloudOff,
          title: e is ApiException ? e.msg : '加载失败',
          actionLabel: '重试',
          onAction: () => ref.invalidate(blacklistProvider),
        ),
        data: (list) => list.isEmpty
            ? const EmptyState(
                icon: LucideIcons.ban,
                title: '黑名单是空的',
                subtitle: '在聊天页或资料页可以拉黑骚扰你的人',
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                itemCount: list.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  indent: 76,
                  color: AppColors.divider,
                ),
                itemBuilder: (context, i) => _Tile(person: list[i]),
              ),
      ),
    );
  }
}

class _Tile extends ConsumerWidget {
  const _Tile({required this.person});

  final PersonCard person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messenger = ScaffoldMessenger.of(context);
    return ListTile(
      leading: PersonAvatar(
        url: person.photos.isNotEmpty ? person.photos.first : null,
        size: 52,
        fallbackText: person.nickname.characters.first,
      ),
      title: Text(
        person.nickname,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        person.city.isEmpty ? '已拉黑' : '${person.city} · 已拉黑',
        style: const TextStyle(fontSize: 12.5, color: Colors.black45),
      ),
      trailing: TextButton(
        onPressed: () async {
          try {
            await Api.unblock(person.id);
            ref.invalidate(blacklistProvider);
            ref.invalidate(feedProvider);
            messenger.showSnackBar(
              SnackBar(content: Text('已移出黑名单：${person.nickname}')),
            );
          } on ApiException catch (e) {
            messenger.showSnackBar(SnackBar(content: Text(e.msg)));
          }
        },
        child: const Text('移除', style: TextStyle(fontSize: 13.5)),
      ),
    );
  }
}
