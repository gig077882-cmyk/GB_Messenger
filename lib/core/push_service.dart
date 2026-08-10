import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../core/api_service.dart';
import '../core/local_db.dart';

/// Background message handler MUST be a top-level function.
/// Runs in isolation — can access LocalDatabase (singleton) to cache the message.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    return;
  }
  final data = message.data;
  final chatId = data['chatId'] as String?;
  if (chatId == null || chatId.isEmpty) return;
  // Кэшируем факт нового сообщения, чтобы при тапе история уже была.
  try {
    final db = LocalDatabase.instance;
    await db.updateChatMeta(chatId, DateTime.now(), 1);
  } catch (_) {}
}

/// Push notifications via FCM. Gracefully disabled if Firebase is not
/// configured (no google-services.json at build time), so the rest of the
/// app keeps working in local development.
class PushService {
  static final PushService instance = PushService._();
  PushService._();

  FirebaseMessaging? _messaging;
  bool _initialized = false;
  String? _lastToken;

  final _inAppController = StreamController<InAppNotification>.broadcast();
  Stream<InAppNotification> get onInAppNotification => _inAppController.stream;

  bool get enabled => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp();
      _messaging = FirebaseMessaging.instance;
    } catch (e) {
      debugPrint('[push] Firebase not configured, push disabled: $e');
      return;
    }

    try {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      final permitted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!permitted) {
        debugPrint('[push] permission denied');
        return;
      }

      final token = await _messaging!.getToken();
      if (token != null) {
        await _registerWithServer(token);
      }

      _messaging!.onTokenRefresh.listen(_registerWithServer);

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);

      final initial = await _messaging!.getInitialMessage();
      if (initial != null) {
        _handleNotificationTap(initial.data);
      }

      _initialized = true;
      debugPrint('[push] initialized, token=${token?.substring(0, 12)}...');
    } catch (e) {
      debugPrint('[push] init error: $e');
    }
  }

  /// Повторная регистрация токена после авторизации (первая попытка могла
  /// пройти с 401, т.к. пользователь был не залогинен).
  Future<void> ensureRegistered() async {
    if (!_initialized || _messaging == null) return;
    final token = await _messaging!.getToken();
    if (token != null && token != _lastToken) {
      _lastToken = token;
      await _registerWithServer(token);
    }
  }

  Future<void> _registerWithServer(String token) async {
    try {
      final platform = defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android';
      await ApiService.instance.registerPushToken(
        token: token,
        platform: platform,
      );
    } catch (e) {
      debugPrint('[push] token registration failed: $e');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final chatId = data['chatId'] as String?;
    if (chatId == null) return;
    debugPrint('[push] foreground message: chatId=$chatId');
    _inAppController.add(
      InAppNotification(
        chatId: chatId,
        senderName: data['senderName'] as String? ?? '',
        body: message.notification?.body ?? data['preview'] as String? ?? '',
        avatarUrl: data['avatarUrl'] as String?,
      ),
    );
    onForegroundMessage?.call(
      chatId,
      data['senderName'] as String? ?? '',
      message.notification?.body ?? data['preview'] as String? ?? '',
    );
  }

  void _onMessageOpened(RemoteMessage message) {
    _handleNotificationTap(message.data);
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    final chatId = data['chatId'] as String?;
    if (chatId == null || chatId.isEmpty) return;
    onNotificationTap?.call(chatId);
  }

  /// Called when a push notification (data) should navigate to a chat.
  void Function(String chatId)? onNotificationTap;

  /// Called when a message arrives in foreground (app open).
  void Function(String chatId, String senderName, String body)?
  onForegroundMessage;

  void dispose() {
    _inAppController.close();
  }
}

class InAppNotification {
  final String chatId;
  final String senderName;
  final String body;
  final String? avatarUrl;
  InAppNotification({
    required this.chatId,
    required this.senderName,
    required this.body,
    this.avatarUrl,
  });
}
