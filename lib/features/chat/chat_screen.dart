import 'dart:async';
import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api_service.dart';
import '../../core/app_state.dart';
import '../../core/models.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_scope.dart';
import '../../theme/widgets.dart';
import 'chat_repository.dart';
import 'chat_widgets.dart';
import 'models/local_message.dart';
import 'widgets/reaction_bar.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  const ChatScreen({super.key, required this.chatId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<GbMessage> _messages = [];
  final Set<String> _seenIds = <String>{};
  final Set<String> _typingUsers = {};
  GbChat? _chat;
  GbMessage? _replyTo;
  bool _loading = true;
  bool _sending = false;
  bool _typingSent = false;
  Timer? _typingDebounce;

  final ApiService _api = ApiService.instance;
  final ChatRepository _repo = ChatRepository();
  AppState? _app;
  StreamSubscription? _subMsg,
      _subUpd,
      _subDel,
      _subRead,
      _subTyping,
      _subChat,
      _subReaction;

  @override
  void initState() {
    super.initState();
    _app = context.read<AppState>();
    _app!.markChatOpened(widget.chatId);
    _load();
    _subscribe();
  }

  @override
  void dispose() {
    _subMsg?.cancel();
    _subUpd?.cancel();
    _subDel?.cancel();
    _subRead?.cancel();
    _subTyping?.cancel();
    _subChat?.cancel();
    _subReaction?.cancel();
    _typingDebounce?.cancel();
    _input.dispose();
    _scroll.dispose();
    _app?.setTypingLocal(widget.chatId, false);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final chat = await _api.chat(widget.chatId);
      final items = await _repo.loadChat(widget.chatId, limit: 50);
      debugPrint('[chat] loaded ${items.length} messages');
      if (mounted) {
        setState(() {
          _chat = chat;
          _messages.addAll(items);
          _loading = false;
        });
        _scrollToBottom(animated: false);
        _emitReadForVisible();
      }
    } catch (e, st) {
      debugPrint('[chat] load error: $e\n$st');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribe() {
    final s = _app!.socket;
    _subMsg = s.onMessageNew.listen(_onNew);
    _subUpd = s.onMessageUpdate.listen(_onUpdate);
    _subDel = s.onDelivered.listen((e) {
      if (e.chatId != widget.chatId) return;
      _repo.onDelivered(e.messageIds, widget.chatId);
      setState(() {
        for (final m in _messages) {
          if (e.messageIds.contains(m.id)) {
            m.localStatus = MessageStatus.delivered;
          }
        }
      });
    });
    _subRead = s.onRead.listen((e) {
      if (e.chatId != widget.chatId) return;
      setState(() {
        for (final m in _messages) {
          if (e.messageIds.contains(m.id) && m.senderId == _app!.myId) {
            m.localStatus = MessageStatus.read;
          }
        }
      });
    });
    _subTyping = s.onTyping.listen((t) {
      if (t.chatId != widget.chatId || t.userId == _app!.myId) return;
      setState(() {
        if (t.isTyping) {
          _typingUsers.add(t.userId);
        } else {
          _typingUsers.remove(t.userId);
        }
      });
    });
    _subChat = s.onChatUpdated.listen((c) {
      if (c.id == widget.chatId && mounted) setState(() => _chat = c);
    });
    _subReaction = s.onReaction.listen((e) {
      if (e.chatId != widget.chatId) return;
      _onReaction(e.messageId, e.userId, e.emoji, e.action);
    });
  }

  void _onReaction(
    String messageId,
    String userId,
    String? emoji,
    String action,
  ) {
    setState(() {
      for (final m in _messages) {
        if (m.id != messageId) continue;
        if (action == 'added' && emoji != null) {
          final updated = List<MessageReaction>.from(m.reactions);
          updated.removeWhere((r) => r.userId == userId);
          updated.add(MessageReaction(userId: userId, emoji: emoji));
          m.reactions = updated;
        } else if (action == 'removed') {
          m.reactions = m.reactions.where((r) => r.userId != userId).toList();
        }
      }
    });
  }

  void _onNew(GbMessage m) {
    if (m.chatId != widget.chatId) return;
    _repo.onMessageReceived(m);
    setState(() {
      if (_messages.any((e) => e.id == m.id)) return;
      if (m.senderId == _app!.myId &&
          _messages.any(
            (e) =>
                e.senderId == m.senderId &&
                e.type == m.type &&
                e.mediaKey == m.mediaKey &&
                e.createdAt.difference(m.createdAt).abs() <
                    const Duration(seconds: 3),
          )) {
        return;
      }
      _messages.add(_applyServerStatus(m));
      _sort();
    });
    _scrollToBottom();
    _app!.socket.emitRead(widget.chatId, [m.id]);
  }

  GbMessage _applyServerStatus(GbMessage m) {
    if (m.senderId != _app!.myId) return m;
    var read = false, delivered = false;
    for (final s in m.statuses) {
      if (s.userId == _app!.myId) continue;
      if (s.status == MessageStatus.read) read = true;
      if (s.status == MessageStatus.delivered) delivered = true;
    }
    return m.copyWith(
      localStatus: read
          ? MessageStatus.read
          : (delivered ? MessageStatus.delivered : MessageStatus.sent),
    );
  }

  void _onUpdate(GbMessage m) {
    if (m.chatId != widget.chatId) return;
    setState(() {
      final i = _messages.indexWhere((e) => e.id == m.id);
      if (i >= 0) {
        _messages[i] = m;
      } else {
        _messages.add(m);
        _sort();
      }
    });
  }

  void _sort() => _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

  void _emitReadForVisible() {
    final fresh = _messages
        .where((m) => m.senderId != _app!.myId && !_seenIds.contains(m.id))
        .toList();
    if (fresh.isEmpty) return;
    _seenIds.addAll(fresh.map((m) => m.id));
    _app!.socket.emitRead(widget.chatId, fresh.map((m) => m.id).toList());
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (animated) {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  Future<void> _send({
    String text = '',
    String? mediaKey,
    String? mediaUrl,
    String type = 'TEXT',
    Map<String, dynamic>? mediaMeta,
  }) async {
    if (_sending) return;
    final t = (text.isEmpty && mediaKey == null) ? null : text;
    if (t == null && mediaKey == null) return;
    _setTyping(false);
    setState(() => _sending = true);
    final local = GbMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      chatId: widget.chatId,
      senderId: _app!.myId,
      type: type,
      text: t ?? '',
      mediaKey: mediaKey,
      mediaUrl: mediaUrl,
      mediaMeta: mediaMeta,
      createdAt: DateTime.now(),
      localStatus: MessageStatus.sending,
    );
    setState(() {
      _messages.add(local);
      _sort();
    });
    _scrollToBottom();
    try {
      final saved = await _api.sendMessage(widget.chatId, {
        'type': type,
        if (t != null) ...{'text': t},
        if (mediaKey != null) ...{'mediaKey': mediaKey},
        if (mediaUrl != null) ...{'mediaUrl': mediaUrl},
        if (mediaMeta != null) ...{'mediaMeta': mediaMeta},
        if (_replyTo != null) 'replyToId': _replyTo!.id,
      });
      setState(() {
        final localIdx = _messages.indexWhere((e) => e.id == local.id);
        final serverIdx = _messages.indexWhere((e) => e.id == saved.id);
        if (serverIdx >= 0) {
          if (localIdx >= 0) _messages.removeAt(localIdx);
        } else if (localIdx >= 0) {
          _messages[localIdx] = _applyServerStatus(saved);
        }
      });
      if (mounted) setState(() => _replyTo = null);
    } catch (e) {
      final isNetworkError =
          e.toString().contains('SocketException') ||
          e.toString().contains('Connection') ||
          e.toString().contains('Timeout');
      if (isNetworkError && (t != null || mediaKey != null)) {
        await _repo.enqueuePending(
          LocalMessage(
            id: local.id,
            chatId: widget.chatId,
            senderId: _app!.myId,
            type: type,
            text: t,
            mediaKey: mediaKey,
            mediaUrl: mediaUrl,
            mediaMeta: mediaMeta,
            replyToId: _replyTo?.id,
            createdAt: local.createdAt,
          ),
        );
      }
      setState(() {
        final i = _messages.indexWhere((e) => e.id == local.id);
        if (i >= 0) {
          _messages[i] = local.copyWith(
            localStatus: isNetworkError
                ? MessageStatus.sending
                : MessageStatus.failed,
          );
        }
      });
    } finally {
      if (mounted) setState(() => _sending = false);
      _input.clear();
    }
  }

  void _setTyping(bool v) {
    if (_typingSent == v) return;
    _typingSent = v;
    _app!.setTypingLocal(widget.chatId, v);
  }

  void _onInputChanged(String _) {
    _typingDebounce?.cancel();
    if (_input.text.isNotEmpty) {
      _setTyping(true);
      _typingDebounce = Timer(
        const Duration(seconds: 2),
        () => _setTyping(false),
      );
    } else {
      _setTyping(false);
    }
  }

  Future<void> _pickImage() async {
    final p = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
    );
    if (p == null) return;
    final compressed = await _compressImage(p.path);
    await _uploadAndSend(
      compressed.path,
      p.name,
      p.mimeType ?? 'image/jpeg',
      'IMAGE',
    );
  }

  Future<void> _pickFile() async {
    final r = await FilePicker.pickFiles();
    if (r == null || r.files.isEmpty) return;
    final f = r.files.first;
    if (f.path == null) return;
    final isImage =
        f.extension != null &&
        [
          'jpg',
          'jpeg',
          'png',
          'gif',
          'webp',
          'heic',
        ].contains(f.extension!.toLowerCase());
    await _uploadAndSend(
      f.path!,
      f.name,
      f.extension == null
          ? 'application/octet-stream'
          : 'application/$f.extension',
      isImage ? 'IMAGE' : 'DOCUMENT',
    );
  }

  Future<File> _compressImage(String path) async {
    final dir = await getTemporaryDirectory();
    final targetPath =
        '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final result = await FlutterImageCompress.compressAndGetFile(
      path,
      targetPath,
      quality: 75,
      minWidth: 1280,
      minHeight: 1280,
    );
    return File(result?.path ?? path);
  }

  Future<void> _uploadAndSend(
    String path,
    String fileName,
    String mime,
    String type,
  ) async {
    final file = File(path);
    try {
      final size = await file.length();
      final pre = await _api.presign(
        fileName: fileName,
        mimeType: mime,
        size: size,
      );
      final bytes = await file.readAsBytes();
      await _api.uploadBytes(pre.uploadUrl, bytes, mime);
      await _send(
        mediaKey: pre.key,
        mediaUrl: pre.downloadUrl,
        type: type,
        mediaMeta: {'fileName': fileName, 'size': size, 'mimeType': mime},
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось отправить файл: $e')),
        );
      }
    }
  }

  Future<void> _sendVoiceMessage(String path, int durationMs, int size) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('Загрузка аудио...'),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
    try {
      final pre = await _api.presign(
        fileName: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
        mimeType: 'audio/m4a',
        size: size,
      );
      final file = File(path);
      await _api.uploadBytes(
        pre.uploadUrl,
        await file.readAsBytes(),
        'audio/m4a',
      );
      await _send(
        mediaKey: pre.key,
        mediaUrl: pre.downloadUrl,
        type: 'VOICE',
        mediaMeta: {
          'durationMs': durationMs,
          'size': size,
          'mimeType': 'audio/m4a',
        },
      );
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  void _onLongPress(GbMessage m) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF0F2F5),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.reply, color: GBTheme.whatsAppGreen),
              title: const Text('Ответить'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _replyTo = m);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.add_reaction,
                color: GBTheme.whatsAppGreen,
              ),
              title: const Text('Реакция'),
              onTap: () {
                Navigator.pop(ctx);
                _showReactionPicker(m);
              },
            ),
            if (m.text.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy, color: GBTheme.whatsAppGreen),
                title: const Text('Скопировать'),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: m.text));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Скопировано')));
                },
              ),
            ListTile(
              leading: const Icon(Icons.forward, color: GBTheme.whatsAppGreen),
              title: const Text('Переслать'),
              onTap: () {
                Navigator.pop(ctx);
                _forwardMessage(m);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.info_outline,
                color: GBTheme.whatsAppGreen,
              ),
              title: const Text('Инфо'),
              onTap: () {
                Navigator.pop(ctx);
                _showMessageInfo(m);
              },
            ),
            if (m.senderId == _app!.myId)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Удалить'),
                onTap: () {
                  Navigator.pop(ctx);
                  _api.deleteMessage(m.id);
                  if (mounted) {
                    setState(() => _messages.removeWhere((e) => e.id == m.id));
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showReactionPicker(GbMessage m) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ReactionPicker(
          message: m,
          myId: _app!.myId,
          onSelect: (emoji) {
            Navigator.pop(ctx);
            _api.addReaction(m.id, emoji);
            setState(() {
              m.reactions =
                  m.reactions.where((r) => r.userId != _app!.myId).toList()
                    ..add(MessageReaction(userId: _app!.myId, emoji: emoji));
            });
          },
        ),
      ),
    );
  }

  void _forwardMessage(GbMessage m) {
    Navigator.of(context).pushNamed('/new-chat', arguments: m);
  }

  void _showMessageInfo(GbMessage m) async {
    try {
      final info = await _api.messageInfo(m.id);
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        builder: (ctx) => _MessageInfoSheet(info: info),
      );
    } catch (_) {}
  }

  GbMessage? _pendingEdit;

  Future<void> _submitText() async {
    final t = _input.text.trim();
    if (t.isEmpty) return;
    if (_pendingEdit != null) {
      await _api.editMessage(_pendingEdit!.id, t);
      setState(() {
        final i = _messages.indexWhere((e) => e.id == _pendingEdit!.id);
        if (i >= 0) {
          _messages[i] = _messages[i].copyWith(
            localStatus: _messages[i].localStatus,
          );
        }
      });
      _pendingEdit = null;
      _input.clear();
      return;
    }
    await _send(text: t);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final peer = _chat?.peer(app.myId);
    final title = _chat?.title(app.myId) ?? 'Чат';
    final typingUser = _typingUsers.isEmpty ? null : _typingUsers.first;
    return Scaffold(
      backgroundColor: GBTheme.chatBg,
      appBar: AppBar(
        title: InkWell(
          onTap: () => Navigator.of(
            context,
          ).pushNamed('/chat-info', arguments: widget.chatId),
          child: Row(
            children: [
              GBAvatar(
                url: _chat?.type == 'DIRECT'
                    ? peer?.avatarUrl
                    : _chat?.avatarUrl,
                name: title,
                size: 36,
                showOnline: _chat?.type == 'DIRECT',
                online: peer?.isOnline ?? false,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    typingUser != null
                        ? 'печатает…'
                        : (peer?.isOnline == true ? 'в сети' : ''),
                    style: TextStyle(
                      color: typingUser != null
                          ? const Color(0xFFDCF8C6)
                          : Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.white),
            onPressed: () => Navigator.of(
              context,
            ).pushNamed('/call-screen', arguments: widget.chatId),
          ),
          IconButton(
            icon: const Icon(Icons.call, color: Colors.white),
            onPressed: () => Navigator.of(
              context,
            ).pushNamed('/call-screen', arguments: widget.chatId),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (v) {
              if (v == 'info') {
                Navigator.of(
                  context,
                ).pushNamed('/chat-info', arguments: widget.chatId);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'info',
                child: Text('Информация о чате'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.waving_hand_outlined,
                            size: 64,
                            color: GBTheme.chatBg.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Начни общение',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: GBTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Сообщения защищены TLS-соединением',
                            style: TextStyle(color: GBTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      final prev = i > 0 ? _messages[i - 1] : null;
                      final showDate =
                          prev == null ||
                          !_sameDay(prev.createdAt, m.createdAt);
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showDate) _DateHeader(date: m.createdAt),
                          Bubble(
                            message: m,
                            myId: app.myId,
                            showHeader:
                                prev == null || prev.senderId != m.senderId,
                            replyPreview: _replyPreview(m.replyToId),
                            onLongPress: () => _onLongPress(m),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          if (_replyTo != null)
            ReplyBar(
              message: _replyTo!,
              myId: app.myId,
              onCancel: () => setState(() => _replyTo = null),
            ),
          if (_pendingEdit != null)
            EditBar(onCancel: () => setState(() => _pendingEdit = null)),
          InputBar(
            controller: _input,
            onChanged: _onInputChanged,
            onSend: _submitText,
            sending: _sending,
            onImage: _pickImage,
            onFile: _pickFile,
            onVoiceResult: _sendVoiceMessage,
          ),
        ],
      ),
    );
  }

  GbMessage? _replyPreview(String? id) {
    if (id == null) return null;
    for (final m in _messages) {
      if (m.id == id) return m;
    }
    return null;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Bottom sheet с информацией о сообщении (delivered/read).
class _MessageInfoSheet extends StatelessWidget {
  final Map<String, dynamic> info;
  const _MessageInfoSheet({required this.info});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final deliveredTo = (info['deliveredTo'] as List?) ?? [];
    final readTo = (info['readTo'] as List?) ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Информация',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          _infoRow(
            Icons.check,
            'Отправлено',
            info['sentAt']?.toString() ?? '',
            theme,
          ),
          if (deliveredTo.isNotEmpty)
            _infoRow(
              Icons.done_all,
              'Доставлено',
              '${deliveredTo.length} получателям',
              theme,
            ),
          if (readTo.isNotEmpty)
            _infoRow(
              Icons.done_all,
              'Прочитано',
              '${readTo.length} получателям',
              theme,
            ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Закрыть',
              style: TextStyle(color: GBTheme.whatsAppGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value,
    ThemeProvider theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.theme.textHint),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Text(
            value,
            style: TextStyle(fontSize: 13, color: theme.theme.textHint),
          ),
        ],
      ),
    );
  }
}

/// Заголовок даты между сообщениями ("Сегодня", "Вчера", "12 марта").
class _DateHeader extends StatelessWidget {
  final DateTime date;
  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;

    String text;
    if (diff == 0) {
      text = 'Сегодня';
    } else if (diff == 1) {
      text = 'Вчера';
    } else if (diff < 7) {
      const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
      text = days[date.weekday - 1];
    } else {
      text = '${date.day} ${_monthName(date.month)}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.theme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: theme.theme.textHint,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _monthName(int m) => switch (m) {
    1 => 'янв',
    2 => 'фев',
    3 => 'мар',
    4 => 'апр',
    5 => 'мая',
    6 => 'июн',
    7 => 'июл',
    8 => 'авг',
    9 => 'сен',
    10 => 'окт',
    11 => 'ноя',
    12 => 'дек',
    _ => '',
  };
}
