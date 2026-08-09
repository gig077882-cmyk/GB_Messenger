import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_service.dart';
import '../../core/app_state.dart';
import '../../core/models.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_scope.dart';
import '../../theme/widgets.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  final ApiService _api = ApiService.instance;
  List<CallLog> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _api.callLogs();
      if (mounted) {
        setState(() { _logs = r; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = ThemeScope.of(context);
    return RefreshIndicator(
      color: GBTheme.whatsAppGreen,
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const EmptyState(
                  icon: Icons.call_outlined,
                  title: 'РќРµС‚ Р·РІРѕРЅРєРѕРІ',
                  subtitle: 'РСЃС‚РѕСЂРёСЏ Р·РІРѕРЅРєРѕРІ РїРѕСЏРІРёС‚СЃСЏ Р·РґРµСЃСЊ')
              : ListView.separated(
                  itemCount: _logs.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1, indent: 76, endIndent: 16, color: theme.theme.stroke,
                  ),
                  itemBuilder: (_, i) {
                    final l = _logs[i];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 26,
                        backgroundColor: GBTheme.whatsAppGreen.withValues(alpha: 0.15),
                        child: Icon(
                          l.kind == 'VIDEO' ? Icons.videocam : Icons.phone,
                          color: GBTheme.whatsAppGreen,
                        ),
                      ),
                      title: Text(
                        l.callerId == app.myId ? 'РСЃС…РѕРґСЏС‰РёР№' : 'Р’С…РѕРґСЏС‰РёР№',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: l.status == 'missed' ? Colors.red : theme.theme.textMain,
                        ),
                      ),
                      subtitle: Text(
                        '${_statusLabel(l.status)} В· ${shortDate(l.startedAt)}',
                        style: TextStyle(fontSize: 13, color: theme.theme.textHint),
                      ),
                      trailing: Icon(
                        l.kind == 'VIDEO' ? Icons.videocam : Icons.phone,
                        color: GBTheme.whatsAppGreen,
                      ),
                    );
                  },
                ),
    );
  }

  String _statusLabel(String s) => switch (s) {
        'completed' => 'Р—Р°РІРµСЂС€С‘РЅ',
        'missed' => 'РџСЂРѕРїСѓС‰РµРЅ',
        'rejected' => 'РћС‚РєР»РѕРЅС‘РЅ',
        'cancelled' => 'РћС‚РјРµРЅС‘РЅ',
        _ => s,
      };
}
