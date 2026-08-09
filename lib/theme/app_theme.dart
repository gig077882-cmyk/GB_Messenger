import 'package:flutter/material.dart';

/// Акцентные цвета на выбор пользователя.
class AccentColor {
  final String name;
  final Color value;
  final Color onValue;
  const AccentColor(this.name, this.value, this.onValue);

  static const green = AccentColor('WhatsApp', Color(0xFF25D366), Colors.white);
  static const teal = AccentColor('Бирюзовый', Color(0xFF128C7E), Colors.white);
  static const blue = AccentColor('Синий', Color(0xFF4D9FFF), Colors.white);
  static const purple = AccentColor('Фиолетовый', Color(0xFFB44DFF), Colors.white);
  static const pink = AccentColor('Розовый', Color(0xFFFF4D8F), Colors.white);
  static const orange = AccentColor('Оранжевый', Color(0xFFFF8C4D), Colors.white);

  static const all = [green, teal, blue, purple, pink, orange];
}

/// Тема WhatsApp Liquid Glass 2026.
class GBTheme {
  final bool isDark;
  final AccentColor accent;

  const GBTheme({
    this.isDark = false,
    this.accent = AccentColor.green,
  });

  // WhatsApp signature colors
  static const Color whatsAppDark = Color(0xFF075E54);
  static const Color whatsAppPrimary = Color(0xFF128C7E);
  static const Color whatsAppGreen = Color(0xFF25D366);
  static const Color whatsAppLight = Color(0xFFDCF8C6);
  static const Color whatsAppBlue = Color(0xFF34B7F1);
  static const Color chatBg = Color(0xFFECE5DD);
  static const Color chatBgDark = Color(0xFF0B141A);
  static const Color textPrimary = Color(0xFF111B21);
  static const Color textSecondary = Color(0xFF667781);
  static const Color bubbleOut = Color(0xFFDCF8C6);
  static const Color bubbleOutDark = Color(0xFF005C4B);
  static const Color bubbleIn = Color(0xFFFFFFFF);
  static const Color bubbleInDark = Color(0xFF1F2C34);
  static const Color surfaceLight = Color(0xFFF0F2F5);
  static const Color surfaceDark = Color(0xFF111B21);
  static const Color divider = Color(0xFFE9EDEF);

  Color get bg => isDark ? surfaceDark : surfaceLight;
  Color get surface => isDark ? const Color(0xFF1F2C34) : Colors.white;
  Color get surfaceHigh => isDark ? const Color(0xFF2A3942) : const Color(0xFFF5F5F5);
  Color get stroke => isDark ? const Color(0xFF2A3942) : divider;
  Color get textMain => isDark ? const Color(0xFFE9EDF0) : textPrimary;
  Color get textHint => isDark ? const Color(0xFF8696A0) : textSecondary;
  Color get danger => const Color(0xFFFF4D4D);
  Color get online => whatsAppGreen;
  Color get bubbleMine => isDark ? bubbleOutDark : bubbleOut;
  Color get bubbleOther => isDark ? bubbleInDark : bubbleIn;
  Color get textMine => isDark ? const Color(0xFFE9EDF0) : textPrimary;
  Color get textOther => isDark ? const Color(0xFFE9EDF0) : textPrimary;

  LinearGradient get bubbleOutGradient => isDark
      ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF005C4B), Color(0xFF006E58)],
        )
      : const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDCF8C6), Color(0xFFD4F4BE)],
        );

  LinearGradient get primaryGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF25D366), Color(0xFF128C7E)],
      );

  ThemeData build() {
    final base = isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: base.colorScheme.copyWith(
        primary: whatsAppGreen,
        onPrimary: Colors.white,
        secondary: whatsAppPrimary,
        onSecondary: Colors.white,
        surface: surface,
        onSurface: textMain,
        error: danger,
      ),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: whatsAppDark,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
      dividerTheme: DividerThemeData(color: stroke, thickness: 0.6),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: whatsAppGreen,
        selectionColor: whatsAppGreen.withValues(alpha: 0.2),
        selectionHandleColor: whatsAppGreen,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: textHint),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: whatsAppGreen, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: whatsAppGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: whatsAppGreen),
      ),
      iconTheme: IconThemeData(color: textHint),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: whatsAppGreen),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: whatsAppGreen,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? surfaceDark : Colors.white,
        contentTextStyle: TextStyle(color: textMain),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textHint,
        textColor: textMain,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: isDark ? whatsAppGreen : whatsAppDark,
        unselectedItemColor: textHint,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  GBTheme copyWith({bool? isDark, AccentColor? accent}) => GBTheme(
        isDark: isDark ?? this.isDark,
        accent: accent ?? this.accent,
      );
}

/// Неоновое свечение для акцентов.
List<BoxShadow> glow({Color color = const Color(0xFF25D366), double blur = 20}) => [
      BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: blur, spreadRadius: 0),
      BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: blur * 2),
    ];

/// WhatsApp-style layered shadow.
List<BoxShadow> softShadow({double opacity = 0.08}) => [
      BoxShadow(
        color: Colors.black.withValues(alpha: opacity),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: opacity * 0.5),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ];
