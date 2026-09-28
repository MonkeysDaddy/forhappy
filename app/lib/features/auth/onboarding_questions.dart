import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../../api/api_client.dart';
import '../../core/dicts.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../shared/widgets.dart';

/// 注册引导三问（设计 3.1 步骤2）：性别 / 想看谁 / 出生年份
/// 必须完成后才能进入发现页（PopScope 禁止跳过）
class OnboardingQuestionsPage extends ConsumerStatefulWidget {
  const OnboardingQuestionsPage({super.key});

  @override
  ConsumerState<OnboardingQuestionsPage> createState() =>
      _OnboardingQuestionsPageState();
}

class _OnboardingQuestionsPageState
    extends ConsumerState<OnboardingQuestionsPage> {
  int _step = 0;
  int? _gender; // 1男 2女
  int? _prefer; // 1男 2女 3都看
  int _birthYear = DateTime.now().year - 24;
  bool _submitting = false;
  String? _error;

  final int _minYear = DateTime.now().year - 18;

  late final FixedExtentScrollController _yearController =
      FixedExtentScrollController(initialItem: _minYear - _birthYear);

  @override
  void dispose() {
    _yearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),
                // 步骤指示
                Row(
                  children: [
                    for (var i = 0; i < 3; i++)
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                          height: 4,
                          decoration: BoxDecoration(
                            color: i <= _step ? brandColor : AppColors.divider,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 36),
                AnimatedSize(
                  duration: AppMotion.fast,
                  curve: AppMotion.easeOut,
                  alignment: Alignment.topLeft,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _buildStep(),
                  ),
                ),
                const Spacer(),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    onPressed: _submitting ? null : _next,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _step == 2 ? '完成，开始发现' : '下一步',
                            key: ValueKey(_step),
                          ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return Column(
          key: const ValueKey(0),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('你是？', style: _titleStyle),
            const SizedBox(height: 8),
            Text(
              '仅用于配对展示，注册后不可修改',
              style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                _optionCard(1, '男生', Icons.male),
                const SizedBox(width: 14),
                _optionCard(2, '女生', Icons.female),
              ],
            ),
          ],
        );
      case 1:
        return Column(
          key: const ValueKey(1),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('想认识？', style: _titleStyle),
            const SizedBox(height: 8),
            Text(
              '决定你的卡片池，之后可在设置中调整',
              style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                _optionCard(1, '男生', Icons.male),
                const SizedBox(width: 14),
                _optionCard(2, '女生', Icons.female),
              ],
            ),
            const SizedBox(height: 14),
            _optionCardWide(3, '都看看', LucideIcons.infinity),
          ],
        );
      default:
        return Column(
          key: const ValueKey(2),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('你出生在哪一年？', style: _titleStyle),
            const SizedBox(height: 8),
            Text(
              '未满 18 岁不能使用本应用',
              style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: CupertinoPicker(
                scrollController: _yearController,
                itemExtent: 42,
                selectionOverlay: Container(
                  decoration: BoxDecoration(
                    border: Border.symmetric(
                      horizontal: BorderSide(
                        color: brandColor.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
                onSelectedItemChanged: (i) => _birthYear = _minYear - i,
                children: [
                  for (var y = _minYear; y >= _minYear - 60; y--)
                    Center(
                      child: Text(
                        '$y 年 · ${DateTime.now().year - y} 岁',
                        style: const TextStyle(fontSize: 17),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
    }
  }

  static const _titleStyle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
  );

  int? get _currentSelection => _step == 0 ? _gender : _prefer;

  Widget _optionCard(int value, String label, IconData icon) {
    final selected = _currentSelection == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _step == 0 ? _gender = value : _prefer = value);
        },
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(vertical: 26),
          decoration: BoxDecoration(
            color: selected ? AppColors.brand50 : AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? brandColor : Colors.transparent,
              width: 1.6,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 38,
                color: selected ? brandColor : AppColors.textTertiary,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: selected ? brandColor : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionCardWide(int value, String label, IconData icon) {
    final selected = _currentSelection == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _prefer = value);
      },
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.brand50 : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? brandColor : Colors.transparent,
            width: 1.6,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? brandColor : AppColors.textTertiary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: selected ? brandColor : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _next() async {
    if (_step == 0 && _gender == null) {
      setState(() => _error = '请选择你的性别');
      return;
    }
    if (_step == 1 && _prefer == null) {
      setState(() => _error = '请选择想认识的人');
      return;
    }
    if (_step < 2) {
      HapticFeedback.selectionClick();
      setState(() {
        _step++;
        _error = null;
      });
      return;
    }
    // 提交 onboarding（城市取我的资料城市，默认杭州）
    setState(() {
      _submitting = true;
      _error = null;
    });
    final city = (ApiClient.myCity != null && ApiClient.myCity!.isNotEmpty)
        ? ApiClient.myCity!
        : cities.first;
    try {
      await Api.onboarding(
        gender: _gender!,
        preferGender: _prefer!,
        birthYear: _birthYear,
        city: city,
      );
      ApiClient.onboarded = true;
      await ApiClient.saveSession();
      ref.read(authInfoProvider.notifier).state =
          (ref.read(authInfoProvider) ??
                  AuthInfo(userId: ApiClient.myId ?? 0, nickname: '我'))
              .copyWith(onboarded: true);
      ref.read(cityProvider.notifier).state = city;
      ref.read(locatedCityProvider.notifier).state = city;
      ref.invalidate(feedProvider);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() {
        _error = e.msg;
        _submitting = false;
      });
    } catch (_) {
      setState(() {
        _error = '提交失败，请检查后端服务';
        _submitting = false;
      });
    }
  }
}
