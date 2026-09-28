import 'package:flutter/material.dart';

/// ============================================================
/// 品牌色板 v3 —— 珊瑚蜜桃：象牙暖底 + 珊瑚红主色 + 香槟金点缀
/// （取代 v2 的酒红：更年轻、明亮、有活力，同时不荧光）
/// ============================================================

/// 主色：珊瑚红（明快、年轻、亲和）
const brandColor = Color(0xFFFF5A76);

/// 主渐变：蜜桃橙 → 珊瑚红（日出色调，有活力有纵深）
const brandGradient = LinearGradient(
  colors: [Color(0xFFFF8E7A), Color(0xFFFF4F6E)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// 分时渐变（头部专用，让 App "跟着天色走"）：
/// 清晨蜜桃 → 白天珊瑚 → 傍晚霞紫 → 深夜暗珊瑚（暗色模式整体再深一档）
LinearGradient headerGradientForNow({bool dark = false}) {
  final hour = DateTime.now().hour;
  LinearGradient pick() {
    if (hour >= 5 && hour < 10) {
      // 清晨也保持白字 3:1 以上对比度，起点不能过浅
      return const LinearGradient(
        colors: [Color(0xFFFB8A6C), Color(0xFFF5506E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (hour >= 10 && hour < 17) {
      return brandGradient;
    }
    if (hour >= 17 && hour < 20) {
      return const LinearGradient(
        colors: [Color(0xFFF5767E), Color(0xFFB85C98)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return const LinearGradient(
      colors: [Color(0xFFE8687F), Color(0xFFB23A62)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  final g = pick();
  if (!dark) return g;
  // 暗色模式：整体压深保持层次
  return LinearGradient(
    colors: [
      Color.lerp(g.colors[0], const Color(0xFF171315), 0.28)!,
      Color.lerp(g.colors[1], const Color(0xFF171315), 0.28)!,
    ],
    begin: g.begin,
    end: g.end,
  );
}

/// 语义色板 —— 全工程唯一色值定义处，页面一律引用 token。
/// 支持深色模式：启动时按系统亮度调用 [AppColors.setScheme]，
/// 之后所有 getter 返回当前亮/暗色板（页面引用方式不变）。
abstract final class AppColors {
  /// 当前是否暗色（启动/亮度变化时设置；false = 亮色象牙体系）
  static bool _dark = false;

  static bool get isDark => _dark;

  static void setScheme({required bool dark}) {
    if (_dark == dark) return;
    _dark = dark;
  }

  /// 亮/暗成对取值
  static Color _c(Color light, Color dark) => _dark ? dark : light;

  // 暖中性色（亮：象牙/暖灰；暗：暖炭/石墨）
  static Color get appBg =>
      _c(const Color(0xFFFAF7F5), const Color(0xFF171315));
  static Color get surface =>
      _c(const Color(0xFFFFFFFF), const Color(0xFF232022));
  static Color get fill => _c(const Color(0xFFF6F0ED), const Color(0xFF2C282A));
  static Color get divider =>
      _c(const Color(0xFFF1EAE7), const Color(0xFF35302F));
  static Color get hairline =>
      _c(const Color(0xFFEFE7E4), const Color(0xFF3A3433));
  static Color get textPrimary =>
      _c(const Color(0xFF2A2225), const Color(0xFFF0E8E6));
  static Color get textSecondary =>
      _c(const Color(0xFF75696D), const Color(0xFFB4A8AB));
  static Color get textTertiary =>
      _c(const Color(0xFFA2969A), const Color(0xFF877B7E));
  static Color get textDisabled =>
      _c(const Color(0xFFCDC4C6), const Color(0xFF5C5355));

  // 品牌刻度
  static Color get brand50 =>
      _c(const Color(0xFFFFF4F2), const Color(0xFF33262A)); // 图片占位/轻提示底
  static Color get brand100 =>
      _c(const Color(0xFFFFE4DE), const Color(0xFF4A3438));
  static Color get brand500 => brandColor;
  static Color get brand600 => const Color(0xFFE8456F);
  static Color get brandSoft =>
      _c(const Color(0x14FF5A76), const Color(0x2EFF5A76)); // 8% 主色，胶囊/CTA 浅底
  static Color get brandWash =>
      _c(const Color(0xFFFFF3F4), const Color(0xFF382A2E)); // 选中态洗色
  static Color get brandGlow => const Color(0x40FF4F6E); // CTA 柔光
  static Color get glowLight => const Color(0x54FF8E7A); // 庆祝场景光晕
  static Color get glowText => const Color(0x80FF8E7A); // 发光标题
  static Color get onDarkAccent => const Color(0xFFFFB3A3); // 暗底上的蜜桃文字

  // 冷灰填充（聊天输入底/信息行底）
  static Color get fillCold =>
      _c(const Color(0xFFF2F3F5), const Color(0xFF2A2729));

  // 照片暗角底色（瀑布流 scrim/详情页姓名浮层共用，亮暗一致）
  static const photoScrim = Color(0xFF1A1216);

  // 错误语义红（表单/发送失败）
  static const error = Color(0xFFDC2626);

  // 暗卡渐变（非会员状态卡，亮暗一致）
  static const darkCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2E3033), Color(0xFF17181A)],
  );

  // 语义色（各归各位，禁止串用，亮暗一致）
  static const verifiedBlue = Color(0xFF3B82F6);
  static const maleBlue = Color(0xFF5B8DEF);
  static const femalePink = Color(0xFFE0638C);
  static const wechatGreen = Color(0xFF22C55E);
  static const alipayBlue = Color(0xFF1677FF);
  static const facebookBlue = Color(0xFF1877F2);
  static const instagramPink = Color(0xFFE1306C);
  static Color get warningBg =>
      _c(const Color(0xFFFFF7E6), const Color(0xFF3A2F1B));
  static const warningIcon = Color(0xFFF59E0B);
  static Color get warningText =>
      _c(const Color(0xFFB45309), const Color(0xFFE8A33D));

  // 会员香槟金（全工程唯一版本）
  static const goldGradient = LinearGradient(
    colors: [Color(0xFFE0BE8C), Color(0xFFB9854C)],
  );
  static const svipGradient = LinearGradient(
    colors: [Color(0xFF4A4038), Color(0xFF211B16)],
  );
  static const svipGold = Color(0xFFE0BE8C);
}

/// 阴影三级（暖炭灰阴影色，压暖底不发脏）
/// v3：更轻更弥散——高级感来自"几乎看不见但立体"的阴影
abstract final class AppShadows {
  static const sm = [
    BoxShadow(color: Color(0x0A2A2225), blurRadius: 6, offset: Offset(0, 2)),
  ];
  static const md = [
    BoxShadow(color: Color(0x0F2A2225), blurRadius: 12, offset: Offset(0, 4)),
  ];
  static const lg = [
    BoxShadow(color: Color(0x1A2A2225), blurRadius: 28, offset: Offset(0, 10)),
  ];

  /// 卡片专用：轻弥散（替代旧 md，卡片不再"浮"在页面上而是"坐"在页面上）
  static const card = [
    BoxShadow(color: Color(0x082A2225), blurRadius: 10, offset: Offset(0, 2)),
  ];
}

/// 圆角四档：卡片 18 / 标签 10 / 弹窗 24 / 胶囊 Stadium
/// v3：卡片圆角加大（18），与大图圆角形成一致的"柔和几何"
abstract final class AppRadius {
  static const card = 18.0;
  static const chip = 10.0;
  static const dialog = 24.0;
}

/// 动效 token：全工程统一时长与曲线（v3）
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 380);
  static const easeOut = Curves.easeOutCubic;
  static const spring = Curves.easeOutBack;
}

/// 品牌展示字体（得意黑 Smiley Sans）：标题/大数字专用，正文仍用系统字
const brandDisplayFont = 'SmileySans';

/// 排版 token：字号/字重阶梯（v3，数字信息用 tabular 对齐更精致）
abstract final class AppType {
  static final display = TextStyle(
    fontFamily: brandDisplayFont,
    fontSize: 27,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );
  static final titleLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
  static final titleMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static final body = TextStyle(
    fontSize: 13.5,
    height: 1.5,
    color: AppColors.textPrimary,
  );
  static final caption = TextStyle(
    fontSize: 11.5,
    color: AppColors.textTertiary,
  );
}

/// 兼容旧引用
const cardRadius = AppRadius.card;

BoxDecoration cardDecoration({Color? color}) => BoxDecoration(
  color: color ?? AppColors.surface,
  borderRadius: BorderRadius.circular(AppRadius.card),
  boxShadow: AppShadows.card,
);

/// ============================================================
/// 全局主题（按亮度生成亮/暗两套；App 顶层根据系统亮度选择）
/// ============================================================
ThemeData buildAppTheme(Brightness brightness) {
  final snackBarBg = AppColors.isDark
      ? const Color(0xEB3A3336)
      : const Color(0xEB2A2225);
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: brandColor,
      brightness: brightness,
    ),
    scaffoldBackgroundColor: AppColors.appBg,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      titleTextStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: snackBarBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      contentTextStyle: const TextStyle(fontSize: 13, color: Colors.white),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.isDark
          ? const Color(0xEB232022)
          : const Color(0xEBFFFFFF),
      height: 62,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      indicatorColor: brandColor.withValues(alpha: 0.12),
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: brandColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
      ),
    ),
    chipTheme: const ChipThemeData(
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.chip)),
      ),
    ),
  );
}

/// 兼容旧引用（登录页等在 MaterialApp 之外的场合）
final appTheme = buildAppTheme(Brightness.light);

/// 统一页面转场：淡入 + 24px 上浮（比默认横向滑动更"轻"，与品牌动效曲线一致）
class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({required WidgetBuilder builder})
      : super(
          transitionDuration: AppMotion.normal,
          reverseTransitionDuration: AppMotion.fast,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
                parent: animation, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}
