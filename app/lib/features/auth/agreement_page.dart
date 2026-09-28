import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../shared/widgets.dart';

/// 协议展示页（用户协议 / 隐私政策）
/// 上线前替换为法务审定的正式文案，并由 WebView 加载 H5 版本
class AgreementPage extends StatelessWidget {
  const AgreementPage({super.key, required this.title, required this.body});

  final String title;
  final String body;

  static const String userAgreement = '''
【用户协议】

1. 账号注册与安全
  1.1 本服务面向 18 周岁以上单身人士，注册即表示你确认已年满 18 周岁。
  1.2 账号仅限本人使用，禁止出借、转让。
  1.3 你应提供真实信息，因资料虚假导致的损失由本人承担。

2. 用户行为规范
  2.1 禁止发布违法、色情、暴力、诈骗等违规内容。
  2.2 禁止发布联系方式引流至第三方平台（社交展示卡功能除外）。
  2.3 平台对违规行为将视情节采取警告、禁言、封禁等处置措施。

3. 会员服务
  3.1 会员权益包括但不限于：无限喜欢、查看谁喜欢了你、高级筛选等。
  3.2 自动续费可随时取消，取消后权益保留至当期结束。

4. 账号注销
  4.1 你可随时申请注销，平台将依法删除或匿名化你的个人信息。

如有疑问请联系客服。
''';

  static const String privacyPolicy = '''
【隐私政策】

1. 我们收集的信息
  1.1 注册时收集手机号（加密存储，脱敏展示）。
  1.2 你主动填写的资料：昵称、头像、照片、城市、身高、职业等。
  1.3 使用服务时收集位置信息（可随时关闭精确定位）。

2. 信息的使用
  2.1 位置信息仅用于同城推荐与距离展示，开启"隐藏距离"后不再对外提供。
  2.2 照片与动态先审后发，未通过审核的内容不会公开展示。
  2.3 我们不会向第三方出售你的个人信息。

3. 信息的存储与保护
  3.1 手机号等敏感信息加密存储。
  3.2 你可以随时删除照片、动态或注销账号，注销后信息将匿名化。

4. 你的权利
  4.1 查询、更正、删除你的个人信息。
  4.2 撤回授权（如关闭位置权限）。

如有疑问请联系客服。
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(title: title),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(
          body,
          style: TextStyle(
              fontSize: 13.5, height: 1.8, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
