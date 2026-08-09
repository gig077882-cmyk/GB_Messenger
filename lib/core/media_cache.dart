import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:dio/dio.dart';

/// Локальный кэш медиа: thumbnails навсегда, оригиналы с LRU-лимитом.
class MediaCache {
  static final MediaCache instance = MediaCache._();
  MediaCache._();

  static const int _maxOriginalBytes = 300 * 1024 * 1024; // 300 МБ лимит
  final Dio _dio = Dio();

  Future<Directory> get _thumbDir async {
    final dir = await getApplicationDocumentsDirectory();
    final thumb = Directory(p.join(dir.path, 'thumbs'));
    if (!thumb.existsSync()) thumb.createSync(recursive: true);
    return thumb;
  }

  Future<Directory> get _origDir async {
    final dir = await getApplicationDocumentsDirectory();
    final orig = Directory(p.join(dir.path, 'media_orig'));
    if (!orig.existsSync()) orig.createSync(recursive: true);
    return orig;
  }

  /// Получить файл медиа по ключу (сначала кэш, потом скачать).
  Future<File?> getOrDownload(String url, String cacheKey, {bool original = false}) async {
    final dir = original ? await _origDir : await _thumbDir;
    final ext = p.extension(Uri.parse(url).path).isNotEmpty
        ? p.extension(Uri.parse(url).path)
        : '.jpg';
    final file = File(p.join(dir.path, '$cacheKey$ext'));
    if (file.existsSync()) return file;
    try {
      await _dio.download(url, file.path);
      if (original) await _enforceLruLimit();
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Thumbnail (маленький, кэшируем навсегда).
  Future<File?> getThumbnail(String url, String cacheKey) =>
      getOrDownload(url, '${cacheKey}_thumb', original: false);

  /// Оригинал (LRU с лимитом 300 МБ).
  Future<File?> getOriginal(String url, String cacheKey) =>
      getOrDownload(url, cacheKey, original: true);

  Future<void> _enforceLruLimit() async {
    final dir = await _origDir;
    final files = dir.listSync().whereType<File>().toList();
    files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
    var total = files.fold<int>(0, (sum, f) => sum + f.lengthSync());
    for (final f in files) {
      if (total <= _maxOriginalBytes) break;
      total -= f.lengthSync();
      try { f.deleteSync(); } catch (_) {}
    }
  }
}
