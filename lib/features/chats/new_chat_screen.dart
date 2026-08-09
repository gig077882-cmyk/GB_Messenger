import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_service.dart';
import '../../core/app_state.dart';
import '../../core/models.dart';
import '../../theme/widgets.dart';
import '../chat/chat_screen.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _q = TextEditingController();
  final ApiService _api = ApiService.instance;
  List<GbUser> _results = [];
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
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _loading = true);
      try {
        final r = await _api.searchUsers(q.trim());
        if (mounted) setState(() => _results = r);
      } catch (_) {
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  Future<void> _openChat(GbUser u) async {
    final app = context.read<AppState>();
    final chat = await _api.createDirect(u.id);
    await app.refreshChats();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ChatScreen(chatId: chat.id),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новый чат'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pushNamed('/group-create'),
            child: const Text('Группа'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _q,
              autofocus: true,
              onChanged: _search,
              decoration: const InputDecoration(
                hintText: 'Поиск по имени, email или телефону',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? const EmptyState(
                        icon: Icons.person_search_outlined,
                        title: 'Найди собеседника',
                        subtitle: 'Введи минимум 2 символа')
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (_, i) {
                          final u = _results[i];
                          return ListTile(
                            leading: GBAvatar(url: u.avatarUrl, name: u.displayName, size: 44),
                            title: Text(u.displayName),
                            subtitle: Text(u.email),
                            onTap: () => _openChat(u),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
