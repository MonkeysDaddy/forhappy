import 'dart:ui' show Size;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:forhappy_app/main.dart';

/// UI 渲染冒烟（不依赖网络）。
/// 端到端的真实后端链路在模拟器上验证（后端 8080 + 登录/信息流/动态/会员已用 curl 验证）。
void main() {
  testWidgets('未登录时渲染登录页', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: ForHappyApp()));
    await tester.pump();

    expect(find.text('ForHappy'), findsOneWidget);
    expect(find.text('简单、快速、靠谱地遇见心动'), findsOneWidget);
    // 演示账号已预填
    expect(find.text('13800000100'), findsOneWidget);
    expect(find.text('123456'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
