import 'package:flutter/material.dart';

import '../../core/api_service.dart';
import '../../core/contacts_service.dart';
import '../../core/models.dart';
import '../../theme/app_theme.dart';
import '../../theme/widgets.dart';
import '../chat/chat_screen.dart';

class AddByPhoneScreen extends StatefulWidget {
  const AddByPhoneScreen({super.key});

  @override
  State<AddByPhoneScreen> createState() => _AddByPhoneScreenState();
}

class _AddByPhoneScreenState extends State<AddByPhoneScreen> {
  final _phoneCtrl = TextEditingController();
  final ApiService _api = ApiService.instance;
  GbUser? _found;
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  String _formatPhone(String raw) {
    return ContactsService.instance.normalizePhone(raw);
  }

  Future<void> _search() async {
    final phone = _formatPhone(_phoneCtrl.text.trim());
    if (phone.length < 10) {
      setState(() => _error = 'Введите корректный номер');
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
      _found = null;
    });
    try {
      final users = await _api.searchByPhone(phone);
      if (mounted) {
        setState(() {
          _found = users.isNotEmpty ? users.first : null;
          _searching = false;
          if (_found == null) _error = 'Пользователь не найден';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searching = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Добавить по номеру')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              autofocus: true,
              onChanged: (_) => setState(() {
                _error = null;
                _found = null;
              }),
              decoration: InputDecoration(
                hintText: '+7 (912) 345-67-89',
                labelText: 'Номер телефона',
                prefixIcon: const Icon(Icons.phone),
                errorText: _error,
              ),
            ),
            const SizedBox(height: 16),
            NeonButton(
              label: 'Найти',
              icon: Icons.search,
              onPressed: _searching ? null : _search,
              loading: _searching,
            ),
            const SizedBox(height: 24),
            if (_found != null) ...[
              Center(
                child: GBAvatar(
                  url: _found!.avatarUrl,
                  name: _found!.displayName,
                  size: 72,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  _found!.displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  _found!.phone ?? _found!.email,
                  style: const TextStyle(color: GBTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 20),
              NeonButton(
                label: 'Написать',
                icon: Icons.chat,
                onPressed: () async {
                  try {
                    final chat = await _api.createDirect(_found!.id);
                    if (!context.mounted) return;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(chatId: chat.id),
                      ),
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
                    }
                  }
                },
              ),
            ],
            if (_error != null && _found == null) ...[
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.person_off,
                      size: 48,
                      color: Color(0xFF2A2A2A),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Пользователь не найден',
                      style: TextStyle(color: Color(0xFF8A8A8A)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
