import '../../core/api_service.dart';
import '../../core/local_db.dart';
import '../../core/models.dart';
import 'models/local_message.dart';

/// Мост между сервером, локальным кэшем и WS.
/// Открыл чат → мгновенно показываем кэш → подтягиваем новые → обновляем кэш.
class ChatRepository {
  final ApiService _api = ApiService.instance;
  final LocalDatabase _local = LocalDatabase.instance;

  Future<List<GbMessage>> loadChat(String chatId, {int limit = 50}) async {
    final cached = await _local.messagesForChat(chatId, limit: limit);
    if (cached.isNotEmpty) {
      _syncNewMessages(chatId, limit: limit);
      return cached.map(_toGbMessage).toList();
    }
    return _fetchAndCache(chatId, limit: limit);
  }

  Future<List<GbMessage>> _fetchAndCache(String chatId, {int limit = 50}) async {
    try {
      final remote = await _api.messages(chatId, limit: limit);
      final locals = remote.map(_toLocal).toList();
      await _local.upsertMessages(locals);
      return remote;
    } catch (_) {
      return [];
    }
  }

  Future<void> _syncNewMessages(String chatId, {int limit = 50}) async {
    try {
      final remote = await _api.messages(chatId, limit: limit);
      await _local.upsertMessages(remote.map(_toLocal).toList());
    } catch (_) {}
  }

  Future<List<GbMessage>> loadOlder(
      String chatId, String cursor, {int limit = 50}) async {
    try {
      final remote = await _api.messages(chatId, cursor: cursor, limit: limit);
      await _local.upsertMessages(remote.map(_toLocal).toList());
      return remote;
    } catch (_) {
      return [];
    }
  }

  Future<void> onMessageReceived(GbMessage m) async {
    await _local.upsertMessages([_toLocal(m)]);
  }

  Future<void> onMessageUpdated(String messageId,
      {String? text, bool? isDeleted}) async {
    if (isDeleted == true) {
      await _local.deleteMessage(messageId);
    } else {
      try {
        final found = await _local.findMessageById(messageId);
        if (found != null) {
          await _local.upsertMessages([found]);
        }
      } catch (_) {}
    }
  }

  Future<void> onDelivered(List<String> messageIds, String chatId) async {
    try {
      final cached = await _local.messagesForChat(chatId, limit: 500);
      var changed = false;
      for (var m in cached) {
        if (messageIds.contains(m.id)) {
          m.statuses = m.statuses
              .map((s) => {...s, 'status': 'DELIVERED'})
              .toList();
          changed = true;
        }
      }
      if (changed) await _local.upsertMessages(cached);
    } catch (_) {}
  }

  // Оффлайн-очередь
  Future<void> enqueuePending(LocalMessage m) => _local.enqueuePending(m);
  Future<List<LocalMessage>> pendingMessages() => _local.pendingMessages();
  Future<void> markPendingSent(String localId, String serverId) =>
      _local.markPendingSent(localId, serverId);
  Future<void> incrementPendingAttempt(String localId, String error) =>
      _local.incrementPendingAttempt(localId, error);

  GbMessage _toGbMessage(LocalMessage m) => GbMessage(
        id: m.id,
        chatId: m.chatId,
        senderId: m.senderId,
        type: m.type,
        text: m.text ?? '',
        mediaKey: m.mediaKey,
        mediaUrl: m.mediaUrl,
        mediaMeta: m.mediaMeta,
        replyToId: m.replyToId,
        isDeleted: m.isDeleted,
        createdAt: m.createdAt,
        updatedAt: m.updatedAt,
        statuses: m.statuses
            .map((s) => MsgStatusRow(
                  userId: s['userId'] as String,
                  status: _parseStatus(s['status']),
                ))
            .toList(),
      );

  static MessageStatus _parseStatus(Object? v) => switch (v) {
        'READ' => MessageStatus.read,
        'DELIVERED' => MessageStatus.delivered,
        _ => MessageStatus.sent,
      };

  static LocalMessage _toLocal(GbMessage m) => LocalMessage(
        id: m.id,
        chatId: m.chatId,
        senderId: m.senderId,
        type: m.type,
        text: m.text.isEmpty ? null : m.text,
        mediaKey: m.mediaKey,
        mediaUrl: m.mediaUrl,
        mediaMeta: m.mediaMeta,
        replyToId: m.replyToId,
        isDeleted: m.isDeleted,
        createdAt: m.createdAt,
        updatedAt: m.updatedAt,
        statuses: m.statuses
            .map((s) => {'userId': s.userId, 'status': s.status.name})
            .toList(),
      );
}
