/// Модели данных, зеркалящие ответы API сервера.
class GbUser {
  final String id;
  final String email;
  final String displayName;
  final String username;
  final String? bio;
  final String? phone;
  final String? avatarKey;
  final String? avatarUrl;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final String? wallpaperUrl;

  const GbUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.username,
    this.bio,
    this.phone,
    this.avatarKey,
    this.avatarUrl,
    this.isOnline = false,
    this.lastSeenAt,
    this.wallpaperUrl,
  });

  factory GbUser.fromJson(Map<String, dynamic> j) => GbUser(
    id: j['id'] as String,
    email: (j['email'] ?? '') as String,
    displayName: (j['displayName'] ?? '') as String,
    username: (j['username'] ?? '') as String,
    bio: j['bio'] as String?,
    phone: j['phone'] as String?,
    avatarKey: j['avatarKey'] as String?,
    avatarUrl: j['avatarUrl'] as String?,
    isOnline: j['isOnline'] == true,
    lastSeenAt: _dt(j['lastSeenAt']),
    wallpaperUrl: j['wallpaperUrl'] as String?,
  );
}

class ChatMember {
  final String userId;
  final String role;
  final GbUser user;

  const ChatMember({
    required this.userId,
    required this.role,
    required this.user,
  });

  factory ChatMember.fromJson(Map<String, dynamic> j) {
    final userJson = j['user'];
    final userId = j['userId'] as String? ?? '';
    return ChatMember(
      userId: userId,
      role: (j['role'] ?? 'member') as String,
      user: userJson is Map<String, dynamic>
          ? GbUser.fromJson(userJson)
          : GbUser(
              id: userId,
              email: '',
              displayName: (j['displayName'] ?? '') as String,
              username: (j['username'] ?? '') as String,
            ),
    );
  }
}

class GbChat {
  final String id;
  final String type; // DIRECT | GROUP
  final String? name;
  final String? avatarUrl;
  final String? wallpaperUrl;
  final DateTime createdAt;
  final GbMessage? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool isMuted;
  final bool iAmAdmin;
  final List<ChatMember> members;

  const GbChat({
    required this.id,
    required this.type,
    this.name,
    this.avatarUrl,
    this.wallpaperUrl,
    required this.createdAt,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.isMuted = false,
    this.iAmAdmin = false,
    this.members = const [],
  });

  factory GbChat.fromJson(Map<String, dynamic> j) => GbChat(
    id: j['id'] as String,
    type: (j['type'] ?? 'DIRECT') as String,
    name: j['name'] as String?,
    avatarUrl: j['avatarUrl'] as String?,
    wallpaperUrl: j['wallpaperUrl'] as String?,
    createdAt: _dt(j['createdAt']) ?? DateTime.now(),
    lastMessage: j['lastMessage'] != null
        ? GbMessage.fromJson(j['lastMessage'] as Map<String, dynamic>)
        : null,
    lastMessageAt: _dt(j['lastMessageAt']),
    unreadCount: (j['unreadCount'] ?? 0) as int,
    isMuted: j['isMuted'] == true,
    iAmAdmin: j['iAmAdmin'] == true,
    members: ((j['members'] ?? const []) as List)
        .whereType<Map<String, dynamic>>()
        .map(ChatMember.fromJson)
        .toList(),
  );

  /// Собеседник в direct-чате (не я).
  GbUser? peer(String myId) {
    if (type != 'DIRECT') return null;
    for (final m in members) {
      if (m.userId != myId) return m.user;
    }
    return null;
  }

  String title(String myId) => type == 'GROUP'
      ? (name ?? 'Группа')
      : (peer(myId)?.displayName ?? 'Собеседник');
}

enum MessageStatus { sent, delivered, read, failed, sending }

class MsgStatusRow {
  final String userId;
  final MessageStatus status;

  const MsgStatusRow({required this.userId, required this.status});

  factory MsgStatusRow.fromJson(Map<String, dynamic> j) => MsgStatusRow(
    userId: j['userId'] as String,
    status: switch (j['status']) {
      'SENT' => MessageStatus.sent,
      'DELIVERED' => MessageStatus.delivered,
      'READ' => MessageStatus.read,
      _ => MessageStatus.sent,
    },
  );
}

class MessageReaction {
  final String userId;
  final String emoji;

  const MessageReaction({required this.userId, required this.emoji});

  factory MessageReaction.fromJson(Map<String, dynamic> j) => MessageReaction(
    userId: j['userId'] as String,
    emoji: j['emoji'] as String,
  );
}

class GbMessage {
  final String id;
  final String chatId;
  final String senderId;
  final GbUser? sender;
  final String type;
  final String text;
  final String? mediaKey;
  final String? mediaUrl;
  final Map<String, dynamic>? mediaMeta;
  final String? replyToId;
  final GbMessage? replyTo;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<MsgStatusRow> statuses;
  List<MessageReaction> reactions;
  final GbUser? forwardedFrom;
  bool viewOnce;
  bool viewed;

  MessageStatus localStatus;

  GbMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.sender,
    required this.type,
    this.text = '',
    this.mediaKey,
    this.mediaUrl,
    this.mediaMeta,
    this.replyToId,
    this.replyTo,
    this.isDeleted = false,
    required this.createdAt,
    this.updatedAt,
    this.statuses = const [],
    this.reactions = const [],
    this.forwardedFrom,
    this.viewOnce = false,
    this.viewed = false,
    this.localStatus = MessageStatus.sent,
  });

  factory GbMessage.fromJson(Map<String, dynamic> j) => GbMessage(
    id: j['id'] as String,
    chatId: j['chatId'] as String,
    senderId: j['senderId'] as String,
    sender: j['sender'] != null
        ? GbUser.fromJson(j['sender'] as Map<String, dynamic>)
        : null,
    type: (j['type'] ?? 'TEXT') as String,
    text: (j['text'] ?? '') as String,
    mediaKey: j['mediaKey'] as String?,
    mediaUrl: j['mediaUrl'] as String?,
    mediaMeta: (j['mediaMeta'] as Map<String, dynamic>?)
        ?.cast<String, dynamic>(),
    replyToId: j['replyToId'] as String?,
    isDeleted: j['isDeleted'] == true,
    createdAt: _dt(j['createdAt']) ?? DateTime.now(),
    updatedAt: _dt(j['updatedAt']),
    statuses: ((j['statuses'] ?? const []) as List)
        .whereType<Map<String, dynamic>>()
        .map(MsgStatusRow.fromJson)
        .toList(),
    reactions: ((j['reactions'] ?? const []) as List)
        .whereType<Map<String, dynamic>>()
        .map(MessageReaction.fromJson)
        .toList(),
    forwardedFrom: j['forwardedFrom'] != null
        ? GbUser.fromJson(j['forwardedFrom'] as Map<String, dynamic>)
        : null,
  );

  GbMessage copyWith({MessageStatus? localStatus}) => GbMessage(
    id: id,
    chatId: chatId,
    senderId: senderId,
    sender: sender,
    type: type,
    text: text,
    mediaKey: mediaKey,
    mediaUrl: mediaUrl,
    mediaMeta: mediaMeta,
    replyToId: replyToId,
    replyTo: replyTo,
    isDeleted: isDeleted,
    createdAt: createdAt,
    updatedAt: updatedAt,
    statuses: statuses,
    reactions: reactions,
    forwardedFrom: forwardedFrom,
    viewOnce: viewOnce,
    viewed: viewed,
    localStatus: localStatus ?? this.localStatus,
  );

  String preview() {
    if (isDeleted) return 'Удалено';
    switch (type) {
      case 'IMAGE':
        return '📷 Фото';
      case 'VIDEO':
        return '🎬 Видео';
      case 'VOICE':
        return '🎤 Голосовое';
      case 'AUDIO':
        return '🎵 Аудио';
      case 'DOCUMENT':
        return '📎 Документ';
      case 'CALL':
        return '📞 Звонок';
      default:
        return text;
    }
  }
}

class GbStatus {
  final String id;
  final String userId;
  final GbUser? user;
  final String kind; // IMAGE|VIDEO|TEXT
  final String? mediaKey;
  final String? mediaUrl;
  final String? caption;
  final Map<String, dynamic>? mediaMeta;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final List<String> viewerIds;
  final int viewCount;

  const GbStatus({
    required this.id,
    required this.userId,
    this.user,
    required this.kind,
    this.mediaKey,
    this.mediaUrl,
    this.caption,
    this.mediaMeta,
    required this.createdAt,
    this.expiresAt,
    this.viewerIds = const [],
    this.viewCount = 0,
  });

  factory GbStatus.fromJson(Map<String, dynamic> j) => GbStatus(
    id: j['id'] as String,
    userId: j['userId'] as String,
    user: j['user'] != null
        ? GbUser.fromJson(j['user'] as Map<String, dynamic>)
        : null,
    kind: (j['kind'] ?? 'IMAGE') as String,
    mediaKey: j['mediaKey'] as String?,
    mediaUrl: j['mediaUrl'] as String?,
    caption: j['caption'] as String?,
    mediaMeta: (j['mediaMeta'] as Map<String, dynamic>?)
        ?.cast<String, dynamic>(),
    createdAt: _dt(j['createdAt']) ?? DateTime.now(),
    expiresAt: _dt(j['expiresAt']),
    viewerIds: ((j['viewerIds'] ?? const []) as List)
        .whereType<String>()
        .toList(),
    viewCount: (j['viewCount'] ?? 0) as int,
  );
}

class CallLog {
  final String id;
  final String chatId;
  final String callerId;
  final List<String> calleeIds;
  final String kind; // AUDIO|VIDEO
  final String status; // completed|missed|rejected|cancelled
  final DateTime? startedAt;
  final DateTime? endedAt;

  const CallLog({
    required this.id,
    required this.chatId,
    required this.callerId,
    required this.calleeIds,
    required this.kind,
    required this.status,
    this.startedAt,
    this.endedAt,
  });

  factory CallLog.fromJson(Map<String, dynamic> j) => CallLog(
    id: j['id'] as String,
    chatId: j['chatId'] as String,
    callerId: j['callerId'] as String,
    calleeIds: ((j['calleeIds'] ?? const []) as List)
        .whereType<String>()
        .toList(),
    kind: (j['kind'] ?? 'AUDIO') as String,
    status: (j['status'] ?? 'completed') as String,
    startedAt: _dt(j['startedAt']),
    endedAt: _dt(j['endedAt']),
  );
}

class IncomingCall {
  final String callId;
  final String chatId;
  final String type; // AUDIO|VIDEO
  final GbUser caller;

  const IncomingCall({
    required this.callId,
    required this.chatId,
    required this.type,
    required this.caller,
  });
}

class AuthResult {
  final String accessToken;
  final String refreshToken;
  final GbUser user;

  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });
}

DateTime? _dt(Object? v) =>
    v == null ? null : (DateTime.tryParse(v.toString())?.toLocal());
