import 'package:flutter/material.dart';

/// Панель форматирования текста для сообщений.
class FormattingToolbar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;

  const FormattingToolbar({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  void _wrap(String left, String right) {
    final text = controller.text;
    final selection = controller.selection;
    final start = selection.start;
    final end = selection.end;
    final selected = start >= 0 && end >= 0 && start != end
        ? text.substring(start, end)
        : '';
    final newText = text.replaceRange(start, end, '$left$selected$right');
    controller.text = newText;
    controller.selection = TextSelection.collapsed(
      offset: start + left.length + selected.length,
    );
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2A3942),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          _btn(Icons.format_bold, 'Жирный', () => _wrap('**', '**')),
          _btn(Icons.format_italic, 'Курсив', () => _wrap('_', '_')),
          _btn(
            Icons.format_strikethrough,
            'Зачёркнутый',
            () => _wrap('~~', '~~'),
          ),
          _btn(Icons.code, 'Моно', () => _wrap('`', '`')),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, String tooltip, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, size: 20, color: const Color(0xFF8696A0)),
      tooltip: tooltip,
      onPressed: onTap,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}
