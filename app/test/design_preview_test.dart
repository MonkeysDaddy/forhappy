import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:forhappy_app/core/theme.dart';
import 'package:forhappy_app/features/auth/login_page.dart';
import 'package:forhappy_app/features/discover/feed_views.dart';
import 'package:forhappy_app/models/models.dart';

/// 设计预览 Golden：离线渲染重设计后的发现页卡片（照片由本地桩提供）。
/// `flutter test --update-goldens` 生成/更新 goldens/*.png，供设计走查。
void main() {
  testWidgets('瀑布流卡片设计预览', (tester) async {
    HttpOverrides.global = _PhotoStubOverrides();
    tester.view.physicalSize = const Size(1170, 2200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme,
          home: Scaffold(
            backgroundColor: AppColors.appBg,
            body: WaterfallView(entries: _fakeEntries()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(WaterfallView),
      matchesGoldenFile('goldens/waterfall.png'),
    );
  });

  testWidgets('列表卡片设计预览', (tester) async {
    HttpOverrides.global = _PhotoStubOverrides();
    tester.view.physicalSize = const Size(1170, 2200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme,
          home: Scaffold(
            backgroundColor: AppColors.appBg,
            body: CardListView(entries: _fakeEntries()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(CardListView),
      matchesGoldenFile('goldens/list.png'),
    );
  });

  testWidgets('登录页设计预览', (tester) async {
    tester.view.physicalSize = const Size(1170, 2200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme,
          home: const LoginPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(LoginPage),
      matchesGoldenFile('goldens/login.png'),
    );
  });
}

List<FeedEntry> _fakeEntries() => [
  for (var i = 0; i < 6; i++)
    FeedEntry(
      person: PersonCard(
        id: i + 1,
        nickname: const ['豆腐脑', '夜航西飞', '徒步的猫', '山与风', '南音', '橘子汽水'][i],
        gender: Gender.female,
        age: 24 + i,
        city: '杭州',
        photos: ['https://stub.local/p$i.jpg'],
        occupation: const ['自由职业', '产品经理', '设计师', '教师', '医生', '运营'][i],
        bio: '带猫爬过 30 座山，目标 100 座。周末喜欢去西湖边散步拍照。',
        tags: const ['徒步', '露营', '摄影'],
        verified: i % 2 == 0,
        memberTier: i == 1
            ? MemberTier.svip
            : (i == 4 ? MemberTier.vip : MemberTier.none),
        wechat: i == 0 ? 'demo-wx' : null,
        lastActiveMinutes: i * 30,
      ),
      distanceKm: 0.6 + i * 1.7,
    ),
];

// ---------- 本地照片桩：任意 URL 返回按 URL 染色的纯色 PNG ----------

class _PhotoStubOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

class _FakeHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeRequest(url);
}

class _FakeRequest extends Fake implements HttpClientRequest {
  final Uri url;
  _FakeRequest(this.url);

  @override
  Future<HttpClientResponse> close() async => _FakeResponse(url);
}

const _palette = [
  [0xC9, 0x8A, 0x76], // 陶土
  [0x9A, 0xA5, 0xB0], // 雾灰蓝
  [0xB0, 0x8B, 0x9E], // 灰玫
  [0x8F, 0xA3, 0x8B], // 灰绿
  [0xC7, 0xB2, 0x8A], // 燕麦金
  [0xA8, 0x93, 0x8E], // 暖灰
];

class _FakeResponse extends Fake implements HttpClientResponse {
  final Uri url;
  _FakeResponse(this.url);

  @override
  int get statusCode => 200;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  int get contentLength => body.length;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    void Function()? onDone,
    bool? cancelOnError,
    Function? onError,
  }) {
    return Stream.value(body).listen(
      onData,
      onDone: onDone,
      onError: onError,
      cancelOnError: cancelOnError,
    );
  }

  late final List<int> body = _solidPng(_colorFor(url));

  static List<int> _colorFor(Uri url) =>
      _palette[url.toString().hashCode.abs() % _palette.length];
}

/// 生成 8x12 的纯色 PNG（BoxFit.cover 平铺后即为色卡）
List<int> _solidPng(List<int> rgb) {
  final w = 8, h = 12;
  final raw = <int>[];
  for (var y = 0; y < h; y++) {
    raw.add(0);
    for (var x = 0; x < w; x++) {
      raw.addAll(rgb);
    }
  }
  final z = ZLibCodec(level: 6).encode(raw);
  List<int> chunk(int len, List<int> type, List<int> data) {
    final body = [...type, ...data];
    final crc = _crc32(body);
    return [..._be32(len), ...body, ..._be32(crc)];
  }

  return Uint8List.fromList([
    ...[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
    ...chunk(
      13,
      [0x49, 0x48, 0x44, 0x52],
      [..._be32(w), ..._be32(h), 8, 2, 0, 0, 0],
    ),
    ...chunk(z.length, [0x49, 0x44, 0x41, 0x54], z),
    ...chunk(0, [0x49, 0x45, 0x4E, 0x44], const []),
  ]);
}

List<int> _be32(int v) => [
  (v >> 24) & 255,
  (v >> 16) & 255,
  (v >> 8) & 255,
  v & 255,
];

int _crc32(List<int> data) {
  var crc = 0xFFFFFFFF;
  for (final b in data) {
    crc ^= b;
    for (var k = 0; k < 8; k++) {
      crc = (crc & 1) != 0 ? (0xEDB88320 ^ (crc >> 1)) : (crc >> 1);
    }
  }
  return crc ^ 0xFFFFFFFF;
}
