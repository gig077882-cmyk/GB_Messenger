import 'package:flutter/material.dart';

import '../../core/update_service.dart';
import '../../theme/app_theme.dart';

class ForceUpdateScreen extends StatefulWidget {
  final ReleaseInfo release;

  const ForceUpdateScreen({super.key, required this.release});

  @override
  State<ForceUpdateScreen> createState() => _ForceUpdateScreenState();
}

class _ForceUpdateScreenState extends State<ForceUpdateScreen> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startUpdate();
  }

  Future<void> _startUpdate() async {
    if (UpdateService.platform == UpdatePlatform.ios) {
      await UpdateService().openReleasePage();
      return;
    }

    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });

    final service = UpdateService();
    final path = await service.downloadApk(widget.release.downloadUrl, (
      received,
      total,
    ) {
      if (total > 0 && mounted) {
        setState(() => _progress = received / total);
      }
    });

    if (path == null) {
      setState(() {
        _downloading = false;
        _error = 'Не удалось скачать обновление';
      });
      return;
    }

    final ok = await service.installApk(path);
    if (!ok && mounted) {
      setState(() {
        _downloading = false;
        _error = 'Не удалось установить обновление';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GBTheme.chatBgDark,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: GBTheme.whatsAppGreen.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.system_update,
                    size: 40,
                    color: GBTheme.whatsAppGreen,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Требуется обновление',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Для продолжения работы необходимо установить обновление v${widget.release.version}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.white60),
                ),
                const SizedBox(height: 32),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_downloading) ...[
                  LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation(
                      GBTheme.whatsAppGreen,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ] else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _startUpdate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GBTheme.whatsAppGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        UpdateService.platform == UpdatePlatform.ios
                            ? 'Открыть на GitHub'
                            : 'Повторить',
                      ),
                    ),
                  ),
                if (widget.release.changelog.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Что нового:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.release.changelog,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
