import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/api.dart';
import '../../api/api_client.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../shared/widgets.dart';

/// 真人认证中心：上传自拍照完成认证（演示版自动通过；徽章点亮后推荐加权）
/// 正式版：机审（人像质量/活体）+ 人审，展示审核中状态
class VerifyCenterPage extends ConsumerStatefulWidget {
  const VerifyCenterPage({super.key});

  @override
  ConsumerState<VerifyCenterPage> createState() => _VerifyCenterPageState();
}

class _VerifyCenterPageState extends ConsumerState<VerifyCenterPage> {
  bool _busy = false;

  bool get _verified {
    final user = ref.read(myProfileProvider)?['user'];
    return user is Map && user['verified'] == 1;
  }

  Future<void> _submit() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final url = await Api.uploadFile(picked.path);
      if (url.isEmpty) throw Exception();
      await Api.verify(url);
      // 刷新本地资料，让徽章立即点亮
      final me = await Api.myProfile();
      ApiClient.myProfile = me;
      if (mounted) ref.read(myProfileProvider.notifier).state = me;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('认证通过！你的资料会获得更多曝光'),
          duration: Duration(milliseconds: 1500),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('认证失败，请重试')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final verified = _verified;
    return Scaffold(
      appBar: const GradientAppBar(title: '真人认证'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: verified ? AppColors.brandSoft : AppColors.fill,
                shape: BoxShape.circle,
              ),
              child: Icon(
                verified ? LucideIcons.badgeCheck : LucideIcons.userSearch,
                size: 48,
                color: verified ? brandColor : AppColors.textTertiary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              verified ? '你已通过真人认证' : '完成真人认证',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            verified
                ? '你的资料带有认证徽章，被喜欢的概率显著更高。'
                : '上传一张清晰的本人自拍，通过后资料将带有认证徽章。\n认证信息仅用于审核，不会展示在资料页。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.7,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 28),
          if (!verified)
            GradientButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      '拍摄自拍照认证',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: cardDecoration(color: AppColors.fill),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '认证须知',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 8),
                Text(
                  '· 本人真实自拍，不接受网络图片\n'
                  '· 认证后无法自行取消\n'
                  '· 资料造假可能被他人举报冻结',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.9,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
