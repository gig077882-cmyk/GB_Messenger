import 'package:flutter/material.dart';

import '../../core/update_service.dart';
import '../../theme/app_theme.dart';

class UpdateBanner extends StatefulWidget {
  final ReleaseInfo release;
  final VoidCallback onDismiss;

  const UpdateBanner({
    super.key,
    required this.release,
    required this.onDismiss,
  });

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  bool _downloading = false;
  double _progress = 0;

  Future<void> _update() async {
    if (UpdateService.platform == UpdatePlatform.ios) {
      await UpdateService().openReleasePage();
      return;
    }

    setState(() {
      _downloading = true;
      _progress = 0;
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

    if (path != null && mounted) {
      await service.installApk(path);
    }

    if (mounted) {
      setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GBTheme.whatsAppGreen,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.system_update, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Доступно обновление v${widget.release.version}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (_downloading) ...[
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ],
                  ],
                ),
              ),
              if (!_downloading) ...[
                TextButton(
                  onPressed: _update,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white24,
                  ),
                  child: Text(
                    UpdateService.platform == UpdatePlatform.ios
                        ? 'Открыть на GitHub'
                        : 'Обновить',
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: widget.onDismiss,
                  icon: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
