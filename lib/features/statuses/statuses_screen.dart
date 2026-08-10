import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api_service.dart';
import '../../core/app_state.dart';
import '../../core/config.dart';
import '../../core/models.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_scope.dart';
import '../../theme/widgets.dart';

class StatusesScreen extends StatefulWidget {
  const StatusesScreen({super.key});

  @override
  State<StatusesScreen> createState() => _StatusesScreenState();
}

class _StatusesScreenState extends State<StatusesScreen> {
  final ApiService _api = ApiService.instance;
  List<GbStatus> _feed = [];
  bool _loading = true;
  StreamSubscription? _subNew;

  @override
  void initState() {
    super.initState();
    _load();
    _subNew = context.read<AppState>().socket.onStatusNew.listen((s) {
      if (mounted) setState(() => _feed.insert(0, s));
    });
  }

  @override
  void dispose() {
    _subNew?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await _api.statusFeed();
      if (mounted) {
        setState(() {
          _feed = r;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addStatus() async {
    final p = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
    );
    if (p == null) return;
    final file = File(p.path);
    try {
      final pre = await _api.presign(
        fileName: p.name,
        mimeType: p.mimeType ?? 'image/jpeg',
        size: await file.length(),
      );
      await _api.uploadBytes(
        pre.uploadUrl,
        await file.readAsBytes(),
        p.mimeType ?? 'image/jpeg',
      );
      await _api.createStatus(
        mediaKey: pre.key,
        kind: 'IMAGE',
        mediaMeta: {'fileName': p.name},
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = ThemeScope.of(context);
    final mine = _feed.where((s) => s.userId == app.myId).toList();
    final others = _feed.where((s) => s.userId != app.myId).toList();
    return RefreshIndicator(
      color: GBTheme.whatsAppGreen,
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                ListTile(
                  leading: Stack(
                    children: [
                      GBAvatar(
                        url: app.me?.avatarUrl,
                        name: app.me?.displayName ?? '?',
                        size: 52,
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          decoration: BoxDecoration(
                            color: GBTheme.whatsAppGreen,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.theme.surface,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: Text(mine.isEmpty ? 'Мой статус' : 'Мой статус'),
                  subtitle: Text(
                    mine.isEmpty
                        ? 'Коснитесь, чтобы добавить обновление статуса'
                        : 'Обновлено ${shortDate(mine.first.createdAt)}',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  onTap: _addStatus,
                ),
                if (others.isEmpty)
                  const EmptyState(
                    icon: Icons.radio_button_checked,
                    title: 'Нет недавних обновлений',
                    subtitle: 'Нажмите, чтобы добавить статус',
                  ),
                ..._groupByUser(others).entries.map((e) {
                  final items = e.value;
                  final user = items.first.user;
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: GBTheme.whatsAppGreen,
                          width: 2,
                        ),
                      ),
                      child: GBAvatar(
                        url: user?.avatarUrl,
                        name: user?.displayName ?? '?',
                        size: 44,
                      ),
                    ),
                    title: Text(user?.displayName ?? ''),
                    subtitle: Text(
                      shortDate(items.first.createdAt),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    onTap: () => _openViewer(items),
                  );
                }),
              ],
            ),
    );
  }

  Map<String, List<GbStatus>> _groupByUser(List<GbStatus> list) {
    final map = <String, List<GbStatus>>{};
    for (final s in list) {
      map.putIfAbsent(s.userId, () => []).add(s);
    }
    return map;
  }

  void _openViewer(List<GbStatus> items) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StatusViewer(items: items, onViewed: _load),
      ),
    );
  }
}

class StatusViewer extends StatefulWidget {
  final List<GbStatus> items;
  final Future<void> Function() onViewed;
  const StatusViewer({super.key, required this.items, required this.onViewed});

  @override
  State<StatusViewer> createState() => _StatusViewerState();
}

class _StatusViewerState extends State<StatusViewer> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 6), () {
      if (_index < widget.items.length - 1) {
        setState(() => _index++);
        _start();
      } else {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.items[_index];
    final user = s.user;
    _markViewed(s);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _media(s),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: List.generate(
                      widget.items.length,
                      (i) => Expanded(
                        child: Container(
                          height: 2.5,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: i <= _index ? Colors.white : Colors.white30,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      GBAvatar(
                        url: user?.avatarUrl,
                        name: user?.displayName ?? '?',
                        size: 34,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        user?.displayName ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        shortDate(s.createdAt),
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (s.caption != null && s.caption!.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      s.caption!,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.3,
                        color: Colors.white,
                      ),
                    ),
                  ),
                const Spacer(),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.chevron_right,
                        color: Colors.white70,
                        size: 32,
                      ),
                      onPressed: () {
                        if (_index < widget.items.length - 1) {
                          setState(() => _index++);
                          _start();
                        } else {
                          Navigator.pop(context);
                        }
                      },
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

  Widget _media(GbStatus s) {
    final url = s.mediaUrl ?? '';
    final resolved = url.startsWith('http') ? url : '${AppConfig.apiBase}$url';
    return CachedNetworkImage(
      imageUrl: resolved,
      fit: BoxFit.contain,
      errorWidget: (_, _, _) => Center(
        child: Text(
          s.caption ?? 'Статус',
          style: const TextStyle(color: Colors.white70),
        ),
      ),
      placeholder: (_, _) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _markViewed(GbStatus s) {
    if (!s.viewerIds.contains('me')) {
      ApiService.instance.viewStatus(s.id).catchError((_) {});
      s.viewerIds.add('me');
      widget.onViewed();
    }
  }
}
