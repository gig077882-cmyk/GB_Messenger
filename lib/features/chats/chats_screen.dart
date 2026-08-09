import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/models.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_scope.dart';
import '../../theme/widgets.dart';
import '../chat/chat_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final Set<String> _pinned = {};

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = ThemeScope.of(context);
    if (app.chats.isEmpty) {
      return const EmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Нет чатов',
        subtitle: 'Нажми ✎ чтобы начать переписку',
      );
    }

    final pinned = app.chats.where((c) => _pinned.contains(c.id)).toList();
    final others = app.chats.where((c) => !_pinned.contains(c.id)).toList();

    return RefreshIndicator(
      color: GBTheme.whatsAppGreen,
      onRefresh: app.refreshChats,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 12),
        itemCount: pinned.length + others.length + (pinned.isNotEmpty ? 1 : 0),
        itemBuilder: (_, i) {
          if (pinned.isNotEmpty && i == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('Закреплённые', style: TextStyle(
                    color: GBTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                ...pinned.map((c) => _ChatTile(
                      chat: c,
                      pinned: true,
                      onSwipe: (action) => _onSwipe(c.id, action),
                    )),
                if (others.isNotEmpty)
                  Divider(height: 1, color: theme.theme.stroke),
              ],
            );
          }
          final idx = pinned.isNotEmpty ? i - 1 - pinned.length : i;
          if (idx < 0 || idx >= others.length) return const SizedBox.shrink();
          return _ChatTile(
            chat: others[idx],
            pinned: false,
            onSwipe: (action) => _onSwipe(others[idx].id, action),
          );
        },
      ),
    );
  }

  void _onSwipe(String chatId, String action) {
    if (action == 'pin') {
      setState(() => _pinned.add(chatId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Чат закреплён'), duration: Duration(seconds: 1)),
      );
    } else if (action == 'unpin') {
      setState(() => _pinned.remove(chatId));
    } else if (action == 'mute') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Чат без звука'), duration: Duration(seconds: 1)),
      );
    } else if (action == 'delete') {
      setState(() {});
    }
  }
}

class _ChatTile extends StatelessWidget {
  final GbChat chat;
  final bool pinned;
  final void Function(String action) onSwipe;

  const _ChatTile({required this.chat, required this.pinned, required this.onSwipe});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = ThemeScope.of(context);
    final peer = chat.peer(app.myId);
    final title = chat.title(app.myId);
    final last = chat.lastMessage;
    final isMine = last?.senderId == app.myId;
    final typing = peer != null && app.isTyping(chat.id, peer.id);
    final subtitle = last == null
        ? (typing ? 'печатает…' : 'Нет сообщений')
        : (typing ? 'печатает…' : (isMine ? 'Вы: ' : '') + last.preview());

    return Dismissible(
      key: ValueKey(chat.id),
      background: Container(
        color: GBTheme.whatsAppGreen,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Icon(pinned ? Icons.push_pin_outlined : Icons.push_pin, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onSwipe(pinned ? 'unpin' : 'pin');
          return false;
        } else {
          return true;
        }
      },
      onDismissed: (_) => onSwipe('delete'),
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatScreen(chatId: chat.id),
        )),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              GBAvatar(
                url: chat.type == 'DIRECT' ? peer?.avatarUrl : chat.avatarUrl,
                name: title,
                size: 52,
                showOnline: chat.type == 'DIRECT',
                online: peer?.isOnline ?? false,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (pinned)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.push_pin, size: 14, color: GBTheme.textSecondary),
                          ),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: chat.unreadCount > 0 ? FontWeight.w600 : FontWeight.w500,
                              fontSize: 16,
                              color: theme.theme.textMain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          shortTime(chat.lastMessageAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: chat.unreadCount > 0 ? GBTheme.whatsAppGreen : theme.theme.textHint,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (isMine && last != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: StatusTicks(status: last.localStatus, size: 12),
                          ),
                        Expanded(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: typing ? GBTheme.whatsAppGreen : theme.theme.textHint,
                              fontWeight: chat.unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (chat.unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: GBTheme.whatsAppGreen,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text('${chat.unreadCount}',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                        if (chat.isMuted && chat.unreadCount == 0) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.volume_off, size: 16, color: GBTheme.textSecondary),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
