import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../../api/api_client.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import 'widgets.dart';

/// 举报类目（设计 6.3）
const _reportCategories = {
  1: '虚假资料',
  2: '诈骗引流',
  3: '骚扰辱骂',
  4: '色情低俗',
  5: '疑似未成年',
  6: '其他',
};

/// 举报表单（后端 POST /reports）：类目单选 + 补充说明
Future<void> showReportSheet(
  BuildContext context,
  WidgetRef ref, {
  required int userId,
  required String name,
}) async {
  int category = 1;
  final descController = TextEditingController();
  bool submitting = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.flag, size: 20, color: brandColor),
                const SizedBox(width: 8),
                Text(
                  '举报 $name',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: Colors.black38,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in _reportCategories.entries)
                  ChoiceChip(
                    label: Text(
                      e.value,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    selected: category == e.key,
                    onSelected: (_) => setSheetState(() => category = e.key),
                    selectedColor: brandColor.withValues(alpha: 0.12),
                    labelStyle: TextStyle(
                      color: category == e.key ? brandColor : Colors.black87,
                      fontWeight: category == e.key
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              maxLines: 3,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: '补充说明（选填）',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                onPressed: submitting
                    ? null
                    : () async {
                        // 先取 messenger 再 await，避免跨异步间隙使用 context
                        final messenger = ScaffoldMessenger.of(sheetContext);
                        setSheetState(() => submitting = true);
                        try {
                          await Api.report(
                            userId,
                            category,
                            descController.text.trim(),
                          );
                          if (context.mounted) Navigator.pop(context);
                          messenger.showSnackBar(
                            const SnackBar(content: Text('已收到举报，我们会尽快核实处理')),
                          );
                        } on ApiException catch (e) {
                          setSheetState(() => submitting = false);
                          messenger.showSnackBar(
                            SnackBar(content: Text(e.msg)),
                          );
                        } catch (_) {
                          setSheetState(() => submitting = false);
                          messenger.showSnackBar(
                            const SnackBar(content: Text('提交失败，请检查网络')),
                          );
                        }
                      },
                child: Text(submitting ? '提交中…' : '提交举报'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  descController.dispose();
}

/// 拉黑确认（后端 POST /blocks）：双向移出信息流并关闭会话
Future<void> confirmAndBlock(
  BuildContext context,
  WidgetRef ref, {
  required int userId,
  required String name,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('拉黑 $name？'),
      content: const Text('拉黑后双方将从彼此的信息流消失，会话关闭，且无法再次互动。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('拉黑'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await Api.block(userId);
    ref.invalidate(feedProvider);
    ref.invalidate(conversationsProvider);
    ref.invalidate(matchesProvider);
    ref.invalidate(momentsProvider);
    ref.invalidate(blacklistProvider);
    messenger.showSnackBar(const SnackBar(content: Text('已拉黑，对方将无法再与你互动')));
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.msg)));
  }
}
