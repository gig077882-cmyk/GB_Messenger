import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api_service.dart';
import '../../core/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_scope.dart';
import '../../theme/widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiService _api = ApiService.instance;
  bool _uploading = false;

  Future<void> _changeAvatar() async {
    final app = context.read<AppState>();
    final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 82);
    if (p == null) return;
    final file = File(p.path);
    setState(() => _uploading = true);
    try {
      final pre = await _api.presign(
          fileName: p.name, mimeType: p.mimeType ?? 'image/jpeg', size: await file.length());
      await _api.uploadBytes(pre.uploadUrl, await file.readAsBytes(), p.mimeType ?? 'image/jpeg');
      final updated = await _api.patchMe({'avatarKey': pre.key, 'avatarUrl': pre.downloadUrl});
      app.updateMe(updated);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _editField(String title, String current, String field) async {
    final app = context.read<AppState>();
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Сохранить')),
        ],
      ),
    );
    if (result == null || result.isEmpty || result == current) return;
    try {
      final updated = await _api.patchMe({field: result});
      app.updateMe(updated);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final app = context.watch<AppState>();
    final me = app.me;
    return ListView(
      children: [
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _uploading ? null : _changeAvatar,
          child: Stack(
            alignment: Alignment.center,
            children: [
              GBAvatar(url: me?.avatarUrl, name: me?.displayName ?? '?', size: 80),
              if (_uploading)
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                ),
              Positioned(
                right: 0, bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: GBTheme.whatsAppGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.theme.surface, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(me?.displayName ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        ),
        if (me?.phone != null && me!.phone!.isNotEmpty)
          Center(
            child: Text(me.phone!, style: TextStyle(color: theme.theme.textHint, fontSize: 13)),
          ),
        Center(
          child: Text(me?.email ?? '', style: TextStyle(color: theme.theme.textHint, fontSize: 13)),
        ),
        const SizedBox(height: 24),
        _SettingTile(
          icon: Icons.phone_outlined,
          title: 'Телефон',
          subtitle: me?.phone?.isNotEmpty == true ? me!.phone! : 'Добавить',
          onTap: () => _editField('Телефон', me?.phone ?? '', 'phone'),
        ),
        _SettingTile(
          icon: Icons.person_outline,
          title: 'Имя',
          subtitle: me?.displayName ?? '',
          onTap: () => _editField('Имя', me?.displayName ?? '', 'displayName'),
        ),
        _SettingTile(
          icon: Icons.info_outline,
          title: 'О себе',
          subtitle: me?.bio?.isNotEmpty == true ? me!.bio! : 'Добавить',
          onTap: () => _editField('О себе', me?.bio ?? '', 'bio'),
        ),
        const Divider(height: 1),
        _SettingTile(
          icon: theme.theme.isDark ? Icons.dark_mode : Icons.light_mode,
          title: 'Тема',
          subtitle: theme.theme.isDark ? 'Тёмная' : 'Светлая',
          trailing: Switch(
            value: theme.theme.isDark,
            activeTrackColor: GBTheme.whatsAppGreen,
            onChanged: (v) => theme.setDark(v),
          ),
        ),
        _SettingTile(
          icon: app.connected ? Icons.wifi : Icons.wifi_off,
          title: app.connected ? 'Подключено' : 'Нет соединения',
        ),
        const Divider(height: 1),
        _SettingTile(
          icon: Icons.info_outline,
          title: 'GB Messenger',
          subtitle: 'v1.0.0',
        ),
        _SettingTile(
          icon: Icons.logout,
          title: 'Выйти',
          titleColor: Colors.red,
          onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Выйти из аккаунта?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Выйти', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
             if (ok == true && context.mounted) {
               await context.read<AppState>().logout();
             }
          },
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;

  const _SettingTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.theme.textHint),
      title: Text(title, style: TextStyle(color: titleColor)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: const TextStyle(fontSize: 12.5)),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
