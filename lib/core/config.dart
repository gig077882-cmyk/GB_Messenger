/// Конфигурация приложения.
/// API base URL: Android-эмулятор видит хост через 10.0.2.2 или adb reverse.
/// Переопределение: flutter run --dart-define=API_BASE=http://192.168.0.10:3000/api
class AppConfig {
  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://127.0.0.1:3000/api',
  );
  static const bool logWs = bool.fromEnvironment('LOG_WS', defaultValue: true);
}
