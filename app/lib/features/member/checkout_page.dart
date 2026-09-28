import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../../api/api_client.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/providers.dart';
import '../shared/widgets.dart';

/// 会员收银台：商品与金额来自后端 /member/products，下单支付走真实接口
class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key, required this.initialTier});

  final MemberTier initialTier;

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

enum _PayChannel { wechat, alipay, apple }

extension on _PayChannel {
  int get backendCode => switch (this) {
    _PayChannel.wechat => 1,
    _PayChannel.alipay => 2,
    _PayChannel.apple => 3,
  };
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  late MemberTier _tier = widget.initialTier;
  MemberProduct? _selected;
  _PayChannel _channel = _PayChannel.wechat;
  bool _agreed = false;
  bool _paying = false;

  MemberProduct? _effectiveSelected(List<MemberProduct> products) {
    if (products.isEmpty) return null;
    if (_selected != null && _selected!.tier == _tier) return _selected;
    return products.firstWhere(
      (p) => p.durationDays == 30,
      orElse: () => products.first,
    );
  }

  Future<void> _pay(MemberProduct selected) async {
    if (!_agreed) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先勾选同意自动续费协议')));
      return;
    }
    setState(() => _paying = true);
    try {
      final orderNo = await Api.createOrder(
        selected.id,
        channel: _channel.backendCode,
      );
      final result = await Api.payOrder(orderNo);
      if (!mounted) return;
      final tierInt = (result['tier'] as num?)?.toInt() ?? 1;
      final newTier = tierInt == 2 ? MemberTier.svip : MemberTier.vip;
      final expireAt = DateTime.tryParse(result['expireAt']?.toString() ?? '');
      ref.read(membershipProvider.notifier).activate(newTier, expireAt);
      setState(() => _paying = false);
      await _showSuccess(selected);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _paying = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.msg)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _paying = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('支付失败，请检查后端服务')));
      }
    }
  }

  Future<void> _showSuccess(MemberProduct selected) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Icon(LucideIcons.circleCheck, size: 64, color: brandColor),
            const SizedBox(height: 12),
            const GradientText(
              '开通成功！',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              '已激活 ${_tier.label} · ${selected.durationLabel}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('开始使用'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(memberProductsProvider);
    final products = productsAsync.valueOrNull
            ?.where((p) => p.tier == _tier)
            .toList() ??
        const [];
    final selected = _effectiveSelected(products);

    return PopScope(
      // 支付进行中禁止返回：防止成功回调被 !mounted 吞掉（钱付了会员没激活）
      canPop: !_paying,
      child: Scaffold(
        appBar: const GradientAppBar(title: '开通会员'),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // hero 区：情绪 + 价值主张（SVIP 档用金色，与会员卡一致）
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: _tier == MemberTier.svip
                        ? AppColors.svipGradient
                        : brandGradient,
                    borderRadius: BorderRadius.circular(cardRadius),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brandGlow,
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '解锁心动特权',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '无限喜欢 · 查看谁喜欢了我 · 高级筛选',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xCCFFFFFF),
                        ),
                      ),
                    ],
                  ),
                ),
                // 档位切换
                Center(
                  child: SegmentedButton<MemberTier>(
                    segments: const [
                      ButtonSegment(value: MemberTier.vip, label: Text('VIP')),
                      ButtonSegment(
                        value: MemberTier.svip,
                        label: Text('SVIP'),
                      ),
                    ],
                    selected: {_tier},
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: brandColor.withValues(
                        alpha: 0.12,
                      ),
                      selectedForegroundColor: brandColor,
                    ),
                    onSelectionChanged: (s) {
                      setState(() {
                        _tier = s.first;
                        _selected = null;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // 商品列表（价格来自后端 /member/products）
                if (products.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        '商品加载中…（请确认后端已启动）',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                for (final p in products)
                  GestureDetector(
                    onTap: () => setState(() => _selected = p),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selected != null && selected.id == p.id
                            ? AppColors.brandWash
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(cardRadius),
                        border: Border.all(
                          color: selected != null && selected.id == p.id
                              ? brandColor
                              : AppColors.divider,
                          width: selected != null && selected.id == p.id
                              ? 2
                              : 1,
                        ),
                        boxShadow: selected != null && selected.id == p.id
                            ? const [
                                BoxShadow(
                                  color: Color(0x1FE8456F),
                                  blurRadius: 12,
                                  offset: Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected != null && selected.id == p.id
                                ? LucideIcons.circleDot
                                : LucideIcons.circle,
                            color: selected != null && selected.id == p.id
                                ? brandColor
                                : AppColors.textDisabled,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '${_tier.label} ${p.durationLabel}',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (p.badge != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: brandGradient,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          p.badge!,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (p.durationDays == 365)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Text(
                                      '日均 ¥${(p.effectivePriceCents / 100 / 365).toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '¥${yuan(p.effectivePriceCents)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: brandColor,
                                ),
                              ),
                              if (p.originalCents != null &&
                                  p.originalCents != p.effectivePriceCents)
                                Text(
                                  '¥${yuan(p.originalCents!)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black38,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                // 支付方式
                const Text(
                  '支付方式',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: cardDecoration(),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(
                      children: [
                        _channelTile(
                          _PayChannel.wechat,
                          '微信支付',
                          '微',
                          const Color(0xFF22C55E),
                        ),
                        Divider(
                          height: 1,
                          indent: 52,
                          color: AppColors.divider,
                        ),
                        _channelTile(
                          _PayChannel.alipay,
                          '支付宝',
                          '支',
                          const Color(0xFF3B82F6),
                        ),
                        Divider(
                          height: 1,
                          indent: 52,
                          color: AppColors.divider,
                        ),
                        _channelTile(
                          _PayChannel.apple,
                          'Apple Pay（iOS IAP）',
                          '',
                          Colors.black87,
                        ),
                      ],
                    ),
                  ),
                ),
                // 协议勾选框放在固定支付栏内（见底部），此处仅留白
                const SizedBox(height: 160),
              ],
            ),
            // 底部支付栏
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 协议勾选放在固定栏内，任何窗口高度下都可见可点
                      Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _agreed,
                              onChanged: (v) =>
                                  setState(() => _agreed = v ?? false),
                              activeColor: brandColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '已阅读并同意《会员服务协议》与《自动续费协议》（续费前 5 日将提醒，可随时取消）',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      const TextSpan(
                                        text: '合计 ',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      TextSpan(
                                        text:
                                            '¥${yuan(selected?.effectivePriceCents ?? 0)}',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: brandColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${_tier.label} ${selected?.durationLabel ?? ''} · 到期自动续费',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton(
                            onPressed: _paying || selected == null
                                ? null
                                : () => _pay(selected),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(140, 48),
                            ),
                            child: _paying
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('立即支付'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _channelTile(
    _PayChannel channel,
    String title,
    String badgeText,
    Color badgeColor,
  ) {
    return ListTile(
      dense: true,
      leading: badgeText.isEmpty
          ? const Icon(Icons.apple, size: 22, color: Colors.black87)
          : Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                badgeText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
      title: Text(title, style: const TextStyle(fontSize: 13.5)),
      trailing: Icon(
        _channel == channel ? LucideIcons.circleDot : LucideIcons.circle,
        color: _channel == channel ? brandColor : AppColors.textDisabled,
        size: 20,
      ),
      onTap: () => setState(() => _channel = channel),
    );
  }
}
