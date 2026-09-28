import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../api/api.dart';
import '../../api/api_client.dart';
import '../../core/theme.dart';
import '../shared/widgets.dart';
import '../../core/dicts.dart';
import '../../state/providers.dart';

/// 城市选择页（移动端全屏列表：顶部当前定位 + 重新定位，下方城市列表）
class CitySelectPage extends ConsumerStatefulWidget {
  const CitySelectPage({super.key});

  @override
  ConsumerState<CitySelectPage> createState() => _CitySelectPageState();
}

class _CitySelectPageState extends ConsumerState<CitySelectPage> {
  bool _locating = false;

  /// 真实 GPS 定位（设计 3.2）：请求权限 → 取坐标 → 上报后端（反解最近城市）。
  /// 拒绝授权时降级提示手动选城市，不影响基础浏览。
  Future<void> _relocate() async {
    if (_locating) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('未授权定位，已降级为手动选城市'),
            duration: Duration(milliseconds: 1200),
          ),
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
      // 上报坐标 → 后端更新 lat/lng 并反解城市
      final city = await Api.reportLocation(
        position.latitude,
        position.longitude,
      );
      final resolved = city.isNotEmpty
          ? city
          : (ApiClient.myCity ?? cities.first);
      if (!mounted) return;
      ApiClient.myCity = resolved;
      await ApiClient.saveSession();
      ref.read(locatedCityProvider.notifier).state = resolved;
      ref.read(cityProvider.notifier).state = resolved;
      messenger.showSnackBar(
        SnackBar(
          content: Text('已更新定位：$resolved'),
          duration: const Duration(milliseconds: 900),
        ),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.msg)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('定位失败，请检查系统定位服务'),
          duration: Duration(milliseconds: 1200),
        ),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(cityProvider);
    final located = ref.watch(locatedCityProvider);

    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: const GradientAppBar(title: '选择城市'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 当前定位
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(cardRadius),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.locateFixed, size: 20, color: brandColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '当前定位',
                        style: TextStyle(fontSize: 11, color: Colors.black45),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        located,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                _locating
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: brandColor,
                        ),
                      )
                    : OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: brandColor,
                          side: BorderSide(
                            color: brandColor.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onPressed: _relocate,
                        icon: const Icon(LucideIcons.locate, size: 15),
                        label: const Text(
                          '重新定位',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '城市列表',
              style: TextStyle(fontSize: 13, color: Colors.black45),
            ),
          ),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(cardRadius),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < cities.length; i++) ...[
                  ListTile(
                    leading: Icon(
                      LucideIcons.mapPin,
                      size: 20,
                      color: cities[i] == current ? brandColor : Colors.black38,
                    ),
                    title: Text(
                      cities[i],
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: cities[i] == current
                            ? FontWeight.w700
                            : FontWeight.normal,
                        color: cities[i] == current
                            ? brandColor
                            : Colors.black87,
                      ),
                    ),
                    trailing: cities[i] == current
                        ? Icon(LucideIcons.check, size: 20, color: brandColor)
                        : null,
                    onTap: () {
                      ref.read(cityProvider.notifier).state = cities[i];
                      Navigator.pop(context);
                    },
                  ),
                  if (i < cities.length - 1)
                    Divider(
                      height: 1,
                      indent: 56,
                      color: AppColors.divider,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
