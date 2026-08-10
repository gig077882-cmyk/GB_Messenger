import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_service.dart';
import '../../core/app_state.dart';
import '../../core/models.dart';
import '../../theme/app_theme.dart';
import '../../theme/widgets.dart';

class ChatInfoScreen extends StatefulWidget {
  final String chatId;
  const ChatInfoScreen({super.key, required this.chatId});

  @override
  State<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<ChatInfoScreen> {
  final ApiService _api = ApiService.instance;
  GbChat? _chat;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await _api.chat(widget.chatId);
      if (mounted) {
        setState(() {
          _chat = c;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = _chat;
    return Scaffold(
      appBar: AppBar(title: const Text('Информация о чате')),
      body: _loading || c == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 24),
                Center(
                  child: GBAvatar(
                    url: c.type == 'DIRECT'
                        ? c.peer(app.myId)?.avatarUrl
                        : c.avatarUrl,
                    name: c.title(app.myId),
                    size: 96,
                    showOnline: c.type == 'DIRECT',
                    online: c.peer(app.myId)?.isOnline ?? false,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    c.title(app.myId),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (c.type == 'DIRECT' && c.peer(app.myId) != null)
                  Center(
                    child: Text(
                      _peerStatus(c.peer(app.myId)!),
                      style: const TextStyle(
                        color: GBTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                if (c.type == 'GROUP') ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Участники (${c.members.length})',
                      style: TextStyle(
                        color: GBTheme.whatsAppGreen,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...c.members.map(
                    (m) => ListTile(
                      leading: GBAvatar(
                        url: m.user.avatarUrl,
                        name: m.user.displayName,
                        size: 42,
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              m.user.displayName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (m.role == 'admin') ...[
                            const SizedBox(width: 6),
                            const Text(
                              'admin',
                              style: TextStyle(
                                color: GBTheme.whatsAppGreen,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        m.user.email,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_off_outlined),
                  title: const Text('Без звука'),
                  trailing: Switch(
                    value: c.isMuted,
                    activeTrackColor: GBTheme.whatsAppGreen,
                    onChanged: (v) async {
                      await _api.patchChat(c.id, {'isMuted': v});
                      await _load();
                      app.refreshChats();
                    },
                  ),
                ),
                if (c.type == 'DIRECT' && c.peer(app.myId) != null)
                  ListTile(
                    leading: const Icon(Icons.block, color: Colors.red),
                    title: const Text(
                      'Заблокировать',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await _api.blockUser(c.peer(app.myId)!.id);
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Пользователь заблокирован'),
                        ),
                      );
                    },
                  ),
                if (c.type == 'GROUP')
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      'Покинуть группу',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () async {
                      await _api.leaveChat(widget.chatId);
                      await app.refreshChats();
                      if (context.mounted) {
                        Navigator.of(context).popUntil((r) => r.isFirst);
                      }
                    },
                  ),
              ],
            ),
    );
  }

  String _peerStatus(GbUser u) {
    if (u.isOnline) return 'в сети';
    final last = u.lastSeenAt;
    if (last == null) return 'был(а) недавно';
    return 'был(а) в сети: ${shortDate(last)}';
  }
}
