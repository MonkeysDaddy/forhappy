import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/api.dart';
import '../../api/api_client.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../shared/widgets.dart';

/// 照片墙管理：多张上传（最多 9 张）、删除、设为头像
/// （第一张=门面照，社交产品的核心资产）
class PhotoManagerPage extends ConsumerStatefulWidget {
  const PhotoManagerPage({super.key});

  @override
  ConsumerState<PhotoManagerPage> createState() => _PhotoManagerPageState();
}

class _PhotoManagerPageState extends ConsumerState<PhotoManagerPage> {
  bool _busy = false;

  List<Map<String, dynamic>> get _photos {
    final user = ref.read(myProfileProvider);
    // 本人视角：全部照片（含待审），照片墙显示审核状态标记
    final list = user?['photosMine'] ?? user?['photos'];
    return list is List
        ? list.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : [];
  }

  Future<void> _reload() async {
    try {
      final me = await Api.myProfile();
      ApiClient.myProfile = me;
      ApiClient.myAvatar = me['avatarUrl']?.toString();
      if (mounted) ref.read(myProfileProvider.notifier).state = me;
    } catch (_) {}
  }

  Future<void> _addPhoto() async {
    if (_busy || _photos.length >= 9) return;
    final messenger = ScaffoldMessenger.of(context);
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 72,
      maxWidth: 1080,
    );
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final url = await Api.uploadFile(picked.path);
      if (url.isEmpty) throw Exception();
      await ApiClient.unwrap(
        ApiClient.dio.post(
          '/profile/photos',
          data: {'url': url, 'isAvatar': _photos.isEmpty},
        ),
      );
      await _reload();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('已上传'),
          duration: Duration(milliseconds: 800),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('上传失败，请重试')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(int id) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ApiClient.unwrap(ApiClient.dio.delete('/profile/photos/$id'));
      await _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('删除失败')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setAvatar(int id) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ApiClient.unwrap(
        ApiClient.dio.put('/profile/photos/$id', data: {'isAvatar': true}),
      );
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已设为头像'),
            duration: Duration(milliseconds: 800),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('设置失败')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = _photos;
    return Scaffold(
      appBar: const GradientAppBar(title: '照片墙'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: brandColor,
        foregroundColor: Colors.white,
        heroTag: 'addPhoto',
        onPressed: _photos.length >= 9 ? null : _addPhoto,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(LucideIcons.camera, size: 20),
        label: Text(_photos.length >= 9 ? '已满 9 张' : '添加照片'),
      ),
      body: photos.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.images,
                      size: 56,
                      color: AppColors.textDisabled,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '还没有照片\n第一张就是你的门面，认真选哦',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        height: 1.6,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: photos.length,
              itemBuilder: (context, i) {
                final isAvatar = photos[i]['isAvatar'] == 1;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                      child: CachedPhoto(url: photos[i]['url'].toString()),
                    ),
                    if (isAvatar)
                      Positioned(
                        left: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.photoScrim.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '门面',
                            style: TextStyle(fontSize: 10, color: Colors.white),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 2,
                      top: 2,
                      child: GestureDetector(
                        onTap: () => _delete(photos[i]['id'] as int),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppColors.photoScrim.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.chip),
                          onTap: () => isAvatar
                              ? null
                              : _setAvatar(photos[i]['id'] as int),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
