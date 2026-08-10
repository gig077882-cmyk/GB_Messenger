import 'package:flutter/material.dart';

import '../../../core/models.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/theme_scope.dart';

/// Показывает реакции под пузырём сообщения.
class ReactionBar extends StatelessWidget {
  final GbMessage message;
  final String myId;
  final VoidCallback onTapReaction;

  const ReactionBar({
    super.key,
    required this.message,
    required this.myId,
    required this.onTapReaction,
  });

  @override
  Widget build(BuildContext context) {
    if (message.reactions.isEmpty) return const SizedBox.shrink();
    final theme = ThemeScope.of(context);

    // Группируем по emoji
    final groups = <String, List<String>>{};
    for (final r in message.reactions) {
      groups.putIfAbsent(r.emoji, () => []).add(r.userId);
    }

    return GestureDetector(
      onTap: onTapReaction,
      child: Container(
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: theme.theme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.theme.stroke),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: groups.entries.map((e) {
            final mine = e.value.contains(myId);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(e.key, style: const TextStyle(fontSize: 13)),
                  if (e.value.length > 1) ...[
                    const SizedBox(width: 2),
                    Text(
                      '${e.value.length}',
                      style: TextStyle(
                        fontSize: 11,
                        color: mine
                            ? GBTheme.whatsAppGreen
                            : theme.theme.textHint,
                        fontWeight: mine ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Popup для выбора эмодзи-реакции.
class ReactionPicker extends StatelessWidget {
  final GbMessage message;
  final String myId;
  final Function(String emoji) onSelect;

  static const emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  const ReactionPicker({
    super.key,
    required this.message,
    required this.myId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final myReaction = message.reactions
        .where((r) => r.userId == myId)
        .firstOrNull;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.theme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: emojis.map((e) {
          final selected = myReaction?.emoji == e;
          return GestureDetector(
            onTap: () => onSelect(e),
            child: Container(
              padding: const EdgeInsets.all(6),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: selected
                    ? GBTheme.whatsAppGreen.withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(e, style: const TextStyle(fontSize: 22)),
            ),
          );
        }).toList(),
      ),
    );
  }
}
