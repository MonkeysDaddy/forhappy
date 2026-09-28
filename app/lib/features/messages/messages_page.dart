import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/providers.dart';
import '../chat/chat_page.dart';
import '../shared/widgets.dart';

/// Tab3 消息：会话列表（后端 /conversations）
class MessagesPage extends ConsumerWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convsAsync = ref.watch(conversationsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GradientPageHeader(
          bottom: 12,
          child: SizedBox(
            width: double.infinity,
            child: Text(
              '消息',
              style: TextStyle(
                fontFamily: brandDisplayFont,
                fontSize: 27,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
        Expanded(
          child: convsAsync.when(
            loading: () => const ListRowSkeleton(),
            error: (e, _) => EmptyState(
              icon: LucideIcons.cloudOff,
              title: e is ApiException ? e.msg : '会话加载失败',
              actionLabel: '重试',
              onAction: () => ref.invalidate(conversationsProvider),
            ),
            data: (conversations) => conversations.isEmpty
                ? const Padding(
                    padding: EdgeInsets.only(bottom: 110),
                    child: EmptyState(
                      image: 'assets/images/guide_chat.png',
                      icon: LucideIcons.messageCircle,
                      title: '配对成功后即可开始聊天',
                      subtitle: '互相喜欢的人，才能开口说第一句',
                    ),
                  )
                : ListView.separated(
                    controller: TabScrollRegistry.controllerFor(3),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                    itemCount: conversations.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      indent: 78,
                      color: AppColors.divider,
                    ),
                    itemBuilder: (context, i) =>
                        _ConversationTile(conversation: conversations[i]),
                  ),
          ),
        ),
      ],
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasUnread = conversation.unread > 0;
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          AppPageRoute(
            builder: (_) => ChatPage(conversation: conversation),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            // 头像 + 未读小红点（点在右上角，未读一眼可见）
            Stack(
              children: [
                PersonAvatar(
                  url: conversation.peerAvatarUrl,
                  size: 54,
                  fallbackText:
                      (conversation.peerNickname ?? '友').characters.first,
                  verified: conversation.peerVerified == 1,
                ),
                if (hasUnread)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: const BoxDecoration(
                          color: brandColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          conversation.peerNickname ?? '对的人',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: hasUnread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (conversation.peerVerified == 1) ...[
                        const SizedBox(width: 5),
                        const VerifiedBadge(size: 15),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conversation.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      color: hasUnread
                          ? AppColors.textSecondary
                          : AppColors.textTertiary,
                      fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // 右列：时间在上、未读数在下，安静对齐
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  conversation.lastTime,
                  style: const TextStyle(fontSize: 11, color: Colors.black38),
                ),
                if (hasUnread) ...[
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5.5,
                      vertical: 2,
                    ),
                    decoration: const BoxDecoration(
                      color: brandColor,
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      conversation.unread > 99
                          ? '99+'
                          : '${conversation.unread}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
