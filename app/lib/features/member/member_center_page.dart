import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/providers.dart';
import '../shared/widgets.dart';
import 'checkout_page.dart';

/// 会员中心：当前状态 + 权益矩阵 + 开通入口（设计文档 4.8）
class MemberCenterPage extends ConsumerWidget {
  const MemberCenterPage({super.key});

  static const _benefitRows = [
    ('每日喜欢次数', '30 次', '无限', '无限'),
    ('反悔（撤销喜欢/隐藏）', '—', '每日 5 次', '不限'),
    ('查看谁喜欢了我', '模糊展示', '完整列表', '列表+在线优先'),
    ('只看已认证', '—', '✓', '✓'),
    ('高级筛选（学历/职业/兴趣）', '—', '—', '✓'),
    ('推荐优先曝光', '—', '—', '✓'),
    ('隐身访问', '—', '—', '✓'),
    ('超级喜欢', '—', '每日 1 次', '每日 5 次'),
    ('消息已读回执', '—', '✓', '✓'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(membershipProvider);
    // 会员状态 + 商品价格均以后端为准
    final products = ref.watch(memberProductsProvider).valueOrNull ?? const [];
    final vipMonth = products.where(
      (p) => p.tier == MemberTier.vip && p.durationDays == 30,
    );
    final svipMonth = products.where(
      (p) => p.tier == MemberTier.svip && p.durationDays == 30,
    );
    final vipLabel = vipMonth.isNotEmpty
        ? '¥${yuan(vipMonth.first.effectivePriceCents)}/首月'
        : '';
    final svipLabel = svipMonth.isNotEmpty
        ? '¥${yuan(svipMonth.first.effectivePriceCents)}/首月'
        : '';

    return Scaffold(
      appBar: const GradientAppBar(title: '会员中心'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 当前状态：会员金卡质感（流光扫过）/ 非会员暗奢风
          SheenOverlay(
            borderRadius: cardRadius,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: membership.isMember
                    ? AppColors.goldGradient
                    : AppColors.darkCardGradient,
                borderRadius: BorderRadius.circular(cardRadius),
                boxShadow: membership.isMember
                    ? AppShadows.md
                    : AppShadows.card,
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      membership.isMember
                          ? LucideIcons.crown
                          : LucideIcons.crown,
                      color: membership.isMember
                          ? Colors.white
                          : AppColors.svipGold,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          membership.isMember
                              ? '${membership.tier.label} 会员'
                              : '免费用户',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          membership.isMember
                              ? '有效期至 ${_fmt(membership.expireAt)}'
                              : '升级会员，更快找到心仪的 Ta',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!membership.isMember)
                    Icon(
                      LucideIcons.chevronRight,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '权益对比',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: cardDecoration(),
            child: Column(
              children: [
                // 表头
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: brandColor.withValues(alpha: 0.05),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(cardRadius),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 14),
                      Expanded(
                        flex: 5,
                        child: Text(
                          '权益',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _colHeader('免费', 2, currentColumn: 0, myColumn: membership.tier == MemberTier.none ? 0 : -1),
                      _colHeader('VIP', 2, currentColumn: 1, myColumn: membership.tier == MemberTier.vip ? 1 : -1,
                        color: brandColor),
                      _colHeader('SVIP', 3, currentColumn: 2, myColumn: membership.tier == MemberTier.svip ? 2 : -1,
                        color: AppColors.warningText),
                    ],
                  ),
                ),
                for (var i = 0; i < _benefitRows.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      border: i < _benefitRows.length - 1
                          ? const Border(
                              bottom: BorderSide(color: Color(0xFFF3F4F6)),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 5,
                          child: Text(
                            _benefitRows[i].$1,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(child: _cell(_benefitRows[i].$2)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: _benefitRows[i].$3 == '✓'
                                ? Icon(LucideIcons.check,
                                    size: 14, color: brandColor)
                                : Text(
                                    _benefitRows[i].$3,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: _benefitRows[i].$3 == '—'
                                          ? AppColors.textDisabled
                                          : brandColor,
                                    ),
                                  ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Center(
                            child: _benefitRows[i].$4 == '✓'
                                ? Icon(LucideIcons.check,
                                    size: 14, color: AppColors.warningText)
                                : Text(
                                    _benefitRows[i].$4,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: _benefitRows[i].$4 == '—'
                                          ? AppColors.textDisabled
                                          : AppColors.warningText,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '价格为演示配置，正式版以管理后台下发为准',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.textDisabled),
          ),
          const SizedBox(height: 12),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: brandColor,
                    side: BorderSide(color: brandColor),
                    minimumSize: const Size(64, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: () => pushThrottled(
                    context,
                    const CheckoutPage(initialTier: MemberTier.vip),
                    tag: 'checkout-vip',
                  ),
                  child: Text(
                    membership.tier == MemberTier.vip
                        ? '续费 VIP'
                        : '开通 VIP ${vipLabel.isEmpty ? '' : vipLabel}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GradientButton(
                  gradient: AppColors.svipGradient,
                  glowColor: const Color(0x4718181B),
                  onPressed: () => pushThrottled(
                    context,
                    const CheckoutPage(initialTier: MemberTier.svip),
                    tag: 'checkout-svip',
                  ),
                  child: Text(
                    membership.tier == MemberTier.svip
                        ? '续费 SVIP'
                        : '开通 SVIP ${svipLabel.isEmpty ? '' : svipLabel}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.svipGold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 权益表表头：当前用户的档位列高亮
  Widget _colHeader(String label, int flex,
      {required int currentColumn, required int myColumn, Color? color}) {
    final mine = currentColumn == myColumn;
    return Expanded(
      flex: flex,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: mine
              ? BoxDecoration(
                  color: brandColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                )
              : null,
          child: Text(
            mine ? '$label (当前)' : label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: mine ? brandColor : (color ?? AppColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }

  /// 权益单元格：✓ 显示为图标勾，"—" 弱化
  Widget _cell(String text) {
    if (text == '✓') {
      return const Icon(
        LucideIcons.check,
        size: 14,
        color: brandColor,
      );
    }
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 11.5,
        color: text == '—' ? AppColors.textDisabled : AppColors.textPrimary,
        fontWeight: text == '—' ? FontWeight.w400 : FontWeight.w500,
      ),
    );
  }

  String _fmt(DateTime? t) => t == null
      ? ''
      : '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}
