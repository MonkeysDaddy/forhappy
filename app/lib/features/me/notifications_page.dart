import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../../api/api_client.dart';
import '../../core/theme.dart';
import '../shared/widgets.dart';

/// 通知中心：系统公告 / 配对 / 喜欢 / 会员到期提醒
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  bool loading = true;
  List<Map<String, dynamic>> items = const [];
  int unread = 0;

  IconData _icon(String type) => switch (type) {
        'match' => Icons.favorite_rounded,
        'like' => Icons.person_rounded,
        'expiry' => Icons.schedule_rounded,
        _ => Icons.campaign_rounded,
      };

  String _relative(dynamic iso) {
    final t = DateTime.tryParse(iso?.toString() ?? '');
    if (t == null) return '';
    final m = DateTime.now().difference(t).inMinutes;
    if (m < 1) return '刚刚';
    if (m < 60) return '$m 分钟前';
    if (m < 24 * 60) return '${m ~/ 60} 小时前';
    return '${m ~/ (24 * 60)} 天前';
  }

  Future<void> load() async {
    final d = await Api.notifications();
    if (!mounted) return;
    setState(() {
      items = ApiClient.listOf(d['items'])
          .map((j) => Map<String, dynamic>.from(j))
          .toList();
      unread = (d['unread'] as num?)?.toInt() ?? 0;
      loading = false;
    });
  }

  Future<void> _readAll() async {
    await Api.readAllNotifications();
    await load();
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(title: '通知中心'),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: brandColor))
          : items.isEmpty
              ? const EmptyState(
                  image: 'assets/images/guide_chat.png',
                  icon: Icons.notifications_none_rounded,
                  title: '还没有通知',
                  subtitle: '配对成功、系统公告都会出现在这里',
                )
              : RefreshIndicator(
                  color: brandColor,
                  onRefresh: load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: unread > 0 ? _readAll : null,
                          child: Text(
                            unread > 0 ? '全部已读 ($unread)' : '全部已读',
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                      ),
                      for (final n in items)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: cardDecoration(
                            color: n['readAt'] == null
                                ? AppColors.brandWash
                                : AppColors.surface,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.brandSoft,
                                child: Icon(
                                  _icon(n['type'].toString()),
                                  size: 18,
                                  color: brandColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            n['title']?.toString() ?? '',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        if (n['readAt'] == null)
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration: const BoxDecoration(
                                              color: brandColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      n['content']?.toString() ?? '',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        height: 1.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _relative(n['createdAt']),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
