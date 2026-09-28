import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/providers.dart';
import '../chat/chat_page.dart';
import '../member/checkout_page.dart';
import '../shared/icebreakers.dart';
import 'match_dialog.dart';

/// 统一的"喜欢"动作处理（对接后端 /likes）：
/// 配额校验 → 配对弹窗 / 提示 / 付费引导
/// [popOnSuccess] 从详情页发起喜欢时，成功后需关闭详情页
Future<void> performLike(
  BuildContext context,
  WidgetRef ref,
  PersonCard p, {
  bool popOnSuccess = false,
  bool superLike = false,
}) async {
  final myTags = myTagsOf(ref);
  final myCity = ref.read(myProfileProvider)?['city']?.toString();
  // 先取 messenger/nav 再 await，避免跨异步间隙使用 context
  final messenger = ScaffoldMessenger.of(context);
  final nav = Navigator.of(context, rootNavigator: true);
  LikeOutcome outcome;
  try {
    outcome = await DiscoverActions.like(ref, p);
  } on ApiException catch (e) {
    // 网络失败/服务端错误：核心动作不能静默失败
    messenger.showSnackBar(SnackBar(content: Text(e.msg)));
    return;
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('网络异常，请稍后重试')));
    return;
  }

  switch (outcome.result) {
    case LikeResult.alreadyLiked:
      messenger.showSnackBar(
        SnackBar(
          content: Text('已经喜欢过 ${p.nickname} 了'),
          duration: const Duration(milliseconds: 800),
        ),
      );
    case LikeResult.processing:
      // 上一次点赞请求还在途（可能马上配对成功），不要误报
      messenger.showSnackBar(
        const SnackBar(
          content: Text('上一次操作还在处理中，请稍候'),
          duration: Duration(milliseconds: 800),
        ),
      );
    case LikeResult.quotaExceeded:
      // 配额用尽（后端 code=4001）：只弹付费引导
      if (context.mounted) await showQuotaDialog(context);
    case LikeResult.liked:
      if (popOnSuccess) nav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            superLike ? '已超级喜欢 ${p.nickname}，Ta 会优先看到你' : '已喜欢 ${p.nickname}',
          ),
          duration: const Duration(milliseconds: 900),
        ),
      );
    case LikeResult.matched:
      // 配对成功：重度触感（全产品最重要的 3 秒）
      HapticFeedback.mediumImpact();
      // 共同点/破冰话术：优先用后端配对时计算的结果，无则本地按资料生成
      final commonTags = outcome.commonTags.isNotEmpty
          ? outcome.commonTags
          : commonTagsFor(p, myTags, myCity: myCity);
      final icebreakers = outcome.icebreakers.isNotEmpty
          ? outcome.icebreakers
          : icebreakersFor(p, myTags, myCity: myCity);
      if (!context.mounted) return;
      // 返回：null=继续逛；''=进聊天；其他=选中的破冰话术（进聊天并直发）
      final choice = await showDialog<String>(
        context: context,
        barrierColor: const Color(0xA8140A0F),
        builder: (_) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: MatchDialog(
            person: p,
            commonTags: commonTags,
            icebreakers: icebreakers,
          ),
        ),
      );
      if (popOnSuccess) nav.pop();
      if (choice != null) {
        // 找到后端刚建的会话（含 convId/matchId）
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
        final target =
            conv ??
            (Conversation(
                personId: p.id,
                lastMessage: '配对成功，快打个招呼吧～',
                lastTime: '刚刚',
              )
              ..peerNickname = p.nickname
              ..peerAvatarUrl = p.photos.isNotEmpty ? p.photos.first : null
              ..peerGender = p.gender == Gender.male ? 1 : 2
              ..peerVerified = p.verified ? 1 : 0);
        nav.push(
          AppPageRoute(
            builder: (_) => ChatPage(
              conversation: target,
              initialMessage: choice.isEmpty ? null : choice,
              icebreakers: icebreakers,
            ),
          ),
        );
      }
  }
}

/// 免费配额用尽弹窗（付费墙主入口，见设计文档 4.8）
Future<void> showQuotaDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('今日喜欢次数已用完'),
      content: Text(
        '免费用户每天可喜欢 30 人。\n'
        '开通 VIP 解锁无限喜欢、反悔、查看谁喜欢了你等权益。',
        style: const TextStyle(height: 1.6),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('明天再来'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.of(context, rootNavigator: true).push(
              AppPageRoute(
                builder: (_) => const CheckoutPage(initialTier: MemberTier.vip),
              ),
            );
          },
          child: const Text('开通 VIP'),
        ),
      ],
    ),
  );
}
