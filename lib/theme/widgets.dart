import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/media_cache.dart';
import '../core/models.dart';
import 'app_theme.dart';
import 'theme_scope.dart';

/// РђРІР°С‚Р°СЂ СЃ РёРЅРёС†РёР°Р»Р°РјРё, РѕРЅР»Р°Р№РЅ-С‚РѕС‡РєРѕР№ Рё РѕРїС†РёРѕРЅР°Р»СЊРЅРѕР№ Р·Р°РіСЂСѓР·РєРѕР№ РїРѕ СЃРµС‚Рё.
class GBAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;
  final bool online;
  final bool showOnline;
  final Widget? badge;

  const GBAvatar({
    super.key,
    this.url,
    required this.name,
    this.size = 48,
    this.online = false,
    this.showOnline = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final initials = name.isNotEmpty
        ? name.trim().split(RegExp(r'\s+')).take(2).map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase()
        : '?';
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(size / 2),
            child: _image(context, initials, theme),
          ),
          if (showOnline)
            Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                width: size * 0.3,
                height: size * 0.3,
                decoration: BoxDecoration(
                  color: theme.theme.online,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.theme.surface, width: 2),
                ),
              ),
            ),
          if (badge != null)
            Positioned(right: -2, bottom: -2, child: badge!),
        ],
      ),
    );
  }

  Widget _image(BuildContext context, String initials, ThemeProvider theme) {
    final fallback = ColoredBox(
      color: GBTheme.whatsAppPrimary.withValues(alpha: 0.3),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: size * 0.36,
          ),
        ),
      ),
    );
    final u = url ?? '';
    if (u.isEmpty) return fallback;
    final resolved = u.startsWith('http') ? u : '${AppConfig.apiBase}$u';
    return CachedNetworkImage(
      imageUrl: resolved,
      fit: BoxFit.cover,
      errorWidget: (_, _, _) => fallback,
      placeholder: (_, _) => fallback,
    );
  }
}

/// WhatsApp-style filled button with gradient.
class NeonButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool outline;

  const NeonButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.outline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: onPressed == null || outline ? null : softShadow(opacity: 0.15),
      ),
      child: outline
          ? OutlinedButton(
              onPressed: loading ? null : onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: GBTheme.whatsAppGreen,
                side: const BorderSide(color: GBTheme.whatsAppGreen, width: 1.2),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: loading
                  ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: GBTheme.whatsAppGreen))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                        Text(label),
                      ],
                    ),
            )
          : ElevatedButton(
              onPressed: loading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: GBTheme.whatsAppGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                        Text(label),
                      ],
                    ),
            ),
    );
  }
}

/// Р—Р°РіРѕР»РѕРІРѕРє СЃРµРєС†РёРё РІ СЃС‚РёР»Рµ WhatsApp.
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle({super.key, required this.text, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(text, style: TextStyle(
            color: theme.theme.textHint,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          )),
          const Spacer(),
          // ignore: use_null_aware_elements
          ...[if (trailing != null) trailing!],
        ],
      ),
    );
  }
}

/// Р“Р°Р»РѕС‡РєРё СЃС‚Р°С‚СѓСЃР° СЃРѕРѕР±С‰РµРЅРёСЏ РІ СЃС‚РёР»Рµ WhatsApp.
class StatusTicks extends StatelessWidget {
  final MessageStatus status;
  final double size;
  const StatusTicks({super.key, required this.status, this.size = 14});

  @override
  Widget build(BuildContext context) {
    if (status == MessageStatus.sending) {
      return SizedBox(
        width: size, height: size,
        child: CircularProgressIndicator(strokeWidth: 1.5, color: GBTheme.textSecondary),
      );
    }
    if (status == MessageStatus.failed) {
      return Icon(Icons.error_outline, size: size, color: Colors.red);
    }
    // WhatsApp style: single check = sent, double check = delivered, blue double = read
    if (status == MessageStatus.read) {
      return SizedBox(
        width: size * 1.8,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.done, size: size, color: GBTheme.whatsAppBlue),
            Transform.translate(
              offset: const Offset(-6, 0),
              child: Icon(Icons.done, size: size, color: GBTheme.whatsAppBlue),
            ),
          ],
        ),
      );
    }
    final color = status == MessageStatus.delivered ? GBTheme.textSecondary : GBTheme.textSecondary.withValues(alpha: 0.6);
    return SizedBox(
      width: size * 1.8,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.done, size: size, color: color),
          if (status == MessageStatus.delivered)
            Transform.translate(
              offset: const Offset(-6, 0),
              child: Icon(Icons.done, size: size, color: color),
            ),
        ],
      ),
    );
  }
}

/// РџСѓСЃС‚РѕРµ СЃРѕСЃС‚РѕСЏРЅРёРµ.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.theme.stroke),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: theme.theme.textMain)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, textAlign: TextAlign.center,
                  style: TextStyle(color: theme.theme.textHint, fontSize: 13)),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Р”Р°С‚Р° В«СЃРµРіРѕРґРЅСЏ / РІС‡РµСЂР° / 12:40В».
String shortDate(DateTime? dt) {
  if (dt == null) return '';
  final now = DateTime.now();
  final d = dt.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  String two(int v) => v.toString().padLeft(2, '0');
  if (diff == 0) return '${two(d.hour)}:${two(d.minute)}';
  if (diff == 1) return 'Р’С‡РµСЂР°';
  if (diff < 7) {
    const days = ['РџРЅ', 'Р’С‚', 'РЎСЂ', 'Р§С‚', 'РџС‚', 'РЎР±', 'Р’СЃ'];
    return days[d.weekday - 1];
  }
  return '${two(d.day)}.${two(d.month)}.${d.year}';
}

String shortTime(DateTime? dt) {
  if (dt == null) return '';
  final d = dt.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.hour)}:${two(d.minute)}';
}

/// Р›РѕРєР°Р»РёР·РѕРІР°РЅРЅС‹Р№ СЂР°Р·РјРµСЂ С„Р°Р№Р»Р°.
String fileSize(int bytes) {
  if (bytes < 1024) return '$bytes Р‘';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} РљР‘';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} РњР‘';
}

/// РР·РѕР±СЂР°Р¶РµРЅРёРµ СЃ Р»РѕРєР°Р»СЊРЅС‹Рј РєСЌС€РёСЂРѕРІР°РЅРёРµРј.
class MediaCachedImage extends StatelessWidget {
  final String url;
  final String cacheKey;
  final double width;
  final double height;
  final ThemeProvider theme;
  const MediaCachedImage({super.key, required this.url, required this.cacheKey, required this.width, required this.height, required this.theme});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: MediaCache.instance.getThumbnail(url, cacheKey),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Image.file(snapshot.data!, width: width, height: height, fit: BoxFit.cover);
        }
        return CachedNetworkImage(
          imageUrl: url,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => Container(
            width: width, height: height,
            color: theme.theme.bg,
            child: Icon(Icons.broken_image_outlined, color: theme.theme.textHint),
          ),
          placeholder: (_, _) => Container(
            width: width, height: height,
            color: theme.theme.bg,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        );
      },
    );
  }
}
