import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Безопасное хранилище токенов и сессии.
class TokenStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';

  Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
  }

  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }

  Future<String?> accessToken() async => await _storage.read(key: _kAccess);
  Future<String?> refreshToken() async => await _storage.read(key: _kRefresh);
  Future<bool> hasSession() async => (await accessToken()) != null;
}
