import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'local_db.dart';
import 'models.dart';
import 'push_service.dart';
import 'socket_client.dart';
import 'token_storage.dart';

/// Глобальное состояние: сессия, сокет, кэш чатов, presence.
class AppState extends ChangeNotifier {
  final tokenStorage = TokenStorage();
  final api = ApiService.instance;
  final socket = SocketClient();

  GbUser? me;
  List<GbChat> chats = [];
  bool connected = false;
  bool initialized = false;
  bool _wsSubscribed = false;

  final Map<String, bool> _presence = {};
  bool isOnline(String userId) => _presence[userId] ?? false;

  String get myId => me?.id ?? '';

  Future<void> init() async {
    initialized = true;
    final has = await tokenStorage.hasSession();
    if (!has) {
      notifyListeners();
      return;
    }
    try {
      me = await api.me();
    } catch (_) {
      await tokenStorage.clear();
      notifyListeners();
      return;
    }
    _subscribeWs();
    await socket.connect();
    await refreshChats();
    PushService.instance.ensureRegistered();
    notifyListeners();
  }

  void _subscribeWs() {
    if (_wsSubscribed) return;
    _wsSubscribed = true;
    socket.onConnectedChanged.listen((c) {
      connected = c;
      notifyListeners();
      if (c) {
        refreshChats();
        _flushAllPending();
      }
    });
    socket.onMessageNew.listen((m) {
      _upsertChatFromMessage(m);
      notifyListeners();
    });
    socket.onMessageUpdate.listen((m) {
      _upsertChatFromMessage(m);
      notifyListeners();
    });
    socket.onChatNew.listen((c) {
      if (!chats.any((e) => e.id == c.id)) chats.insert(0, c);
      notifyListeners();
    });
    socket.onChatUpdated.listen((c) {
      final i = chats.indexWhere((e) => e.id == c.id);
      if (i >= 0) {
        chats[i] = c;
        _sortChats();
      }
      notifyListeners();
    });
    socket.onTyping.listen((t) {
      _typing['${t.chatId}:${t.userId}'] = t.isTyping;
      if (!t.isTyping) _typing.remove('${t.chatId}:${t.userId}');
      notifyListeners();
    });
    socket.onPresence.listen((p) {
      _presence[p.userId] = p.isOnline;
      notifyListeners();
    });
  }

  final Map<String, bool> _typing = {};
  bool isTyping(String chatId, String userId) =>
      _typing['$chatId:$userId'] ?? false;
  void setTypingLocal(String chatId, bool v) {
    final key = '$chatId:${me?.id}';
    _typing[key] = v;
    socket.emitTyping(chatId, v);
  }

  void _upsertChatFromMessage(GbMessage m) {
    final i = chats.indexWhere((c) => c.id == m.chatId);
    if (i < 0) return;
    chats[i] = _copyChatWithMessage(chats[i], m);
    _sortChats();
  }

  GbChat _copyChatWithMessage(GbChat c, GbMessage m) => GbChat(
        id: c.id,
        type: c.type,
        name: c.name,
        avatarUrl: c.avatarUrl,
        wallpaperUrl: c.wallpaperUrl,
        createdAt: c.createdAt,
        lastMessage: m,
        lastMessageAt: m.createdAt,
        unreadCount: c.unreadCount,
        isMuted: c.isMuted,
        iAmAdmin: c.iAmAdmin,
        members: c.members,
      );

  void _sortChats() {
    chats.sort((a, b) => (b.lastMessageAt ?? b.createdAt)
        .compareTo(a.lastMessageAt ?? a.createdAt));
  }

  /// Отправка всех pending-сообщений при восстановлении связи.
  Future<void> _flushAllPending() async {
    final db = LocalDatabase.instance;
    final pending = await db.pendingMessages();
    for (final p in pending) {
      try {
        await api.sendMessage(p.chatId, {
          'type': p.type,
          if (p.text != null) 'text': p.text,
          if (p.mediaKey != null) 'mediaKey': p.mediaKey,
          if (p.mediaUrl != null) 'mediaUrl': p.mediaUrl,
          if (p.mediaMeta != null) 'mediaMeta': p.mediaMeta,
          if (p.replyToId != null) 'replyToId': p.replyToId,
        });
        await db.markPendingSent(p.id, '${DateTime.now().millisecondsSinceEpoch}');
        notifyListeners();
      } catch (e) {
        await db.incrementPendingAttempt(p.id, e.toString());
      }
    }
  }

  Future<void> refreshChats() async {
    try {
      chats = await api.chats();
      _sortChats();
      notifyListeners();
    } catch (_) {}
  }

  /// Декремент непрочитанных при входе в чат.
  void markChatOpened(String chatId) {
    final i = chats.indexWhere((c) => c.id == chatId);
    if (i >= 0 && chats[i].unreadCount > 0) {
      chats[i] = _withUnread(chats[i], 0);
      notifyListeners();
    }
    api.markRead(chatId);
  }

  GbChat _withUnread(GbChat c, int unread) => GbChat(
        id: c.id,
        type: c.type,
        name: c.name,
        avatarUrl: c.avatarUrl,
        wallpaperUrl: c.wallpaperUrl,
        createdAt: c.createdAt,
        lastMessage: c.lastMessage,
        lastMessageAt: c.lastMessageAt,
        unreadCount: unread,
        isMuted: c.isMuted,
        iAmAdmin: c.iAmAdmin,
        members: c.members,
      );

  Future<bool> login(String email, String password) async {
    final r = await api.login(email: email, password: password);
    return _afterAuth(r);
  }

  Future<bool> register(String email, String password, String displayName, {String? phone}) async {
    final r = await api.register(
      email: email,
      password: password,
      displayName: displayName,
      phone: phone,
    );
    return _afterAuth(r);
  }

  Future<bool> _afterAuth(AuthResult r) async {
    await tokenStorage.saveTokens(r.accessToken, r.refreshToken);
    me = r.user;
    _subscribeWs();
    await socket.connect();
    await refreshChats();
    PushService.instance.ensureRegistered();
    notifyListeners();
    return true;
  }

  void updateMe(GbUser u) {
    me = u;
    notifyListeners();
  }

  Future<void> logout() async {
    final rt = await tokenStorage.refreshToken();
    if (rt != null) api.logout(rt);
    socket.disconnect();
    await tokenStorage.clear();
    me = null;
    chats = [];
    _presence.clear();
    _typing.clear();
    notifyListeners();
  }
}
