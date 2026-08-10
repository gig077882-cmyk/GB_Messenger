import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/config.dart';
import '../../core/api_service.dart';
import '../../theme/theme_scope.dart';
import 'media_viewer_screen.dart';

/// Галерея чата — все медиа-сообщения в сетке.
class ChatGalleryScreen extends StatefulWidget {
  final String chatId;
  const ChatGalleryScreen({super.key, required this.chatId});

  @override
  State<ChatGalleryScreen> createState() => _ChatGalleryScreenState();
}

class _ChatGalleryScreenState extends State<ChatGalleryScreen> {
  final ApiService _api = ApiService.instance;
  List<dynamic> _media = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final msgs = await _api.messages(widget.chatId, limit: 200);
      final media = msgs
          .where((m) => m.mediaKey != null && m.mediaUrl != null)
          .toList();
      if (mounted) {
        setState(() {
          _media = media;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Медиа чата')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _media.isEmpty
          ? const EmptyState(
              icon: Icons.photo_library_outlined,
              title: 'Нет медиа',
              subtitle: 'Фото и видео появятся هنا',
            )
          : GridView.builder(
              padding: const EdgeInsets.all(2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: _media.length,
              itemBuilder: (_, i) {
                final m = _media[i];
                final url = m.mediaUrl.startsWith('http')
                    ? m.mediaUrl
                    : '${AppConfig.apiBase}${m.mediaUrl}';
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          MediaViewerScreen(imageUrl: url, caption: m.text),
                    ),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        Container(color: theme.theme.surface),
                    errorWidget: (_, _, _) => Container(
                      color: theme.theme.surface,
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: theme.theme.stroke),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: TextStyle(color: theme.theme.textHint)),
          ],
        ],
      ),
    );
  }
}
