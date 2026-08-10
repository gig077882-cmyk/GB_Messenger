import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';

import '../../../core/config.dart';

/// РџРѕР»РЅРѕСЌРєСЂР°РЅРЅС‹Р№ РїСЂРѕСЃРјРѕС‚СЂ РёР·РѕР±СЂР°Р¶РµРЅРёР№ СЃ zoom/pan.
class MediaViewerScreen extends StatelessWidget {
  final String imageUrl;
  final String? caption;
  final bool viewOnce;

  const MediaViewerScreen({
    super.key,
    required this.imageUrl,
    this.caption,
    this.viewOnce = false,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = imageUrl.startsWith('http')
        ? imageUrl
        : '${AppConfig.apiBase}$imageUrl';
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PhotoView(
            imageProvider: CachedNetworkImageProvider(resolved),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            loadingBuilder: (_, _) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorBuilder: (_, _, _) => const Center(
              child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onPressed: () => _showOptions(context),
                    ),
                  ],
                ),
                const Spacer(),
                if (caption != null && caption!.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Colors.black54,
                    child: Text(
                      caption!,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: const Text('РЎРѕС…СЂР°РЅРёС‚СЊ РІ РіР°Р»РµСЂРµСЋ'),
              onTap: () async {
                Navigator.pop(context);
                await _saveToGallery(context);
              },
            ),
            if (!viewOnce)
              ListTile(
                leading: const Icon(Icons.forward),
                title: const Text('РџРµСЂРµСЃР»Р°С‚СЊ'),
                onTap: () => Navigator.pop(context),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveToGallery(BuildContext context) async {
    try {
      final resolved = imageUrl.startsWith('http')
          ? imageUrl
          : '${AppConfig.apiBase}$imageUrl';
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/media_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Dio().download(resolved, path);
      await GallerySaver.saveImage(path);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('РЎРѕС…СЂР°РЅРµРЅРѕ РІ РіР°Р»РµСЂРµСЋ')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('РћС€РёР±РєР°: $e')));
      }
    }
  }
}
