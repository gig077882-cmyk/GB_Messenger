import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api_service.dart';
import '../../core/app_state.dart';
import '../../core/contacts_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_scope.dart';
import '../../theme/widgets.dart';
import '../chat/chat_screen.dart';
import 'add_by_phone_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final ContactsService _service = ContactsService.instance;
  List<PhoneContact> _contacts = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final contacts = await _service.syncContacts();
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<PhoneContact> get _filtered {
    if (_query.isEmpty) return _contacts;
    final q = _query.toLowerCase();
    return _contacts
        .where((c) => c.name.toLowerCase().contains(q) || c.phone.contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('РљРѕРЅС‚Р°РєС‚С‹'),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone),
            tooltip: 'Р”РѕР±Р°РІРёС‚СЊ РїРѕ РЅРѕРјРµСЂСѓ',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AddByPhoneScreen())),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
          ? _emptyState(theme)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'РџРѕРёСЃРє РєРѕРЅС‚Р°РєС‚РѕРІ...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: _filtered.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      indent: 76,
                      endIndent: 16,
                      color: theme.theme.stroke,
                    ),
                    itemBuilder: (_, i) {
                      final c = _filtered[i];
                      return ListTile(
                        leading: GBAvatar(
                          url: c.avatarUrl,
                          name: c.name,
                          size: 48,
                        ),
                        title: Text(
                          c.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          c.phone,
                          style: TextStyle(
                            color: theme.theme.textHint,
                            fontSize: 13,
                          ),
                        ),
                        trailing: c.registered
                            ? TextButton(
                                onPressed: () => _openChat(c),
                                child: const Text('РќР°РїРёСЃР°С‚СЊ'),
                              )
                            : const Icon(
                                Icons.person_add,
                                color: GBTheme.textSecondary,
                              ),
                        onTap: c.registered ? () => _openChat(c) : null,
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _load,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _emptyState(ThemeProvider theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, size: 64, color: Color(0xFF2A2A2A)),
          const SizedBox(height: 16),
          const Text(
            'РќРµС‚ РєРѕРЅС‚Р°РєС‚РѕРІ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            'РЎРёРЅС…СЂРѕРЅРёР·РёСЂСѓР№С‚Рµ РєРѕРЅС‚Р°РєС‚С‹ РёР· С‚РµР»РµС„РѕРЅР°',
            style: TextStyle(color: Color(0xFF8A8A8A)),
          ),
          const SizedBox(height: 20),
          NeonButton(
            label: 'Р”РѕР±Р°РІРёС‚СЊ РїРѕ РЅРѕРјРµСЂСѓ',
            icon: Icons.phone,
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AddByPhoneScreen())),
          ),
        ],
      ),
    );
  }

  Future<void> _openChat(PhoneContact c) async {
    final app = context.read<AppState>();
    try {
      final chat = await ApiService.instance.createDirectByUserPhone(c.phone);
      await app.refreshChats();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ChatScreen(chatId: chat.id)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('РћС€РёР±РєР°: $e')));
      }
    }
  }
}
