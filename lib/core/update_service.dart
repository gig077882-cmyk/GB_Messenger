import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class ReleaseInfo {
  final String version;
  final String downloadUrl;
  final String changelog;
  final bool isCritical;
  final DateTime publishedAt;

  ReleaseInfo({
    required this.version,
    required this.downloadUrl,
    required this.changelog,
    required this.isCritical,
    required this.publishedAt,
  });
}

class UpdateService {
  static const String _repo = 'gig077882-cmyk/GB_Messenger';
  static const String _apiUrl =
      'https://api.github.com/repos/$_repo/releases/latest';

  Future<ReleaseInfo?> checkForUpdate() async {
    try {
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode != 200) return null;

      final data = _parseJson(response.body);
      if (data == null) return null;

      final tag = (data['tag_name'] as String?)?.replaceAll('v', '') ?? '';
      if (tag.isEmpty) return null;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (!_isNewerVersion(currentVersion, tag)) return null;

      final assets = data['assets'] as List?;
      if (assets == null || assets.isEmpty) return null;

      String? downloadUrl;
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          downloadUrl = asset['browser_download_url'] as String?;
          break;
        }
      }

      if (downloadUrl == null) return null;

      return ReleaseInfo(
        version: tag,
        downloadUrl: downloadUrl,
        changelog: (data['body'] as String?) ?? '',
        isCritical: data['prerelease'] == true,
        publishedAt: DateTime.tryParse(data['published_at'] as String? ?? '') ??
            DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> downloadApk(
    String url,
    Function(int received, int total) onProgress,
  ) async {
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await request.send();

      if (response.statusCode != 200) return null;

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/update.apk';
      final file = File(path);

      final sink = file.openWrite();
      int received = 0;
      final total = response.contentLength ?? 0;

      await response.stream.listen(
        (chunk) {
          sink.add(chunk);
          received += chunk.length;
          onProgress(received, total);
        },
        onDone: () async {
          await sink.close();
        },
        onError: (_) async {
          await sink.close();
        },
        cancelOnError: true,
      ).asFuture();

      return path;
    } catch (_) {
      return null;
    }
  }

  Future<bool> installApk(String filePath) async {
    try {
      if (!Platform.isAndroid) return false;
      final result = await OpenFilex.open(filePath);
      return result.type == ResultType.done;
    } catch (_) {
      return false;
    }
  }

  bool _isNewerVersion(String current, String latest) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final latestParts = latest.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        final c = i < currentParts.length ? currentParts[i] : 0;
        final l = i < latestParts.length ? latestParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic>? _parseJson(String body) {
    try {
      return Map<String, dynamic>.from(
        json.decode(body) as Map,
      );
    } catch (_) {
      return null;
    }
  }
}
