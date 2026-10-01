import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'palette.dart';

abstract final class AppTheme {
  static ThemeData of(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final p = isDark ? AppPalette.dark : AppPalette.light;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.pine,
      onPrimary: p.onPine,
      primaryContainer: p.pineSoft,
      onPrimaryContainer: p.ink,
      secondary: p.pine,
      onSecondary: p.onPine,
      secondaryContainer: p.pineSoft,
      onSecondaryContainer: p.pineText,
      error: const Color(0xFFB3261E),
      onError: Colors.white,
      surface: p.card,
      onSurface: p.ink,
      onSurfaceVariant: p.ink2,
      surfaceContainerHighest: p.chip,
      outline: p.ink3,
      outlineVariant: p.line,
      surfaceTint: Colors.transparent,
    );

    final base = ThemeData(brightness: brightness).textTheme
        .apply(fontFamily: AppFonts.sans, bodyColor: p.ink, displayColor: p.ink);
    TextStyle display(TextStyle? s, double size, FontWeight w) => (s ?? const TextStyle()).copyWith(
      fontFamily: AppFonts.display,
      fontSize: size,
      fontWeight: w,
      letterSpacing: -0.4,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: p.bg,
      extensions: [p],
      textTheme: base.copyWith(
        displaySmall: display(base.displaySmall, 40, FontWeight.w600),
        headlineMedium: display(base.headlineMedium, 32, FontWeight.w500),
        headlineSmall: display(base.headlineSmall, 26, FontWeight.w600),
        titleLarge: display(base.titleLarge, 20, FontWeight.w500),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        foregroundColor: p.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.display,
          fontSize: 22,
          fontWeight: FontWeight.w500,
          color: p.ink,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.card,
        indicatorColor: p.pineSoft,
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? p.pineText : p.ink3),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? p.ink : p.ink3,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontFamily: AppFonts.sans, fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: p.pine,
          selectedForegroundColor: p.onPine,
          side: BorderSide(color: p.line),
          textStyle: const TextStyle(fontFamily: AppFonts.sans, fontWeight: FontWeight.w600),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.pine : null),
      ),
      dividerTheme: DividerThemeData(color: p.line, space: 1, thickness: 1),
    );
  }
}
