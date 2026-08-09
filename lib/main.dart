import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_state.dart';
import 'core/models.dart';
import 'core/push_service.dart';
import 'core/update_service.dart';
import 'features/auth/auth_screen.dart';
import 'features/calls/call_screen.dart';
import 'features/chat/chat_info_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/chats/group_create_screen.dart';
import 'features/chats/new_chat_screen.dart';
import 'features/home/home_shell.dart';
import 'features/settings/settings_screen.dart';
import 'features/update/force_update_screen.dart';
import 'features/update/update_banner.dart';
import 'theme/app_theme.dart';
import 'theme/notification_banner.dart';
import 'theme/theme_scope.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: ThemeScope(
        notifier: ThemeProvider(),
        child: const GbMessengerApp(),
      ),
    ),
  );
}

class GbMessengerApp extends StatefulWidget {
  const GbMessengerApp({super.key});

  @override
  State<GbMessengerApp> createState() => _GbMessengerAppState();
}

class _GbMessengerAppState extends State<GbMessengerApp> {
  IncomingCall? _incoming;
  ReleaseInfo? _updateRelease;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final app = context.read<AppState>();
      await app.socket.connect();

      PushService.instance.onNotificationTap = _navigateToChat;
      await PushService.instance.init();

      app.socket.onCallInvite.listen((call) {
        if (!mounted) return;
        setState(() => _incoming = call);
      });

      _checkForUpdate();
    });
  }

  Future<void> _checkForUpdate() async {
    final release = await UpdateService().checkForUpdate();
    if (mounted && release != null) {
      setState(() => _updateRelease = release);
    }
  }

  void _navigateToChat(String chatId) {
    final nav = _navKey.currentState;
    if (nav == null) return;
    nav.push(MaterialPageRoute(
      builder: (_) => _ChatPlaceholder(chatId: chatId),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final app = context.watch<AppState>();
    return MaterialApp(
      title: 'GB Messenger',
      debugShowCheckedModeBanner: false,
      theme: theme.theme.build(),
      navigatorKey: _navKey,
      builder: (context, child) => _InAppNotificationOverlay(child: child ?? const SizedBox()),
      home: _home(app),
      onGenerateRoute: _routes,
    );
  }

  Widget _home(AppState app) {
    if (_updateRelease?.isCritical == true) {
      return ForceUpdateScreen(release: _updateRelease!);
    }
    if (_incoming != null) {
      return CallScreen(
        key: ValueKey(_incoming!.callId),
        chatId: _incoming!.chatId,
        type: _incoming!.type,
        incoming: _incoming,
      );
    }
    if (!app.initialized) return const _Splash();
    final content = app.me == null ? const AuthScreen() : const HomeShell();
    if (_updateRelease != null) {
      return Column(
        children: [
          UpdateBanner(
            release: _updateRelease!,
            onDismiss: () => setState(() => _updateRelease = null),
          ),
          Expanded(child: content),
        ],
      );
    }
    return content;
  }

  Route<dynamic>? _routes(RouteSettings s) {
    switch (s.name) {
      case '/new-chat':
        return _page(const NewChatScreen());
      case '/group-create':
        return _page(const GroupCreateScreen());
      case '/chat-info':
        return _page(ChatInfoScreen(chatId: s.arguments as String));
      case '/call-screen':
        return _page(CallScreen(chatId: s.arguments as String));
      case '/chat':
        return _page(_ChatPlaceholder(chatId: s.arguments as String));
      case '/settings':
        return _page(const SettingsScreen());
    }
    return null;
  }

  static Route<dynamic> _page(Widget w) => PageRouteBuilder(
        pageBuilder: (_, _, _) => w,
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 200),
      );
}

class _ChatPlaceholder extends StatefulWidget {
  final String chatId;
  const _ChatPlaceholder({required this.chatId});

  @override
  State<_ChatPlaceholder> createState() => _ChatPlaceholderState();
}

class _ChatPlaceholderState extends State<_ChatPlaceholder> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _waitForChat());
  }

  Future<void> _waitForChat() async {
    final app = context.read<AppState>();
    for (var i = 0; i < 50; i++) {
      final chat = app.chats.where((c) => c.id == widget.chatId).firstOrNull;
      if (chat != null) {
        if (mounted) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => ChatScreen(chatId: widget.chatId),
          ));
        }
        return;
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

final _navKey = GlobalKey<NavigatorState>();

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_rounded, color: GBTheme.whatsAppGreen, size: 72),
            SizedBox(height: 20),
            CircularProgressIndicator(color: GBTheme.whatsAppGreen),
          ],
        ),
      ),
    );
  }
}

/// РџРѕРєР°Р·С‹РІР°РµС‚ in-app Р±Р°РЅРЅРµСЂ РїСЂРё РїРѕР»СѓС‡РµРЅРёРё РїСѓС€Р° РІ С„РѕСЂРµРіСЂР°СѓРЅРґРµ.
class _InAppNotificationOverlay extends StatefulWidget {
  final Widget child;
  const _InAppNotificationOverlay({required this.child});

  @override
  State<_InAppNotificationOverlay> createState() => _InAppNotificationOverlayState();
}

class _InAppNotificationOverlayState extends State<_InAppNotificationOverlay> {
  InAppNotification? _current;
  Timer? _dismissTimer;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = PushService.instance.onInAppNotification.listen(_show);
  }

  void _show(InAppNotification n) {
    setState(() {
      _current = n;
      _dismissTimer?.cancel();
      _dismissTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _current = null);
      });
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_current != null)
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              bottom: false,
              child: NotificationBanner(
                title: _current!.senderName,
                body: _current!.body,
                avatarUrl: _current!.avatarUrl,
                senderName: _current!.senderName,
                onTap: () {
                  final chatId = _current!.chatId;
                  setState(() => _current = null);
                  _navKey.currentState?.push(MaterialPageRoute(
                    builder: (_) => _ChatPlaceholder(chatId: chatId),
                  ));
                },
                onDismiss: () => setState(() => _current = null),
              ),
            ),
          ),
      ],
    );
  }
}
