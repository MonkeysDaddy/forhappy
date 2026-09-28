import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/api.dart';
import '../../api/api_client.dart';
import '../../core/dicts.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../shared/widgets.dart';

/// 编辑资料（后端 PUT /profile/me，全量提交：先读我的资料再合并）
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  bool _socialActive = false;
  String? _socialExpire;
  final List<Map<String, String>> _socialItems = [];
  bool _socialSaving = false;

  static const _socialPlatforms = ['微信', 'QQ', '小红书', 'Instagram', '微博'];

  Future<void> _loadSocial() async {
    try {
      final d = await Api.socialShowcase();
      if (!mounted) return;
      setState(() {
        _socialActive = d['active'] == true;
        _socialExpire = d['expireAt']?.toString();
        _socialItems
          ..clear()
          ..addAll((d['items'] as List)
              .map((e) => Map<String, String>.from(e as Map)));
      });
    } catch (_) {}
  }

  Future<void> _subscribeSocial() async {
    setState(() => _socialSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await Api.buySocialShowcase();
    if (!mounted) return;
    setState(() => _socialSaving = false);
    if (ok) {
      messenger.showSnackBar(const SnackBar(content: Text('社交展示卡已开通（30 天）')));
      await _loadSocial();
    } else {
      messenger.showSnackBar(const SnackBar(content: Text('暂无可用套餐')));
    }
  }

  Future<void> _saveSocial() async {
    if (_socialSaving) return;
    setState(() => _socialSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Api.saveSocialShowcase(_socialItems);
      messenger.showSnackBar(const SnackBar(content: Text('社交展示已保存')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.msg)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('保存失败')));
    } finally {
      if (mounted) setState(() => _socialSaving = false);
    }
  }

  final _nickname = TextEditingController();
  final _bio = TextEditingController();
  final _height = TextEditingController();
  final _occupation = TextEditingController();
  final _wechat = TextEditingController();
  final _instagram = TextEditingController();
  final _facebook = TextEditingController();

  Map<String, dynamic>? _profile;
  String _city = cities.first;
  String _education = '本科';
  String? _incomeCode;
  List<String> _tags = const [];
  bool _saving = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _loadSocial();
    final p = ref.read(myProfileProvider);
    if (p != null) {
      _fill(p);
    } else {
      Api.myProfile()
          .then((p) {
            if (mounted) {
              _fill(p);
              ref.read(myProfileProvider.notifier).state = p;
            }
          })
          .catchError((_) {});
    }
  }

  void _fill(Map<String, dynamic> p) {
    final tagsRaw = p['tags'];
    List<String> tags = const [];
    if (tagsRaw is List) {
      tags = tagsRaw.map((e) => e.toString()).toList();
    } else if (tagsRaw is String && tagsRaw.isNotEmpty) {
      try {
        tags = (jsonDecode(tagsRaw) as List).map((e) => e.toString()).toList();
      } catch (_) {}
    }
    final incomeRaw = p['income']?.toString();
    setState(() {
      _profile = p;
      _nickname.text = p['nickname']?.toString() ?? '';
      _bio.text = p['bio']?.toString() ?? '';
      _height.text = p['heightCm'] != null ? '${p['heightCm']}' : '';
      _occupation.text = p['occupation']?.toString() ?? '';
      _wechat.text = p['wechat']?.toString() ?? '';
      _instagram.text = p['instagram']?.toString() ?? '';
      _facebook.text = p['facebook']?.toString() ?? '';
      _city = cities.contains(p['city']) ? p['city'].toString() : cities.first;
      _education = educationOptions.contains(p['education'])
          ? p['education'].toString()
          : '本科';
      _incomeCode = incomeCodes.values.contains(incomeRaw) ? incomeRaw : null;
      _tags = tags;
    });
  }

  @override
  void dispose() {
    _nickname.dispose();
    _bio.dispose();
    _height.dispose();
    _occupation.dispose();
    _wechat.dispose();
    _instagram.dispose();
    _facebook.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nickname = _nickname.text.trim();
    if (nickname.isEmpty || nickname.length < 2) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('昵称至少 2 个字符')));
      return;
    }
    if (_tags.length > 8) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('兴趣标签最多 8 个')));
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      final merged = {
        ...?_profile,
        'nickname': nickname,
        'bio': _bio.text.trim(),
        'heightCm': int.tryParse(_height.text.trim()),
        'occupation': _occupation.text.trim(),
        'city': _city,
        'education': _education,
        'income': _incomeCode,
        'tags': jsonEncode(_tags),
        'wechat': _wechat.text.trim(),
        'instagram': _instagram.text.trim(),
        'facebook': _facebook.text.trim(),
      };
      await Api.updateProfile(merged);
      ApiClient.myNickname = nickname;
      ApiClient.myCity = _city;
      await ApiClient.saveSession();
      final me = await Api.myProfile();
      ref.read(myProfileProvider.notifier).state = me;
      ref.read(authInfoProvider.notifier).state =
          (ref.read(authInfoProvider) ??
                  AuthInfo(userId: ApiClient.myId ?? 0, nickname: nickname))
              .copyWith(nickname: nickname);
      ref.read(cityProvider.notifier).state = _city;
      ref.invalidate(feedProvider);
      ref.invalidate(matchesProvider);
      messenger.showSnackBar(const SnackBar(content: Text('资料已更新')));
      nav.pop();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.msg)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('保存失败，请检查后端服务')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 更换头像：相册选图 → 上传 → 登记为头像照片（isAvatar 同步 fh_user.avatar_url）
  Future<void> _changeAvatar() async {
    if (_uploadingAvatar) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 78,
        maxWidth: 600,
      );
      if (picked == null) return;
      if (!mounted) return;
      setState(() => _uploadingAvatar = true);
      final url = await Api.uploadFile(picked.path);
      if (url.isEmpty) throw ApiException(-1, '上传失败');
      await Api.addPhoto(url, isAvatar: true);
      ApiClient.myAvatar = url;
      await ApiClient.saveSession();
      final me = await Api.myProfile();
      if (!mounted) return;
      ref.read(myProfileProvider.notifier).state = me;
      setState(() => _profile = me);
      messenger.showSnackBar(const SnackBar(content: Text('头像已更新')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.msg)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('头像上传失败，请重试')));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: GradientAppBar(
        title: '编辑资料',
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving ? '保存中…' : '保存',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: _profile == null
          ? const Center(child: CircularProgressIndicator(color: brandColor))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _section('头像'),
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _changeAvatar,
                        child: Stack(
                          children: [
                            PersonAvatar(
                              url: ApiClient.myAvatar,
                              size: 88,
                              fallbackText: _nickname.text.isNotEmpty
                                  ? _nickname.text.characters.first
                                  : '我',
                            ),
                            if (_uploadingAvatar)
                              const Positioned.fill(
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: brandColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _uploadingAvatar ? '上传中…' : '点击更换头像',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                _section('基础信息'),
                _field(
                  '昵称',
                  TextField(
                    controller: _nickname,
                    maxLength: 12,
                    decoration: _deco('2-12 字符'),
                  ),
                ),
                _pickerTile(
                  '所在城市',
                  _city,
                  cities,
                  (v) => setState(() => _city = v),
                ),
                _pickerTile(
                  '学历',
                  _education,
                  educationOptions,
                  (v) => setState(() => _education = v),
                ),
                _pickerTile(
                  '年收入',
                  _incomeCode == null
                      ? '未填写'
                      : incomeCodes.entries
                            .firstWhere((e) => e.value == _incomeCode)
                            .key,
                  ['未填写', ...incomeCodes.keys],
                  (v) => setState(
                    () => _incomeCode = v == '未填写' ? null : incomeCodes[v],
                  ),
                ),
                _field(
                  '身高',
                  TextField(
                    controller: _height,
                    keyboardType: TextInputType.number,
                    decoration: _deco('cm，如 170'),
                  ),
                ),
                _field(
                  '职业',
                  TextField(
                    controller: _occupation,
                    decoration: _deco('如 产品经理'),
                  ),
                ),
                const SizedBox(height: 8),
                _section('兴趣标签（最多 8 个）'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in interestTagPresets)
                      FilterChip(
                        label: Text(t, style: const TextStyle(fontSize: 12.5)),
                        selected: _tags.contains(t),
                        onSelected: (on) => setState(() {
                          if (on && _tags.length >= 8) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('最多选 8 个标签')),
                            );
                            return;
                          }
                          _tags = on
                              ? [..._tags, t]
                              : _tags.where((x) => x != t).toList();
                        }),
                        selectedColor: brandColor.withValues(alpha: 0.12),
                        checkmarkColor: brandColor,
                        labelStyle: TextStyle(
                          color: _tags.contains(t)
                              ? brandColor
                              : Colors.black87,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _section('自我介绍'),
                TextField(
                  controller: _bio,
                  maxLines: 4,
                  maxLength: 200,
                  decoration: _deco('让别人更快了解你（≤200 字）', borderRadius: 12),
                ),
                _section('社交账号展示（社交展示卡·按月订阅）'),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    boxShadow: AppShadows.card,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_socialActive)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '开通社交展示卡（¥12/月），你的微信/QQ 等账号将展示在主页，'
                              '让心动的人主动找到你。未订阅或到期后自动隐藏。',
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.6,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            GradientButton(
                              height: 44,
                              onPressed: _socialSaving ? null : _subscribeSocial,
                              child: const Text('开通社交展示卡 · ¥12/月',
                                  style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        )
                      else ...[
                        Row(
                          children: [
                            const Icon(LucideIcons.badgeCheck,
                                size: 16, color: brandColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '展示中 · ${_socialExpire?.split("T").first ?? ""} 到期',
                                style: const TextStyle(
                                    fontSize: 12.5, color: brandColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        for (var i = 0; i < _socialItems.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 96,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _socialItems[i]['platform'],
                                    decoration: _deco('平台'),
                                    items: _socialPlatforms
                                        .map((p) => DropdownMenuItem(
                                            value: p,
                                            child: Text(p,
                                                style: const TextStyle(
                                                    fontSize: 13))))
                                        .toList(),
                                    onChanged: (v) => setState(
                                        () => _socialItems[i]['platform'] =
                                            v ?? '微信'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: TextEditingController(
                                        text: _socialItems[i]['account']),
                                    onChanged: (v) =>
                                        _socialItems[i]['account'] = v,
                                    decoration: _deco('账号'),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    LucideIcons.x,
                                    size: 16,
                                    color: AppColors.textTertiary,
                                  ),
                                  onPressed: () =>
                                      setState(() => _socialItems.removeAt(i)),
                                ),
                              ],
                            ),
                          ),
                        TextButton.icon(
                          onPressed: _socialItems.length >= 6
                              ? null
                              : () => setState(() => _socialItems.add(
                                  {'platform': '微信', 'account': ''})),
                          icon: const Icon(LucideIcons.plus, size: 15),
                          label: const Text('添加账号'),
                        ),
                        const SizedBox(height: 4),
                        GradientButton(
                          height: 44,
                          onPressed: _socialSaving ? null : _saveSocial,
                          child: _socialSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('保存社交展示',
                                  style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _section('联系方式（配对后对方可见）'),
                _field(
                  '微信号',
                  TextField(controller: _wechat, decoration: _deco('选填')),
                ),
                _field(
                  'Instagram',
                  TextField(controller: _instagram, decoration: _deco('选填')),
                ),
                _field(
                  'Facebook',
                  TextField(controller: _facebook, decoration: _deco('选填')),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 14, 0, 8),
    child: Text(
      title,
      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
    ),
  );

  Widget _field(String label, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 5),
          child: Text(
            label,
            style: TextStyle(fontSize: 12.5, color: AppColors.textTertiary),
          ),
        ),
        child,
      ],
    ),
  );

  InputDecoration _deco(String hint, {double borderRadius = 12}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13.5),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide.none,
        ),
      );

  Widget _pickerTile(
    String label,
    String value,
    List<String> options,
    void Function(String) onPick,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        dense: true,
        title: Text(label, style: const TextStyle(fontSize: 13.5)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 4),
            const Icon(
              LucideIcons.chevronDown,
              size: 18,
              color: Colors.black26,
            ),
          ],
        ),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final o in options)
                  ListTile(
                    title: Text(o, style: const TextStyle(fontSize: 14.5)),
                    trailing: o == value
                        ? const Icon(
                            LucideIcons.check,
                            size: 18,
                            color: brandColor,
                          )
                        : null,
                    onTap: () {
                      onPick(o);
                      Navigator.pop(sheetContext);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
