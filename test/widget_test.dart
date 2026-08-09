import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gb_messenger/theme/app_theme.dart';

void main() {
  test('WhatsApp зелёный цвет', () {
    expect(GBTheme.whatsAppGreen, const Color(0xFF25D366));
  });

  test('тёмная тема применима', () {
    const theme = GBTheme();
    expect(theme.isDark, false);
    expect(GBTheme.whatsAppGreen, const Color(0xFF25D366));
  });

  test('светлая тема', () {
    final theme = const GBTheme(isDark: false);
    expect(theme.isDark, false);
    expect(theme.bg, const Color(0xFFF0F2F5));
  });
}
