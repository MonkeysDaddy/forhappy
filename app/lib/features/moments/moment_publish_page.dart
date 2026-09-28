import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/api.dart';
import '../../api/api_client.dart';
import '../../core/theme.dart';
import '../../core/tracker.dart';
import '../../state/providers.dart';
import '../shared/widgets.dart';

/// 发布动态：1-6 张照片（相册多选）+ 文案；先上传后发布，文案过联系方式过滤
class MomentPublishPage extends ConsumerStatefulWidget {
  const MomentPublishPage({super.key});

  @override
  ConsumerState<MomentPublishPage> createState() => _MomentPublishPageState();
}

class _MomentPublishPageState extends ConsumerState<MomentPublishPage> {
  final _controller = TextEditingController();
  final _photos = <String>[]; // 本地待上传路径
  final _uploaded = <String>[]; // 已上传的 /files/ 路径（与 _photos 按序对应）
  bool _publishing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_publishing &&
      (_controller.text.trim().isNotEmpty || _photos.isNotEmpty);

  Future<void> _pickPhotos() async {
    if (_photos.length >= 6) return;
    final picked = await ImagePicker().pickMultiImage(
      imageQuality: 72,
      maxWidth: 1080,
    );
    if (picked.isEmpty) return;
    final room = 6 - _photos.length;
    setState(() => _photos.addAll(picked.take(room).map((x) => x.path)));
  }

  Future<void> _removeAt(int i) async {
    setState(() {
      _photos.removeAt(i);
      if (i < _uploaded.length) _uploaded.removeAt(i);
    });
  }

  Future<void> _publish() async {
    if (!_canSubmit) return;
    setState(() => _publishing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // 先补齐未上传的照片
      final urls = <String>[];
      for (var i = 0; i < _photos.length; i++) {
        if (i < _uploaded.length) {
          urls.add(_uploaded[i]);
        } else {
          final url = await Api.uploadFile(_photos[i]);
          if (url.isEmpty) throw Exception('照片上传失败');
          _uploaded.add(url);
          urls.add(url);
        }
      }
      await Api.publishMoment(_controller.text.trim(), urls);
      Tracker.log('moment_publish');
      ref.invalidate(momentsProvider);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('发布成功'),
          duration: Duration(milliseconds: 900),
        ),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.msg)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('发布失败，请检查网络')));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    if (_photos.isEmpty && _controller.text.trim().isEmpty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('放弃这条动态？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('放弃',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await _confirmDiscard();
        if (context.mounted && discard) Navigator.pop(context);
      },
      child: Scaffold(
      appBar: GradientAppBar(
        title: '发布动态',
        actions: [
          TextButton(
            onPressed: _canSubmit ? _publish : null,
            child: Text(
              _publishing
                  ? '上传中…'
                  : _publishing
                  ? '发布中…'
                  : '发布',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _canSubmit ? Colors.white : Colors.white54,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            maxLines: 5,
            maxLength: 500,
            cursorColor: brandColor,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '分享此刻…（禁止留联系方式）',
              hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
              border: InputBorder.none,
              counterText: '',
            ),
            style: const TextStyle(fontSize: 15, height: 1.6),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _photos.length; i++)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                      child: Image.file(
                        File(_photos[i]),
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: -6,
                      top: -6,
                      child: GestureDetector(
                        onTap: () => _removeAt(i),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.textPrimary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              if (_photos.length < 6)
                GestureDetector(
                  onTap: _pickPhotos,
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: AppColors.fill,
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                    ),
                    child: Icon(
                      LucideIcons.imagePlus,
                      size: 28,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '· 照片将先上传到本站服务器\n· 联系方式与违规内容会被拦截\n· 每天最多发布 10 条',
            style: TextStyle(
              fontSize: 12,
              height: 1.8,
              color: AppColors.textTertiary,
            ),
          ),
        ],
        ),
      ),
    );
  }
}
