import 'package:dio/dio.dart';

import 'config.dart';
import 'token_storage.dart';

/// REST-клиент с автоподстановкой Bearer-токена и refresh-логикой.
class ApiClient {
  late final Dio dio;

  ApiClient() {
    dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBase,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (o, h) async {
        final t = await TokenStorage().accessToken();
        if (t != null) o.headers['Authorization'] = 'Bearer $t';
        h.next(o);
      },
      onError: (e, h) async {
        if (e.response?.statusCode == 401 && e.requestOptions.path != '/auth/login') {
          final refreshed = await _tryRefresh();
          if (refreshed) {
            final t = await TokenStorage().accessToken();
            e.requestOptions.headers['Authorization'] = 'Bearer $t';
            h.resolve(await dio.fetch(e.requestOptions));
            return;
          }
        }
        h.next(e);
      },
    ));
  }

  Future<bool> _tryRefresh() async {
    final rt = await TokenStorage().refreshToken();
    if (rt == null) return false;
    try {
      final r = await dio.post('/auth/refresh', data: {'refreshToken': rt});
      final d = r.data as Map<String, dynamic>;
      await TokenStorage().saveTokens(d['accessToken'] as String, d['refreshToken'] as String);
      return true;
    } catch (_) {
      await TokenStorage().clear();
      return false;
    }
  }
}
