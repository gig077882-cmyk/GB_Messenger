import 'dart:convert';

/// Локальное представление сообщения — зерло серверного payload.
class LocalMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String type;
  final String? text;
  final String? mediaKey;
  final String? mediaUrl;
  final Map<String, dynamic>? mediaMeta;
  final String? replyToId;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime? updatedAt;
  List<Map<String, dynamic>> statuses;

  LocalMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.type,
    this.text,
    this.mediaKey,
    this.mediaUrl,
    this.mediaMeta,
    this.replyToId,
    this.isDeleted = false,
    required this.createdAt,
    this.updatedAt,
    this.statuses = const [],
  });

  factory LocalMessage.fromJson(Map<String, dynamic> j) => LocalMessage(
        id: j['id'] as String,
        chatId: j['chatId'] as String,
        senderId: j['senderId'] as String,
        type: (j['type'] ?? 'TEXT') as String,
        text: j['text'] as String?,
        mediaKey: j['mediaKey'] as String?,
        mediaUrl: j['mediaUrl'] as String?,
        mediaMeta: (j['mediaMeta'] as Map<String, dynamic>?)?.cast(),
        replyToId: j['replyToId'] as String?,
        isDeleted: j['isDeleted'] == true,
        createdAt:
            DateTime.tryParse(j['createdAt'].toString())?.toLocal() ?? DateTime.now(),
        updatedAt: j['updatedAt'] != null
            ? DateTime.tryParse(j['updatedAt'].toString())?.toLocal()
            : null,
        statuses: ((j['statuses'] ?? const []) as List)
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList(),
      );

  factory LocalMessage.fromRow(Map<String, dynamic> r) => LocalMessage(
        id: r['id'] as String,
        chatId: r['chat_id'] as String,
        senderId: r['sender_id'] as String,
        type: r['type'] as String,
        text: r['text'] as String?,
        mediaKey: r['media_key'] as String?,
        mediaUrl: r['media_url'] as String?,
        mediaMeta: r['media_meta'] != null
            ? jsonDecode(r['media_meta'] as String).cast<String, dynamic>()
            : null,
        replyToId: r['reply_to_id'] as String?,
        isDeleted: (r['is_deleted'] as int?) == 1,
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
        updatedAt: r['updated_at'] != null
            ? DateTime.parse(r['updated_at'] as String).toLocal()
            : null,
        statuses: (jsonDecode(r['statuses'] ?? '[]') as List)
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList(),
      );

  Map<String, dynamic> toRow() => {
        'id': id,
        'chat_id': chatId,
        'sender_id': senderId,
        'type': type,
        'text': text,
        'media_key': mediaKey,
        'media_url': mediaUrl,
        'media_meta': mediaMeta != null ? jsonEncode(mediaMeta) : null,
        'reply_to_id': replyToId,
        'is_deleted': isDeleted ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'statuses': jsonEncode(statuses),
      };
}
