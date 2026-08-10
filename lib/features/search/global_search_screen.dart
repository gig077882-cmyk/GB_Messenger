import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_service.dart';
import '../../core/app_state.dart';
import '../../core/models.dart';
import '../../theme/widgets.dart';
import '../chat/chat_screen.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _q = TextEditingController();
  final ApiService _api = ApiService.instance;
  List<GbUser> _users = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _q.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _search(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() {
        _users = [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _loading = true);
      try {
        final users = await _api.searchUsers(q.trim());
        if (mounted) {
          setState(() {
            _users = users;
            _loading = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _q,
          autofocus: true,
          onChanged: _search,
          decoration: const InputDecoration(
            hintText: 'Поиск...',
            border: InputBorder.none,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _q.text.trim().length < 2
          ? const EmptyState(
              icon: Icons.search,
              title: 'Найди контакты и чаты',
              subtitle: 'Введи минимум 2 символа',
            )
          : ListView(
              children: [
                if (_users.isNotEmpty) ...[
                  const SectionTitle(text: 'КОНТАКТЫ'),
                  ..._users.map(
                    (u) => ListTile(
                      leading: GBAvatar(
                        url: u.avatarUrl,
                        name: u.displayName,
                        size: 44,
                      ),
                      title: Text(u.displayName),
                      subtitle: Text(u.email),
                      onTap: () async {
                        final appState = context.read<AppState>();
                        final chat = await _api.createDirect(u.id);
                        await appState.refreshChats();
                        if (!context.mounted) return;
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(chatId: chat.id),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
