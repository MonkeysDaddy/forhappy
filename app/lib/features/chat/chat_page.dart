import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';

import '../../api/api.dart';
import '../../api/api_client.dart';
import '../../core/theme.dart';
import '../../core/tracker.dart';
import '../../core/ws_service.dart';
import '../../models/models.dart';
import '../../state/providers.dart';
import '../discover/user_detail_page.dart';
import '../shared/icebreakers.dart';
import '../shared/report_sheet.dart';
import '../shared/widgets.dart';

/// 聊天页：真实后端消息（无模拟回复），破冰话术按人个性化
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({
    super.key,
    required this.conversation,
    this.initialMessage,
    this.icebreakers,
  });

  final Conversation conversation;

  /// 从配对弹窗点破冰话术进入时，自动发送的首条消息
  final String? initialMessage;

  /// 后端配对时计算的破冰话术（无则本地按对方资料生成）
  final List<String>? icebreakers;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage>
    with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  bool _aiLoading = false;
  bool _uploadingImage = false;
  bool _recording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  bool _sendingVoice = false;
  bool _showEmoji = false;
  final FocusNode _inputFocus = FocusNode();
  String? _playingKey;
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _voicePlayer = AudioPlayer();
  StreamSubscription? _playerSub;
  StreamSubscription<Map<String, dynamic>>? _wsSub;

  static const _emojis = [
    '😊',
    '😂',
    '🥰',
    '😍',
    '😘',
    '😜',
    '🤗',
    '🤔',
    '😎',
    '😭',
    '😅',
    '😴',
    '🥺',
    '😤',
    '😍',
    '🤩',
    '😇',
    '🙃',
    '😉',
    '🥳',
    '❤️',
    '💕',
    '💖',
    '🌹',
    '🌸',
    '🎀',
    '✨',
    '🔥',
    '👍',
    '🙏',
    '🍰',
    '☕',
    '🐶',
    '🐱',
    '🎬',
    '🎮',
    '🏃',
    '✈️',
    '🌙',
    '⭐',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    // 长连接实时收消息：对方发来即追加（无需退出重进）
    _wsSub = WsService.instance.frames.listen((frame) {
      // 已读回执：对方读了本会话 → 我发出的消息标记已读（VIP 可见）
      if (frame['type'] == 'read') {
        if ((frame['convId'] as num?)?.toInt() !=
            widget.conversation.convId) {
          return;
        }
        if (!mounted) return;
        final at =
            DateTime.tryParse(frame['readAt']?.toString() ?? '') ??
                DateTime.now();
        setState(() {
          _messages = [
            for (final m in _messages)
              if (m.fromMe && m.readAt == null) m.withRead(at) else m
          ];
        });
        return;
      }
      if (frame['type'] != 'message') return;
      if ((frame['convId'] as num?)?.toInt() != widget.conversation.convId) {
        return;
      }
      final msg = ApiClient.mapOf(frame['message']);
      final fromUser = (msg['fromUser'] as num?)?.toInt();
      if (fromUser == ApiClient.myId) return; // 自己的走 HTTP 回执
      if (!mounted) return;
      final incoming = ChatMessage(
        fromMe: false,
        text: msg['content']?.toString() ?? '',
        type: (msg['type'] as num?)?.toInt() ?? 1,
        time: DateTime.tryParse(msg['createdAt']?.toString() ?? ''),
        serverId: (msg['id'] as num?)?.toInt(),
      );
      setState(() => _messages = _mergeMessage(incoming));
      _scrollToBottom(force: false);
      Api.markRead(widget.conversation.convId!).catchError((_) {});
    });
  }

  @override
  void didChangeMetrics() {
    // 键盘弹出把视口压矮时回滚到底，保证打字时能看到最新消息
    final inset = MediaQuery.of(context).viewInsets.bottom;
    if (inset > 0) _scrollToBottom();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wsSub?.cancel();
    _playerSub?.cancel();
    _recordTimer?.cancel();
    _voicePlayer.dispose();
    _recorder.dispose();
    _inputFocus.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 按住说话/松开发送：录音 → 上传 → type=3 语音消息
  static const _voiceMaxSeconds = 60;

  Future<void> _toggleRecording() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_recording) {
      _recordTimer?.cancel();
      final path = await _recorder.stop();
      if (mounted) {
        setState(() {
          _recording = false;
          _sendingVoice = true;
        });
      }
      if (path == null) return;
      try {
        final url = await Api.uploadFile(path);
        if (url.isEmpty) throw Exception();
        await File(path).delete().catchError((_) => File(path));
        await _send(url, type: 3, urlOverride: url);
      } catch (_) {
        messenger.showSnackBar(const SnackBar(content: Text('语音发送失败')));
      } finally {
        if (mounted) setState(() => _sendingVoice = false);
      }
      return;
    }
    try {
      if (await _recorder.hasPermission()) {
        final path =
            '${Directory.systemTemp.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
        if (mounted) {
          setState(() {
            _recording = true;
            _recordSeconds = 0;
          });
          // 60 秒上限：到时自动停止并发送
          _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
            if (!mounted) return t.cancel();
            setState(() => _recordSeconds++);
            if (_recordSeconds >= _voiceMaxSeconds) {
              t.cancel();
              _toggleRecording();
            }
          });
        }
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('需要麦克风权限')));
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('录音启动失败')));
    }
  }

  /// 播放/停止语音气泡（setUrl 失败容错，避免未处理异常）
  Future<void> _toggleVoice(ChatMessage m) async {
    final messenger = ScaffoldMessenger.of(context);
    if (_playingKey == m.localKey) {
      await _voicePlayer.stop();
      if (mounted) setState(() => _playingKey = null);
      return;
    }
    _playerSub?.cancel();
    try {
      await _voicePlayer.setUrl(Api.fileUrl(m.text));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('语音加载失败')));
      return;
    }
    _playerSub = _voicePlayer.playerStateStream.listen((st) {
      if (st.processingState == ProcessingState.completed && mounted) {
        setState(() => _playingKey = null);
      }
    });
    await _voicePlayer.play();
    if (mounted) setState(() => _playingKey = m.localKey);
  }

  /// 由会话对方信息构造的轻量 PersonCard（破冰/资料页用）
  PersonCard get _peer {
    final c = widget.conversation;
    return PersonCard(
      id: c.personId,
      nickname: c.peerNickname ?? '对的人',
      gender: c.peerGender == 1 ? Gender.male : Gender.female,
      age: 0,
      city: '',
      photos: [if (c.peerAvatarUrl != null) c.peerAvatarUrl!],
      verified: c.peerVerified == 1,
    );
  }

  Future<void> _load() async {
    final convId = widget.conversation.convId;
    if (convId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final list = await Api.messages(convId, myId: ApiClient.myId ?? 0);
      if (!mounted) return;
      // 进入会话即告知对方"我已读"（REST 兜底，WS 不可达时也生效）
      Api.markRead(convId).catchError((_) {});
      // 与 WS 先到的消息按 id 合并，快照不覆盖实时帧
      setState(() {
        var merged = _messages;
        for (final m in list) {
          merged = _mergeMessage(m, base: merged);
        }
        _messages = merged;
      });
      _scrollToBottom();
      if (widget.initialMessage != null) {
        _send(widget.initialMessage!);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.msg)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom({bool force = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      // 用户上滑回看历史（离底 > 400px）时，WS 新消息不强拽
      final fromBottom = _scrollController.position.maxScrollExtent -
          _scrollController.offset;
      if (!force && fromBottom > 400) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  /// 选图发送（相册 → 上传 → type=2 消息；真实工程上传前压缩至长边1080/≤500KB）
  Future<void> _pickAndSendImage() async {
    if (_uploadingImage) return;
    final convId = widget.conversation.convId;
    if (convId == null) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 72,
        maxWidth: 1080,
      );
      if (picked == null) return;
      if (!mounted) return;
      setState(() => _uploadingImage = true);
      final url = await Api.uploadFile(picked.path);
      if (url.isEmpty) throw ApiException(-1, '上传失败');
      await _send(url, type: 2, urlOverride: url);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.msg)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('图片发送失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  /// 失败消息重试：文本回填输入框；图片/语音直接重发（先移除失败气泡）
  void _retryMessage(int i) {
    final m = _messages[i];
    setState(() => _messages = [..._messages]..removeAt(i));
    if (m.type == 1) {
      _controller.text = m.text;
      _controller.selection =
          TextSelection.collapsed(offset: m.text.length);
      _inputFocus.requestFocus();
    } else {
      _send(m.text, type: m.type, urlOverride: m.text);
    }
  }

  Future<void> _send(String text, {int type = 1, String? urlOverride}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sending) return;
    final convId = widget.conversation.convId;
    if (convId == null) return;
    // 图片消息本地展示用完整 URL，发送给后端的是相对路径
    final displayText = type == 2 && urlOverride != null
        ? urlOverride
        : trimmed;
    String payloadOf(String url) {
      final i = url.indexOf('/files/');
      return i >= 0 ? url.substring(i) : url;
    }

    final payload = type == 2 && urlOverride != null
        ? payloadOf(urlOverride)
        : trimmed;
    final pending = ChatMessage(fromMe: true, text: displayText, type: type);
    setState(() {
      _sending = true;
      _messages = [..._messages, pending];
    });
    if (type == 1) _controller.clear();
    _scrollToBottom();
    try {
      await Api.sendMessage(convId, payload, type: type);
      Tracker.log('message_send', {'type': type});
      // 会话列表同步最后一条消息
      ref.invalidate(conversationsProvider);
    } on ApiException catch (e) {
      if (mounted) {
        // 失败回滚：气泡置失败态（可重发），文本回填输入框
        setState(() {
          _messages = [
            for (final m in _messages)
              if (identical(m, pending)) pending.failedCopy() else m,
          ];
        });
        if (type == 1) {
          _controller.text = trimmed;
          _controller.selection = TextSelection.collapsed(
            offset: trimmed.length,
          );
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.msg)));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages = [
            for (final m in _messages)
              if (identical(m, pending)) pending.failedCopy() else m,
          ];
        });
        if (type == 1) {
          _controller.text = trimmed;
          _controller.selection = TextSelection.collapsed(
            offset: trimmed.length,
          );
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('发送失败，请检查网络')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// 已读角标：会员 + 我发出的最后一条已读消息
  bool _showReadReceipt(List<ChatMessage> messages, int i) {
    final tier = ref.watch(membershipProvider).tier;
    if (tier == MemberTier.none) return false;
    if (!messages[i].fromMe || messages[i].readAt == null) return false;
    // 只在"我最后一条已读消息"上显示，避免整列角标
    final lastReadFromMe = messages.lastIndexWhere(
        (m) => m.fromMe && m.readAt != null);
    return i == lastReadFromMe;
  }

  /// 聊天时间条：今天 HH:mm / 昨天 HH:mm / 周X HH:mm / MM-DD
  String _chatTimeLabel(DateTime t) {
    final now = DateTime.now();
    final hm =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final day = DateTime(t.year, t.month, t.day);
    final diff = DateTime(now.year, now.month, now.day).difference(day).inDays;
    if (diff == 0) return '今天 $hm';
    if (diff == 1) return '昨天 $hm';
    if (diff < 7) return '周${'一二三四五六日'[t.weekday - 1]} $hm';
    return '${t.month}/${t.day} $hm';
  }

  /// 空安全取首字符（昵称可能为空串）
  String? _firstChar(String? name) {
    if (name == null || name.isEmpty) return null;
    return name.characters.first;
  }

  /// WS 实时帧与 HTTP 快照按 serverId（退回 text+time+fromMe）去重合并
  List<ChatMessage> _mergeMessage(
    ChatMessage incoming, {
    List<ChatMessage>? base,
  }) {
    final list = [...(base ?? _messages)];
    bool exists;
    if (incoming.serverId != null) {
      exists = list.any((m) => m.serverId == incoming.serverId);
    } else {
      exists = list.any(
        (m) =>
            m.serverId == null &&
            m.fromMe == incoming.fromMe &&
            m.text == incoming.text &&
            m.time.difference(incoming.time).abs() < const Duration(seconds: 3),
      );
    }
    if (exists) return list;
    list.add(incoming);
    return list;
  }

  /// 拉黑后关闭聊天页（屏蔽即时生效：双向移出信息流并关闭会话，设计 6.3）
  Future<void> _blockAndLeave() async {
    await confirmAndBlock(context, ref, userId: _peer.id, name: _peer.nickname);
    if (mounted) Navigator.pop(context);
  }

  /// AI 回复建议：不知道怎么回时一键求助（后端拼装双方资料+聊天记录调大模型）
  Future<void> _showAiReplies() async {
    if (_aiLoading) return;
    final convId = widget.conversation.convId;
    if (convId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('会话同步中，稍后再试')));
      return;
    }
    setState(() => _aiLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final suggestion = await Api.aiReply(convId);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        gradient: brandGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.sparkles,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'AI 帮你回',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.black38,
                      ),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                if (suggestion.source != 'llm')
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'AI 服务未接入，以下是模板建议（配置 LLM_API_KEY 后自动升级）',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                for (final reply in suggestion.replies)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        _controller.text = reply;
                        _controller.selection = TextSelection.collapsed(
                          offset: reply.length,
                        );
                        Navigator.pop(sheetContext);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.hairline),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                reply,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              LucideIcons.penLine,
                              size: 15,
                              color: Colors.black26,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    '点击填入输入框，按自己的语气微调后发送更真诚',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.msg)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('AI 建议获取失败，请稍后再试')));
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  Future<void> _confirmUnmatch() async {
    final matchId = widget.conversation.matchId;
    if (matchId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('解除与 ${_peer.nickname} 的配对？'),
        content: const Text('解除后双方会话将被移除，且短期内不会再次互相推荐。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('解除配对'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await DiscoverActions.unmatch(ref, matchId);
        if (mounted) Navigator.pop(context);
      } on ApiException catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(e.msg)));
      } catch (_) {
        messenger.showSnackBar(const SnackBar(content: Text('操作失败，请稍后再试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _peer;

    return Scaffold(
      appBar: GradientAppBar(
        titleWidget: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.push(
            context,
            AppPageRoute(
              builder: (_) => UserDetailPage(personId: p.id, seed: p),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PersonAvatar(
                url: p.photos.isNotEmpty ? p.photos.first : null,
                size: 32,
                fallbackText: _firstChar(p.nickname) ?? '友',
              ),
              const SizedBox(width: 8),
              Text(
                p.nickname,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (p.verified) ...[
                const SizedBox(width: 4),
                const VerifiedBadge(size: 16),
              ],
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(LucideIcons.moreHorizontal, size: 20),
            onSelected: (v) {
              if (v == 'report') {
                showReportSheet(context, ref, userId: p.id, name: p.nickname);
              } else if (v == 'block') {
                _blockAndLeave();
              } else if (v == 'unmatch') {
                _confirmUnmatch();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'report', child: Text('举报')),
              PopupMenuItem(value: 'block', child: Text('拉黑')),
              PopupMenuItem(value: 'unmatch', child: Text('解除配对')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 安全提醒条（设计文档 4.5）
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.warningBg,
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.shieldCheck,
                    size: 15,
                    color: AppColors.warningIcon,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '谨防财物往来，线下见面请选择公共场所',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.warningText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: brandColor),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                      // 间隔 >5 分钟插入时间分隔条
                      final showTime = i == 0 ||
                          _messages[i].time
                                  .difference(_messages[i - 1].time)
                                  .inMinutes >
                              5;
                      return Column(
                        children: [
                          if (showTime)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 10),
                              child: Text(
                                _chatTimeLabel(_messages[i].time),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textTertiary),
                            ),
                            ),
                          _Bubble(
                        message: _messages[i],
                        voicePlaying: _playingKey == _messages[i].localKey,
                        onPlayVoice: () => _toggleVoice(_messages[i]),
                        onRetrySend: () => _retryMessage(i),
                        avatar:
                            i == 0 ||
                            (i > 0 &&
                                _messages[i - 1].fromMe != _messages[i].fromMe),
                        peerPhoto: p.photos.isNotEmpty ? p.photos.first : null,
                        peerName: p.nickname,
                        showRead: _showReadReceipt(_messages, i),
                      ),
                        ],
                      );
                      },
                    ),
            ),
            if (_messages.length <= 1 && !_loading) ...[
              // 新会话破冰提示（按人个性化，设计文档 4.6）
              SizedBox(
                height: 40,
                child: Builder(
                  builder: (context) {
                    final ices =
                        (widget.icebreakers != null &&
                            widget.icebreakers!.isNotEmpty)
                        ? widget.icebreakers!
                        : icebreakersFor(
                            _peer,
                            myTagsOf(ref),
                            myCity: ref
                                .read(myProfileProvider)?['city']
                                ?.toString(),
                          );
                    return ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final ice in ices)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              label: Text(
                                ice,
                                style: const TextStyle(fontSize: 12),
                              ),
                              backgroundColor: brandColor.withValues(
                                alpha: 0.06,
                              ),
                              onPressed: () => _send(ice),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (_recording)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                color: AppColors.error, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '正在录音 $_recordSeconds s（点■发送，最长 60s）',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (_showEmoji)
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    top: BorderSide(color: AppColors.hairline, width: 0.5),
                  ),
                ),
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                  ),
                  itemCount: _emojis.length,
                  itemBuilder: (context, i) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _controller.text += _emojis[i];
                      _controller.selection = TextSelection.collapsed(
                        offset: _controller.text.length,
                      );
                    },
                    child: Center(
                      child: Text(
                        _emojis[i],
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // AI 帮你回：不知道怎么接话时一键生成 3 条候选
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      style: IconButton.styleFrom(
                        backgroundColor: brandColor.withValues(alpha: 0.08),
                        foregroundColor: brandColor,
                      ),
                      tooltip: 'AI 帮你回',
                      onPressed: _aiLoading ? null : _showAiReplies,
                      icon: _aiLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: brandColor,
                              ),
                            )
                          : const Icon(LucideIcons.sparkles, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 发图（相册选图 → 上传 → type=2 消息）
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.textSecondary,
                      ),
                      tooltip: '发送图片',
                      onPressed: _uploadingImage ? null : _pickAndSendImage,
                      icon: _uploadingImage
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textTertiary,
                              ),
                            )
                          : const Icon(LucideIcons.image, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.fillCold,
                        foregroundColor: AppColors.textSecondary,
                      ),
                      tooltip: '表情',
                      onPressed: () => setState(() => _showEmoji = !_showEmoji),
                      icon: Icon(
                        LucideIcons.smile,
                        size: 20,
                        color: _showEmoji ? brandColor : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                      decoration: InputDecoration(
                        hintText: '说点什么…',
                        hintStyle: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: AppColors.fillCold,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton.filled(
                      onPressed: _sendingVoice ? null : _toggleRecording,
                      style: IconButton.styleFrom(
                        backgroundColor: _recording
                            ? AppColors.error
                            : brandColor,
                        foregroundColor: Colors.white,
                      ),
                      tooltip: _recording ? '停止并发送' : '录语音',
                      icon: Icon(
                        _recording ? LucideIcons.square : LucideIcons.mic,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : () => _send(_controller.text),
                    style: IconButton.styleFrom(
                      backgroundColor: brandColor,
                      foregroundColor: Colors.white,
                    ),
                    tooltip: '发送',
                    icon: const Icon(LucideIcons.send, size: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.avatar,
    required this.peerPhoto,
    required this.peerName,
    this.onRetrySend,
    this.voicePlaying = false,
    this.onPlayVoice,
    this.showRead = false,
  });

  final ChatMessage message;
  final bool avatar;
  final String? peerPhoto;
  final String peerName;

  /// 语音消息：是否播放中 + 点击回调
  final bool voicePlaying;
  final VoidCallback? onPlayVoice;

  /// 我最后一条已读消息（下方显示"已读"角标，VIP）
  final bool showRead;

  /// 失败消息点击重发：把文本回填输入框
  final VoidCallback? onRetrySend;

  @override
  Widget build(BuildContext context) {
    final fromMe = message.fromMe;
    return Padding(
      padding: EdgeInsets.only(bottom: showRead ? 16 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
        Row(
        mainAxisAlignment: fromMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!fromMe && avatar)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: PersonAvatar(
                url: peerPhoto,
                size: 34,
                fallbackText: peerName.isEmpty
                    ? '友'
                    : peerName.characters.first,
              ),
            ),
          if (!fromMe && !avatar) const SizedBox(width: 42),
          // 限宽 72%：长文本不成一整行，保持对话呼吸感（随屏宽自适应，小屏不溢出）
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: (MediaQuery.of(context).size.width * 0.72)
                  .clamp(200.0, 300.0),
            ),
            child: message.isVoice
                // 语音消息：播放/停止 + 声波示意
                ? GestureDetector(
                    onTap: onPlayVoice,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: fromMe ? brandGradient : null,
                        color: fromMe ? null : AppColors.surface,
                        border: fromMe
                            ? null
                            : Border.all(
                                color: AppColors.hairline, width: 0.5),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(14),
                          topRight: const Radius.circular(14),
                          bottomLeft: Radius.circular(fromMe ? 14 : 4),
                          bottomRight: Radius.circular(fromMe ? 4 : 14),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!fromMe) ...[
                            Icon(
                              voicePlaying
                                  ? Icons.stop_rounded
                                  : Icons.play_arrow_rounded,
                              size: 20,
                              color: brandColor,
                            ),
                            const SizedBox(width: 6),
                          ],
                          for (final h in [8.0, 14.0, 10.0, 16.0, 9.0])
                            Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 1.5),
                              width: 2.5,
                              height: h,
                              decoration: BoxDecoration(
                                color: (fromMe
                                        ? Colors.white70
                                        : brandColor.withValues(alpha: 0.5))
                                    .withValues(
                                        alpha: voicePlaying ? 1.0 : 0.55),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          if (fromMe) ...[
                            const SizedBox(width: 6),
                            Icon(
                              voicePlaying
                                  ? Icons.stop_rounded
                                  : Icons.play_arrow_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : message.isImage
                // 图片消息：圆角图片气泡，点击全屏查看
                ? GestureDetector(
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) => Dialog(
                        backgroundColor: Colors.transparent,
                        insetPadding: const EdgeInsets.all(16),
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: InteractiveViewer(
                            child: CachedPhoto(url: Api.fileUrl(message.text)),
                          ),
                        ),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 200,
                        height: 140,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedPhoto(url: Api.fileUrl(message.text)),
                            if (message.failed)
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: AppColors.error, width: 1.6),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            if (message.failed)
                              const Center(
                                child: Icon(
                                  Icons.error_outline_rounded,
                                  size: 30,
                                  color: AppColors.error,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: fromMe && !message.failed
                          ? brandGradient
                          : null,
                      color: fromMe && !message.failed
                          ? null
                          : message.failed
                          ? const Color(0x14DC2626)
                          : AppColors.surface,
                      border: fromMe
                          ? null
                          : Border.all(color: AppColors.hairline, width: 0.5),
                      boxShadow: fromMe
                          ? null
                          : const [
                              BoxShadow(
                                color: Color(0x0A1F2329),
                                blurRadius: 6,
                              ),
                            ],
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(14),
                        topRight: const Radius.circular(14),
                        bottomLeft: Radius.circular(fromMe ? 14 : 4),
                        bottomRight: Radius.circular(fromMe ? 4 : 14),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            message.text,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: message.failed
                                  ? AppColors.error
                                  : fromMe
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (message.failed) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: onRetrySend,
                            child: const Icon(
                              LucideIcons.refreshCw,
                              size: 15,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
        ),
        if (showRead)
          Padding(
            padding: const EdgeInsets.only(top: 3, right: 4),
            child: Text(
              '已读',
              style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}
