import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config.dart';
import '../../core/models.dart';
import '../../core/voice_recorder.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_scope.dart';
import '../../theme/widgets.dart';
import 'media_viewer_screen.dart';
import 'widgets/formatting_toolbar.dart';
import 'widgets/reaction_bar.dart';

/// Пузырь сообщения в стиле WhatsApp.
class Bubble extends StatelessWidget {
  final GbMessage message;
  final String myId;
  final bool showHeader;
  final GbMessage? replyPreview;
  final VoidCallback onLongPress;

  const Bubble({
    super.key,
    required this.message,
    required this.myId,
    required this.showHeader,
    required this.replyPreview,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final mine = message.senderId == myId;
    return Padding(
      padding: EdgeInsets.only(
        top: showHeader ? 6 : 1,
        bottom: 1,
        left: 8,
        right: 8,
      ),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            margin: const EdgeInsets.symmetric(vertical: 1),
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
            decoration: BoxDecoration(
              color: mine ? theme.theme.bubbleMine : theme.theme.bubbleOther,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(mine ? 12 : 3),
                bottomRight: Radius.circular(mine ? 3 : 12),
              ),
              boxShadow: softShadow(opacity: 0.05),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.forwardedFrom != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Переслано от ${message.forwardedFrom!.displayName}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.theme.textHint,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                if (replyPreview != null) _replyBox(replyPreview!, theme),
                _content(context, theme),
                if (message.reactions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: ReactionBar(
                      message: message,
                      myId: myId,
                      onTapReaction: () {},
                    ),
                  ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      shortTime(message.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: mine
                            ? theme.theme.textHint.withValues(alpha: 0.8)
                            : theme.theme.textHint,
                      ),
                    ),
                    if (mine) ...[
                      const SizedBox(width: 3),
                      StatusTicks(status: message.localStatus, size: 11),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _replyBox(GbMessage reply, ThemeProvider theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(color: GBTheme.whatsAppGreen, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reply.senderId == myId ? 'Вы' : (reply.sender?.displayName ?? ''),
            style: const TextStyle(
              color: GBTheme.whatsAppGreen,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            reply.isDeleted ? 'Удалено' : reply.preview(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: theme.theme.textHint, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, ThemeProvider theme) {
    if (message.isDeleted) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, size: 14, color: GBTheme.textSecondary),
            SizedBox(width: 4),
            Text(
              'Сообщение удалено',
              style: TextStyle(
                color: GBTheme.textSecondary,
                fontStyle: FontStyle.italic,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    switch (message.type) {
      case 'IMAGE':
        return _mediaPreview(context, theme);
      case 'VOICE':
      case 'AUDIO':
        return _voiceTile(context, theme);
      case 'DOCUMENT':
        return _docTile(theme);
      case 'CALL':
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.call, size: 14, color: GBTheme.textSecondary),
            SizedBox(width: 6),
            Text(
              'Звонок',
              style: TextStyle(color: GBTheme.textSecondary, fontSize: 14),
            ),
          ],
        );
      default:
        return _formattedText(message.text, theme);
    }
  }

  Widget _formattedText(String text, ThemeProvider theme) {
    final spans = <TextSpan>[];
    final regex = RegExp(
      r'(\*\*\*(.+?)\*\*\*|\*\*(?!\s)(.+?)(?<!\s)\*\*|\*(?!\s)(.+?)(?<!\s)\*|~~(.+?)~~|`(.+?)`|([^*~`]+))',
    );
    final matches = regex.allMatches(text);
    for (final m in matches) {
      if (m.group(2) != null) {
        // ***bold+italic***
        spans.add(
          TextSpan(
            text: m.group(2),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              color: theme.theme.textOther,
              fontSize: 14.5,
              height: 1.35,
            ),
          ),
        );
      } else if (m.group(3) != null) {
        // **bold**
        spans.add(
          TextSpan(
            text: m.group(3),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.theme.textOther,
              fontSize: 14.5,
              height: 1.35,
            ),
          ),
        );
      } else if (m.group(4) != null) {
        // *italic*
        spans.add(
          TextSpan(
            text: m.group(4),
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: theme.theme.textOther,
              fontSize: 14.5,
              height: 1.35,
            ),
          ),
        );
      } else if (m.group(5) != null) {
        // ~~strike~~
        spans.add(
          TextSpan(
            text: m.group(5),
            style: TextStyle(
              decoration: TextDecoration.lineThrough,
              color: theme.theme.textOther,
              fontSize: 14.5,
              height: 1.35,
            ),
          ),
        );
      } else if (m.group(6) != null) {
        // `mono`
        spans.add(
          TextSpan(
            text: m.group(6),
            style: TextStyle(
              fontFamily: 'monospace',
              backgroundColor: theme.theme.stroke.withValues(alpha: 0.3),
              color: theme.theme.textOther,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        );
      } else if (m.group(7) != null) {
        spans.add(
          TextSpan(
            text: m.group(7),
            style: TextStyle(
              color: theme.theme.textOther,
              fontSize: 14.5,
              height: 1.35,
            ),
          ),
        );
      }
    }
    if (spans.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 14.5,
          height: 1.35,
          color: theme.theme.textOther,
        ),
      );
    }
    return RichText(text: TextSpan(children: spans), maxLines: null);
  }

  Widget _mediaPreview(BuildContext context, ThemeProvider theme) {
    final url = message.mediaUrl ?? '';
    final resolved = url.startsWith('http') ? url : '${AppConfig.apiBase}$url';
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MediaViewerScreen(
            imageUrl: resolved,
            caption: message.text.isEmpty ? null : message.text,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 220,
          child: MediaCachedImage(
            url: resolved,
            cacheKey: message.mediaKey ?? message.id,
            width: 220,
            height: 180,
            theme: theme,
          ),
        ),
      ),
    );
  }

  Widget _voiceTile(BuildContext context, ThemeProvider theme) {
    final meta = message.mediaMeta;
    final dur = (meta?['durationMs'] as num?)?.toDouble() ?? 30000.0;
    final url = message.mediaUrl ?? '';
    final resolved = url.startsWith('http') ? url : '${AppConfig.apiBase}$url';
    return _VoiceBubble(
      url: resolved,
      durationMs: dur,
      theme: theme,
      isMine: message.senderId == myId,
    );
  }

  Widget _docTile(ThemeProvider theme) {
    final name = (message.mediaMeta?['fileName'] ?? 'Документ') as String;
    final size = (message.mediaMeta?['size'] as num?)?.toInt() ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: GBTheme.whatsAppGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.insert_drive_file,
            color: GBTheme.whatsAppGreen,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              fileSize(size),
              style: TextStyle(color: theme.theme.textHint, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}

class ReplyBar extends StatelessWidget {
  final GbMessage message;
  final String myId;
  final VoidCallback onCancel;
  const ReplyBar({
    super.key,
    required this.message,
    required this.myId,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      color: theme.theme.surface,
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      child: Row(
        children: [
          Container(width: 3, height: 34, color: GBTheme.whatsAppGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.senderId == myId
                      ? 'Вы'
                      : (message.sender?.displayName ?? ''),
                  style: const TextStyle(
                    color: GBTheme.whatsAppGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  message.preview(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.theme.textHint, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: theme.theme.textHint),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

class EditBar extends StatelessWidget {
  final VoidCallback onCancel;
  const EditBar({super.key, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      color: theme.theme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Container(width: 3, height: 26, color: GBTheme.whatsAppGreen),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Редактирование…',
              style: TextStyle(color: GBTheme.whatsAppGreen, fontSize: 13),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: theme.theme.textHint),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

class InputBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onImage;
  final VoidCallback onFile;
  final void Function(String path, int durationMs, int size) onVoiceResult;
  final bool sending;

  const InputBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onSend,
    required this.onImage,
    required this.onFile,
    required this.onVoiceResult,
    required this.sending,
  });

  @override
  State<InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<InputBar>
    with SingleTickerProviderStateMixin {
  bool _showFormat = false;
  final _focusNode = FocusNode();
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  bool _isCancelRecording = false;
  double _dragOffset = 0;
  double _audioLevel = 0.0;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    widget.controller.addListener(_onTextChanged);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  void _onFocusChanged() {
    if (mounted) {
      setState(() {
        _showFormat = _focusNode.hasFocus && widget.controller.text.isNotEmpty;
      });
    }
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {
        _showFormat = _focusNode.hasFocus && widget.controller.text.isNotEmpty;
      });
    }
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;
    final recorder = VoiceRecorder.instance;
    final messenger = ScaffoldMessenger.of(context);
    final focusScope = FocusScope.of(context);
    if (!await recorder.hasPermission()) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Нужно разрешение на микрофон')),
      );
      return;
    }
    focusScope.unfocus();
    await recorder.start();
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isRecording = true;
      _recordingSeconds = 1;
      _isCancelRecording = false;
      _dragOffset = 0;
      _audioLevel = 0.0;
    });
    _pulseController.repeat(reverse: true);
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (
      _,
    ) async {
      if (!mounted) return;
      final level = await recorder.getAmplitude();
      if (mounted) setState(() => _audioLevel = level.current.clamp(0.0, 1.0));
    });
    _maxTimer = Timer(const Duration(seconds: 60), () {
      if (mounted && _isRecording) _stopRecording();
    });
  }

  Timer? _maxTimer;

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    widget.controller.removeListener(_onTextChanged);
    _recordingTimer?.cancel();
    _maxTimer?.cancel();
    _pulseController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _maxTimer?.cancel();
    _maxTimer = null;
    _pulseController.stop();
    _pulseController.reset();
    final recorder = VoiceRecorder.instance;
    final wasCancelled = _isCancelRecording;
    VoiceResult? result;
    try {
      result = wasCancelled ? null : await recorder.stop();
    } catch (_) {
      await recorder.cancel();
    }
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
      _isCancelRecording = false;
      _dragOffset = 0;
      _audioLevel = 0.0;
    });
    if (wasCancelled) {
      HapticFeedback.lightImpact();
    } else if (result != null && result.durationMs > 500) {
      HapticFeedback.lightImpact();
      widget.onVoiceResult(result.path, result.durationMs, result.size);
    } else if (result != null) {
      await recorder.deleteFile(result.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Запись слишком короткая')),
        );
      }
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _maxTimer?.cancel();
    _maxTimer = null;
    _pulseController.stop();
    _pulseController.reset();
    await VoiceRecorder.instance.cancel();
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
      _isCancelRecording = false;
      _dragOffset = 0;
      _audioLevel = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final hasText = widget.controller.text.trim().isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showFormat)
          FormattingToolbar(
            controller: widget.controller,
            onChanged: () => setState(() {}),
          ),
        Container(
          padding: EdgeInsets.only(
            left: 8,
            right: 8,
            top: 6,
            bottom: 6 + MediaQuery.of(context).padding.bottom,
          ),
          decoration: BoxDecoration(
            color: theme.theme.surface,
            border: Border(
              top: BorderSide(color: theme.theme.stroke, width: 0.4),
            ),
          ),
          child: _isRecording
              ? _buildRecordingRow(theme)
              : _buildInputRow(theme, hasText),
        ),
      ],
    );
  }

  Widget _buildInputRow(ThemeProvider theme, bool hasText) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 120),
            decoration: BoxDecoration(
              color: theme.theme.bg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: theme.theme.stroke.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.emoji_emotions_outlined,
                    color: theme.theme.textHint,
                    size: 24,
                  ),
                  onPressed: () {},
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    onChanged: widget.onChanged,
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Сообщение',
                      hintStyle: TextStyle(color: theme.theme.textHint),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 4,
                      ),
                    ),
                  ),
                ),
                if (!hasText)
                  IconButton(
                    icon: Icon(
                      Icons.camera_alt_outlined,
                      color: theme.theme.textHint,
                      size: 24,
                    ),
                    onPressed: widget.onImage,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                IconButton(
                  icon: Icon(
                    Icons.attach_file,
                    color: theme.theme.textHint,
                    size: 24,
                  ),
                  onPressed: widget.onFile,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 44,
          height: 44,
          child: Material(
            color: GBTheme.whatsAppGreen,
            borderRadius: BorderRadius.circular(22),
            elevation: 2,
            child: Tooltip(
              message: hasText ? 'Отправить' : 'Зажмите для записи',
              child: GestureDetector(
                onTap: hasText ? widget.onSend : null,
                onLongPressStart: hasText ? null : (_) => _startRecording(),
                onLongPressEnd: hasText ? null : (_) => _stopRecording(),
                onLongPressMoveUpdate: hasText
                    ? null
                    : (details) {
                        setState(() {
                          _dragOffset = details.localOffsetFromOrigin.dx;
                          _isCancelRecording = _dragOffset < -60;
                        });
                      },
                onLongPressCancel: () => _cancelRecording(),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    hasText ? Icons.send_rounded : Icons.mic_none_rounded,
                    key: ValueKey(hasText),
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingRow(ThemeProvider theme) {
    final mins = (_recordingSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_recordingSeconds % 60).toString().padLeft(2, '0');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          icon: Icon(Icons.delete_outline, color: theme.theme.danger, size: 24),
          onPressed: _cancelRecording,
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: theme.theme.bg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: GBTheme.whatsAppGreen.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                ScaleTransition(
                  scale: Tween<double>(
                    begin: 0.8,
                    end: 1.2,
                  ).animate(_pulseController),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _isCancelRecording
                          ? Colors.red
                          : GBTheme.whatsAppGreen,
                      shape: BoxShape.circle,
                      boxShadow: _isCancelRecording
                          ? null
                          : glow(color: GBTheme.whatsAppGreen, blur: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$mins:$secs',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.theme.textMain,
                  ),
                ),
                const SizedBox(width: 8),
                _AudioLevelBars(
                  level: _audioLevel,
                  color: _isCancelRecording
                      ? Colors.red
                      : GBTheme.whatsAppGreen,
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isCancelRecording
                      ? Icon(
                          Icons.arrow_back_ios,
                          size: 14,
                          key: const ValueKey('cancel'),
                          color: Colors.red.withValues(alpha: 0.7),
                        )
                      : Icon(
                          Icons.arrow_back_ios,
                          size: 14,
                          key: const ValueKey('slide'),
                          color: theme.theme.textHint.withValues(alpha: 0.5),
                        ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _isCancelRecording
                          ? 'Отпустите для отмены'
                          : 'Slide to cancel',
                      key: ValueKey(_isCancelRecording),
                      style: TextStyle(
                        fontSize: 12,
                        color: _isCancelRecording
                            ? Colors.red
                            : theme.theme.textHint,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _isCancelRecording ? Colors.red : GBTheme.whatsAppGreen,
            borderRadius: BorderRadius.circular(22),
            boxShadow: softShadow(opacity: 0.2),
          ),
          child: Icon(Icons.mic, color: Colors.white, size: 22),
        ),
      ],
    );
  }
}

class _AudioLevelBars extends StatelessWidget {
  final double level;
  final Color color;
  const _AudioLevelBars({required this.level, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(5, (i) {
          final threshold = (i + 1) / 5.0;
          final active = level >= threshold - 0.2;
          final height = 4.0 + i * 3.0;
          return Container(
            width: 3,
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: active ? color : color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(1),
            ),
          );
        }),
      ),
    );
  }
}

/// Голосовое сообщение с воспроизведением и waveform.
class _VoiceBubble extends StatefulWidget {
  final String url;
  final double durationMs;
  final ThemeProvider theme;
  final bool isMine;
  const _VoiceBubble({
    required this.url,
    required this.durationMs,
    required this.theme,
    required this.isMine,
  });

  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  final VoicePlayer _player = VoicePlayer.instance;
  bool _playing = false;
  bool _hasError = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _subChange;
  StreamSubscription? _subComplete;

  @override
  void initState() {
    super.initState();
    _duration = Duration(milliseconds: widget.durationMs.toInt());
    _subChange = _player.onStateChange.listen((s) {
      if (s.url != widget.url && s.url.isNotEmpty) return;
      if (mounted) {
        setState(() {
          _playing = s.isPlaying;
          _position = s.position ?? Duration.zero;
          _duration = s.duration ?? _duration;
          if (s.isPlaying) _hasError = false;
        });
      }
    });
    _subComplete = _player.onComplete.listen((url) {
      if (url == widget.url || url.isEmpty) {
        if (mounted) {
          setState(() {
            _playing = false;
            _position = Duration.zero;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _subChange?.cancel();
    _subComplete?.cancel();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
    } else {
      try {
        await _player.play(widget.url);
      } catch (_) {
        if (mounted) setState(() => _hasError = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return SizedBox(
      width: 220,
      child: Row(
        children: [
          InkWell(
            onTap: _toggle,
            child: Icon(
              _hasError
                  ? Icons.error_outline
                  : (_playing
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill),
              color: _hasError ? Colors.red : GBTheme.whatsAppGreen,
              size: 32,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _waveform(theme),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _hasError
                          ? 'Ошибка воспроизведения'
                          : _formatDuration(_position),
                      style: TextStyle(
                        fontSize: 10,
                        color: _hasError ? Colors.red : theme.theme.textHint,
                      ),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.theme.textHint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _waveform(ThemeProvider theme) {
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;
    return Container(
      height: 28,
      alignment: Alignment.center,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(28, (i) {
          final seed = (i * 7919) % 13;
          final barH = 4 + (seed % 10) * 2.0;
          final filled = i / 28 < progress;
          return Container(
            width: 2.5,
            height: barH,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: filled ? GBTheme.whatsAppGreen : theme.theme.stroke,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
