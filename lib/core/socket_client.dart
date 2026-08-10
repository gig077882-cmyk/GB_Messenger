import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'config.dart';
import 'models.dart';
import 'token_storage.dart';

/// Обёртка над Socket.IO: события сервера — стримы, эмиты — методы.
class SocketClient {
  io.Socket? _socket;
  final _mc = StreamController<GbMessage>.broadcast();
  final _mcUpd = StreamController<GbMessage>.broadcast();
  final _delivered = StreamController<DeliveredEvent>.broadcast();
  final _read = StreamController<ReadEvent>.broadcast();
  final _typing = StreamController<TypingEvent>.broadcast();
  final _presence = StreamController<PresenceEvent>.broadcast();
  final _call = StreamController<IncomingCall>.broadcast();
  final _callEnd = StreamController<String>.broadcast();
  final _chatNew = StreamController<GbChat>.broadcast();
  final _chatUpd = StreamController<GbChat>.broadcast();
  final _chatMember = StreamController<ChatMemberEvent>.broadcast();
  final _statusNew = StreamController<GbStatus>.broadcast();
  final _status = StreamController<bool>.broadcast(); // connected
  final _reaction = StreamController<ReactionEvent>.broadcast();

  Stream<GbMessage> get onMessageNew => _mc.stream;
  Stream<GbMessage> get onMessageUpdate => _mcUpd.stream;
  Stream<DeliveredEvent> get onDelivered => _delivered.stream;
  Stream<ReadEvent> get onRead => _read.stream;
  Stream<TypingEvent> get onTyping => _typing.stream;
  Stream<PresenceEvent> get onPresence => _presence.stream;
  Stream<IncomingCall> get onCallInvite => _call.stream;
  Stream<String> get onCallEnd => _callEnd.stream;
  Stream<GbChat> get onChatNew => _chatNew.stream;
  Stream<GbChat> get onChatUpdated => _chatUpd.stream;
  Stream<ChatMemberEvent> get onChatMember => _chatMember.stream;
  Stream<GbStatus> get onStatusNew => _statusNew.stream;
  Stream<bool> get onConnectedChanged => _status.stream;
  Stream<ReactionEvent> get onReaction => _reaction.stream;

  bool get connected => _socket?.connected ?? false;

  Future<void> connect() async {
    if (_socket != null) return;
    final token = await TokenStorage().accessToken();
    if (token == null) return;
    final socketBase = AppConfig.apiBase.endsWith('/api')
        ? AppConfig.apiBase.substring(0, AppConfig.apiBase.length - 4)
        : AppConfig.apiBase;
    _socket = io.io(
      socketBase,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionAttempts(20)
          .disableAutoConnect()
          .build(),
    );
    _socket!
      ..onConnect((_) => _status.add(true))
      ..onDisconnect((_) => _status.add(false))
      ..onConnectError((e) => debugPrint('[ws] connect error: $e'))
      ..onReconnect((_) => debugPrint('[ws] reconnecting...'))
      ..onReconnectError((e) => debugPrint('[ws] reconnect error: $e'))
      ..onReconnectFailed((_) => debugPrint('[ws] reconnect failed'))
      ..on('message:new', (d) => _mc.add(GbMessage.fromJson(_asMap(d))))
      ..on('message:update', (d) => _mcUpd.add(GbMessage.fromJson(_asMap(d))))
      ..on('messages:delivered', (d) {
        final m = _asMap(d);
        _delivered.add(
          DeliveredEvent(
            chatId: m['chatId'] as String,
            messageIds: (m['messageIds'] as List).whereType<String>().toList(),
            userIds: (m['userIds'] as List).whereType<String>().toList(),
          ),
        );
      })
      ..on('read:receipts', (d) {
        final m = _asMap(d);
        _read.add(
          ReadEvent(
            chatId: m['chatId'] as String,
            messageIds: (m['messageIds'] as List).whereType<String>().toList(),
            userId: m['userId'] as String?,
          ),
        );
      })
      ..on('typing', (d) {
        final m = _asMap(d);
        _typing.add(
          TypingEvent(
            chatId: m['chatId'] as String,
            userId: m['userId'] as String,
            isTyping: m['isTyping'] == true,
          ),
        );
      })
      ..on('presence:update', (d) {
        final m = _asMap(d);
        _presence.add(
          PresenceEvent(
            userId: m['userId'] as String,
            isOnline: m['isOnline'] == true,
            lastSeenAt: m['lastSeenAt'] != null
                ? DateTime.tryParse(m['lastSeenAt'].toString())
                : null,
          ),
        );
      })
      ..on('call:invite', (d) {
        final m = _asMap(d);
        final caller = m['caller'] != null
            ? GbUser.fromJson(m['caller'] as Map<String, dynamic>)
            : null;
        if (caller == null) return;
        _call.add(
          IncomingCall(
            callId: (m['callId'] ?? '') as String,
            chatId: (m['chatId'] ?? '') as String,
            type: (m['type'] ?? 'AUDIO') as String,
            caller: caller,
          ),
        );
      })
      ..on('call:end', (d) {
        final m = _asMap(d);
        _callEnd.add((m['callId'] ?? '') as String);
      })
      ..on('chat:new', (d) => _chatNew.add(GbChat.fromJson(_asMap(d))))
      ..on('chat:updated', (d) => _chatUpd.add(GbChat.fromJson(_asMap(d))))
      ..on('chat:member:added', (d) => _member('added', d))
      ..on('chat:member:removed', (d) => _member('removed', d))
      ..on('chat:member:role', (d) => _member('role', d))
      ..on('status:new', (d) => _statusNew.add(GbStatus.fromJson(_asMap(d))))
      ..on('message:reaction', (d) {
        final m = _asMap(d);
        _reaction.add(
          ReactionEvent(
            chatId: (m['chatId'] ?? '') as String,
            messageId: (m['messageId'] ?? '') as String,
            userId: (m['userId'] ?? '') as String,
            emoji: m['emoji'] as String?,
            action: (m['action'] ?? 'added') as String,
          ),
        );
      })
      ..connect();
  }

  void _member(String kind, dynamic d) {
    final m = _asMap(d);
    _chatMember.add(
      ChatMemberEvent(
        kind: kind,
        chatId: (m['chatId'] ?? '') as String,
        userId: (m['userId'] ?? '') as String,
        isAdmin: m['isAdmin'] == true,
      ),
    );
  }

  void emitTyping(String chatId, bool isTyping) =>
      _socket?.emit('typing', {'chatId': chatId, 'isTyping': isTyping});

  void emitRead(String chatId, List<String> messageIds) => _socket?.emit(
    'messages:read',
    {'chatId': chatId, 'messageIds': messageIds},
  );

  void emitCallInvite(String chatId, String type) =>
      _socket?.emit('call:invite', {'chatId': chatId, 'type': type});

  void emitCallEnd(String callId) =>
      _socket?.emit('call:end', {'callId': callId});

  void emitPresenceGet(List<String> userIds) =>
      _socket?.emit('presence:get', {'userIds': userIds});

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  Map<String, dynamic> _asMap(dynamic d) {
    if (d is Map) return d.cast<String, dynamic>();
    return <String, dynamic>{};
  }
}

class DeliveredEvent {
  final String chatId;
  final List<String> messageIds;
  final List<String> userIds;
  const DeliveredEvent({
    required this.chatId,
    required this.messageIds,
    required this.userIds,
  });
}

class ReadEvent {
  final String chatId;
  final List<String> messageIds;
  final String? userId;
  const ReadEvent({
    required this.chatId,
    required this.messageIds,
    this.userId,
  });
}

class TypingEvent {
  final String chatId;
  final String userId;
  final bool isTyping;
  const TypingEvent({
    required this.chatId,
    required this.userId,
    required this.isTyping,
  });
}

class PresenceEvent {
  final String userId;
  final bool isOnline;
  final DateTime? lastSeenAt;
  const PresenceEvent({
    required this.userId,
    required this.isOnline,
    this.lastSeenAt,
  });
}

class ChatMemberEvent {
  final String kind; // added | removed | role
  final String chatId;
  final String userId;
  final bool isAdmin;
  const ChatMemberEvent({
    required this.kind,
    required this.chatId,
    required this.userId,
    this.isAdmin = false,
  });
}

class ReactionEvent {
  final String chatId;
  final String messageId;
  final String userId;
  final String? emoji;
  final String action; // added | removed
  const ReactionEvent({
    required this.chatId,
    required this.messageId,
    required this.userId,
    this.emoji,
    required this.action,
  });
}
