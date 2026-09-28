import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_client.dart';
import 'core/theme.dart';
import 'features/shell/home_shell.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 恢复上次登录会话（token 有效则免登录直接进主框架）
  await ApiClient.restoreSession();
  runApp(const ProviderScope(child: ForHappyApp()));
}

class ForHappyApp extends StatelessWidget {
  const ForHappyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // token 过期/无效（业务 401）→ 清会话回登录页
    ApiClient.onUnauthorized = () {
      final container = ProviderScope.containerOf(context, listen: false);
      container.read(authedProvider.notifier).state = false;
    };
    return MaterialApp(
      title: 'ForHappy',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      // AppColors 是静态开关：按"当前真正生效"的亮度设置（两套 Theme 同时构建，不能在构建时设）
      builder: (context, child) {
        AppColors.setScheme(
            dark: Theme.of(context).brightness == Brightness.dark);
        return child!;
      },
      home: const HomeShell(),
    );
  }
}
