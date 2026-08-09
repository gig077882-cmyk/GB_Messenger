import 'package:shared_preferences/shared_preferences.dart';

/// Хранилище токенов и сессии.
class TokenStorage {
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';

  Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  Future<void> saveTokens(String access, String refresh) async {
    final p = await _prefs;
    await p.setString(_kAccess, access);
    await p.setString(_kRefresh, refresh);
  }

  Future<void> clear() async {
    final p = await _prefs;
    await p.remove(_kAccess);
    await p.remove(_kRefresh);
  }

  Future<String?> accessToken() async => (await _prefs).getString(_kAccess);
  Future<String?> refreshToken() async => (await _prefs).getString(_kRefresh);
  Future<bool> hasSession() async => (await _prefs).containsKey(_kAccess);
}
