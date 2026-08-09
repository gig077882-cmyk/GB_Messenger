import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../theme/app_theme.dart';
import '../calls/calls_screen.dart';
import '../chats/chats_screen.dart';
import '../contacts/contacts_screen.dart';
import '../settings/settings_screen.dart';
import '../statuses/statuses_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('GB Messenger'),
        actions: [
          IconButton(
            tooltip: 'Поиск',
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).pushNamed('/new-chat'),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'settings') Navigator.of(context).pushNamed('/settings');
              if (v == 'new-group') Navigator.of(context).pushNamed('/group-create');
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'new-group', child: Text('Новая группа')),
              const PopupMenuItem(value: 'settings', child: Text('Настройки')),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [
          ChatsScreen(),
          ContactsScreen(),
          StatusesScreen(),
          CallsScreen(),
          SettingsScreen(),
        ],
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton(
              onPressed: () => Navigator.of(context).pushNamed('/new-chat'),
              child: const Icon(Icons.chat),
            )
          : _tab == 1
              ? FloatingActionButton(
                  onPressed: () => Navigator.of(context).pushNamed('/new-chat'),
                  child: const Icon(Icons.camera_alt),
                )
              : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        selectedItemColor: GBTheme.whatsAppDark,
        unselectedItemColor: GBTheme.textSecondary,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Чаты',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Контакты',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.radio_button_unchecked),
            activeIcon: Icon(Icons.radio_button_checked),
            label: 'Статусы',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.call_outlined),
            activeIcon: Icon(Icons.call),
            label: 'Звонки',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Ещё',
          ),
        ],
      ),
    );
  }
}
