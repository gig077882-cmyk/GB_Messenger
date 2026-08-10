import 'package:dio/dio.dart';

import 'api_client.dart';
import 'models.dart';

/// Типизированные методы REST API.
class ApiService {
  static final ApiService instance = ApiService._();
  ApiService._();

  Dio get _d => ApiClient().dio;

  Map<String, dynamic> _j(Response r) =>
      (r.data as Map).cast<String, dynamic>();
  List<dynamic> _l(Response r) => (r.data as List);

  // ── Auth ────────────────────────────────────────────────────────────────
  Future<AuthResult> register({
    required String email,
    required String password,
    required String displayName,
    String? phone,
    String? deviceId,
    String? fcmToken,
  }) async {
    final r = await _d.post(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        'displayName': displayName,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'deviceId': deviceId,
        'fcmToken': fcmToken,
      },
    );
    return _auth(_j(r));
  }

  Future<AuthResult> login({
    required String email,
    required String password,
    String? deviceId,
    String? fcmToken,
  }) async {
    final r = await _d.post(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
        'deviceId': deviceId,
        'fcmToken': fcmToken,
      },
    );
    return _auth(_j(r));
  }

  Future<void> logout(String refreshToken) async {
    try {
      await _d.post('/auth/logout', data: {'refreshToken': refreshToken});
    } catch (_) {}
  }

  AuthResult _auth(Map<String, dynamic> j) => AuthResult(
    accessToken: j['accessToken'] as String,
    refreshToken: j['refreshToken'] as String,
    user: GbUser.fromJson(j['user'] as Map<String, dynamic>),
  );

  // ── Users ───────────────────────────────────────────────────────────────
  Future<GbUser> me() async => GbUser.fromJson(_j(await _d.get('/users/me')));

  Future<GbUser> patchMe(Map<String, dynamic> data) async =>
      GbUser.fromJson(_j(await _d.patch('/users/me', data: data)));

  Future<GbChat> createDirectByUserPhone(String phone) async {
    final users = await searchByPhone(phone);
    if (users.isEmpty) throw Exception('User not found');
    return createDirect(users.first.id);
  }

  Future<List<GbUser>> searchByPhone(String phone) async => _l(
    await _d.get('/users/search', queryParameters: {'phone': phone}),
  ).map((e) => GbUser.fromJson((e as Map).cast<String, dynamic>())).toList();

  Future<List<GbUser>> searchUsers(String q) async => _l(
    await _d.get('/users/search', queryParameters: {'q': q}),
  ).map((e) => GbUser.fromJson((e as Map).cast<String, dynamic>())).toList();

  Future<List<GbUser>> syncContacts(List<String> phones) async {
    final j = _j(
      await _d.post('/users/contacts/sync', data: {'phones': phones}),
    );
    return ((j['matched'] ?? const []) as List)
        .map((e) => GbUser.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> blockUser(String id) =>
      _d.post('/users/block', data: {'userId': id});
  Future<void> unblockUser(String id) => _d.delete('/users/block/$id');
  Future<Map<String, dynamic>> registerPushToken({
    required String token,
    required String platform,
    String? deviceId,
  }) async => _j(
    await _d.post(
      '/users/me/push',
      data: {
        'token': token,
        'platform': platform,
        if (deviceId != null) ...{'deviceId': deviceId},
      },
    ),
  );

  // ── Chats ───────────────────────────────────────────────────────────────
  Future<GbChat> createDirect(String userId) async => GbChat.fromJson(
    _j(await _d.post('/chats/direct', data: {'userId': userId})),
  );

  Future<GbChat> createGroup(String name, List<String> memberIds) async =>
      GbChat.fromJson(
        _j(
          await _d.post(
            '/chats/group',
            data: {'name': name, 'memberIds': memberIds},
          ),
        ),
      );

  Future<List<GbChat>> chats() async => _l(
    await _d.get('/chats'),
  ).map((e) => GbChat.fromJson((e as Map).cast<String, dynamic>())).toList();

  Future<GbChat> chat(String id) async =>
      GbChat.fromJson(_j(await _d.get('/chats/$id')));

  Future<GbChat> patchChat(String id, Map<String, dynamic> data) async =>
      GbChat.fromJson(_j(await _d.patch('/chats/$id', data: data)));

  Future<void> addMembers(String chatId, List<String> userIds) =>
      _d.post('/chats/$chatId/members', data: {'userIds': userIds});

  Future<void> removeMember(String chatId, String userId) =>
      _d.delete('/chats/$chatId/members/$userId');

  Future<void> setAdmin(String chatId, String userId, bool isAdmin) => _d.post(
    '/chats/$chatId/admins',
    data: {'userId': userId, 'isAdmin': isAdmin},
  );

  Future<void> markRead(String chatId) =>
      _d.patch('/chats/$chatId/me', data: {'lastReadMessageId': null});

  Future<void> leaveChat(String chatId) => _d.delete('/chats/$chatId/leave');

  // ── Messages ────────────────────────────────────────────────────────────
  Future<List<GbMessage>> messages(
    String chatId, {
    String? cursor,
    int? limit,
  }) async {
    final r = await _d.get(
      '/chats/$chatId/messages',
      queryParameters: {
        if (cursor != null) ...{'cursor': cursor},
        if (limit != null) ...{'limit': limit},
      },
    );
    final data = _j(r);
    return ((data['items'] ?? data['messages'] ?? data['data']) as List? ??
            (r.data as List))
        .map((e) => GbMessage.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<GbMessage> sendMessage(
    String chatId,
    Map<String, dynamic> data,
  ) async => GbMessage.fromJson(
    _j(await _d.post('/chats/$chatId/messages', data: data)),
  );

  Future<GbMessage> editMessage(String id, String text) async =>
      GbMessage.fromJson(
        _j(await _d.patch('/messages/$id', data: {'text': text})),
      );

  Future<void> deleteMessage(String id, {bool forAll = true}) =>
      _d.delete('/messages/$id', queryParameters: {'forAll': forAll});

  // ── Media ───────────────────────────────────────────────────────────────
  Future<({String key, String uploadUrl, String downloadUrl})> presign({
    required String fileName,
    required String mimeType,
    required int size,
  }) async {
    final j = _j(
      await _d.post(
        '/media/presign',
        data: {'fileName': fileName, 'mimeType': mimeType, 'size': size},
      ),
    );
    return (
      key: j['key'] as String,
      uploadUrl: j['uploadUrl'] as String,
      downloadUrl: j['downloadUrl'] as String,
    );
  }

  Future<void> uploadBytes(String url, List<int> bytes, String mimeType) async {
    await _d.put(
      url,
      data: bytes,
      options: Options(
        headers: {'Content-Type': mimeType},
        followRedirects: true,
      ),
    );
  }

  // ── Statuses ────────────────────────────────────────────────────────────
  Future<GbStatus> createStatus({
    String? mediaKey,
    String? caption,
    Map<String, dynamic>? mediaMeta,
    String kind = 'IMAGE',
  }) async => GbStatus.fromJson(
    _j(
      await _d.post(
        '/statuses',
        data: {
          'mediaKey': mediaKey,
          'caption': caption,
          'mediaMeta': mediaMeta,
          'kind': kind,
        },
      ),
    ),
  );

  Future<List<GbStatus>> statusFeed() async => _l(
    await _d.get('/statuses/feed'),
  ).map((e) => GbStatus.fromJson((e as Map).cast<String, dynamic>())).toList();

  Future<void> viewStatus(String id) => _d.post('/statuses/$id/view');
  Future<void> deleteStatus(String id) => _d.delete('/statuses/$id');

  // ── Calls ───────────────────────────────────────────────────────────────
  Future<({String token, String serverUrl})> callToken(String roomId) async {
    final j = _j(await _d.post('/calls/token', data: {'roomId': roomId}));
    return (token: j['token'] as String, serverUrl: j['serverUrl'] as String);
  }

  Future<List<CallLog>> callLogs() async => _l(
    await _d.get('/calls/logs'),
  ).map((e) => CallLog.fromJson((e as Map).cast<String, dynamic>())).toList();

  // ── Message Actions ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> addReaction(
    String messageId,
    String emoji,
  ) async => _j(
    await _d.post('/messages/$messageId/reactions', data: {'emoji': emoji}),
  );

  Future<void> removeReaction(String messageId) =>
      _d.delete('/messages/$messageId/reactions');

  Future<Map<String, dynamic>> messageInfo(String messageId) async =>
      _j(await _d.get('/messages/$messageId/info'));

  Future<List<GbMessage>> forwardMessages(
    List<String> messageIds,
    String targetChatId,
  ) async {
    final r = await _d.post(
      '/messages/forward',
      data: {'messageIds': messageIds, 'targetChatId': targetChatId},
    );
    return (r.data as List)
        .map((e) => GbMessage.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<GbMessage>> searchMessages(String chatId, String q) async {
    final r = await _d.get('/chats/$chatId/search', queryParameters: {'q': q});
    return (r.data as List)
        .map((e) => GbMessage.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  // ── Copy ─────────────────────────────────────────────────────────────
  Future<void> copyMessage(String text) async {
    // ignore: unused_import
    // Clipboard.setData(ClipboardData(text: text)); // handled in UI
  }
}
