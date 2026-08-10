import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_service.dart';
import '../../core/app_state.dart';
import '../../core/models.dart';
import '../../theme/app_theme.dart';
import '../../theme/widgets.dart';
import '../chat/chat_screen.dart';

class GroupCreateScreen extends StatefulWidget {
  const GroupCreateScreen({super.key});

  @override
  State<GroupCreateScreen> createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends State<GroupCreateScreen> {
  final _name = TextEditingController();
  final _q = TextEditingController();
  final ApiService _api = ApiService.instance;
  final List<GbUser> _selected = [];
  List<GbUser> _results = [];
  bool _loading = false;
  Timer? _debounce;
  bool _creating = false;

  @override
  void dispose() {
    _name.dispose();
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
        if (mounted) {
          setState(
            () => _results = r
                .where((u) => !_selected.any((s) => s.id == u.id))
                .toList(),
          );
        }
      } catch (_) {
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  void _toggle(GbUser u) {
    setState(() {
      if (_selected.any((s) => s.id == u.id)) {
        _selected.removeWhere((s) => s.id == u.id);
      } else {
        _selected.add(u);
      }
      _results = _results
          .where((r) => !_selected.any((s) => s.id == r.id))
          .toList();
    });
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Введите название группы')));
      return;
    }
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте хотя бы одного участника')),
      );
      return;
    }
    setState(() => _creating = true);
    final appState = context.read<AppState>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final chat = await _api.createGroup(
        name,
        _selected.map((u) => u.id).toList(),
      );
      await appState.refreshChats();
      if (!context.mounted) return;
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => ChatScreen(chatId: chat.id)),
      );
    } catch (e) {
      if (context.mounted) {
        setState(() => _creating = false);
        messenger.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новая группа'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _creating
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : NeonButton(label: 'Создать', onPressed: _create),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _name,
              decoration: const InputDecoration(hintText: 'Название группы'),
            ),
          ),
          if (_selected.isNotEmpty)
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                itemCount: _selected.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final u = _selected[i];
                  return Column(
                    children: [
                      GestureDetector(
                        onTap: () => _toggle(u),
                        child: Stack(
                          children: [
                            GBAvatar(
                              url: u.avatarUrl,
                              name: u.displayName,
                              size: 48,
                            ),
                            Positioned(
                              right: -3,
                              top: -3,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 54,
                        child: Text(
                          u.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: TextField(
              controller: _q,
              onChanged: _search,
              decoration: const InputDecoration(
                hintText: 'Добавить участников…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                ? const EmptyState(
                    icon: Icons.person_add_alt_1_outlined,
                    title: 'Найди участников',
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final u = _results[i];
                      return ListTile(
                        leading: GBAvatar(
                          url: u.avatarUrl,
                          name: u.displayName,
                          size: 44,
                        ),
                        title: Text(u.displayName),
                        trailing: const Icon(
                          Icons.add_circle_outline,
                          color: GBTheme.whatsAppGreen,
                        ),
                        onTap: () => _toggle(u),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
