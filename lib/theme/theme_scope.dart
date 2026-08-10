import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Провайдер темы: хранит и позволяет переключать тему на лету.
class ThemeProvider extends ChangeNotifier {
  GBTheme _theme = const GBTheme();
  GBTheme get theme => _theme;

  void setDark(bool dark) {
    _theme = _theme.copyWith(isDark: dark);
    notifyListeners();
  }
}

/// Удобный доступ к теме.
class ThemeScope extends InheritedNotifier<ThemeProvider> {
  const ThemeScope({
    super.key,
    required ThemeProvider super.notifier,
    required super.child,
  });

  static ThemeProvider of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    return scope!.notifier!;
  }

  static ThemeProvider read(BuildContext context) {
    final scope = context.findAncestorWidgetOfExactType<ThemeScope>();
    return scope!.notifier!;
  }
}
