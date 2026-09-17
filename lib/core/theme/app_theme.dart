import 'package:flutter/material.dart';

/// The club's one brand accent — used only for buttons, links, active states,
/// and highlights. Everything else in the app is neutral gray so the accent
/// actually stands out instead of competing with a colorful background.
const _accentSeed = Color(0xFF0F5C4C);

class AppTheme {
  static ThemeData light() => _build(_lightColorScheme());

  static ThemeData dark() => _build(_darkColorScheme());

  static ColorScheme _lightColorScheme() {
    return ColorScheme.fromSeed(
      seedColor: _accentSeed,
      // Everything below overrides fromSeed's default tonal (green-tinted)
      // neutrals with true grayscale, so surfaces/text/borders read as
      // black-and-white and only primary/secondary carry the brand hue.
      surface: const Color(0xFFFAFAFA),
      onSurface: const Color(0xFF1C1C1C),
      surfaceDim: const Color(0xFFDDDDDD),
      surfaceBright: const Color(0xFFFAFAFA),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF4F4F4),
      surfaceContainer: const Color(0xFFEEEEEE),
      surfaceContainerHigh: const Color(0xFFE7E7E7),
      surfaceContainerHighest: const Color(0xFFE0E0E0),
      onSurfaceVariant: const Color(0xFF5B5B5B),
      outline: const Color(0xFFAEAEAE),
      outlineVariant: const Color(0xFFE0E0E0),
      inverseSurface: const Color(0xFF2E2E2E),
      onInverseSurface: const Color(0xFFF2F2F2),
      shadow: Colors.black,
      scrim: Colors.black,
    );
  }

  static ColorScheme _darkColorScheme() {
    return ColorScheme.fromSeed(
      seedColor: _accentSeed,
      brightness: Brightness.dark,
      surface: const Color(0xFF161616),
      onSurface: const Color(0xFFECECEC),
      surfaceDim: const Color(0xFF161616),
      surfaceBright: const Color(0xFF3A3A3A),
      surfaceContainerLowest: const Color(0xFF0E0E0E),
      surfaceContainerLow: const Color(0xFF1C1C1C),
      surfaceContainer: const Color(0xFF212121),
      surfaceContainerHigh: const Color(0xFF2B2B2B),
      surfaceContainerHighest: const Color(0xFF363636),
      onSurfaceVariant: const Color(0xFFA8A8A8),
      outline: const Color(0xFF5C5C5C),
      outlineVariant: const Color(0xFF3A3A3A),
      inverseSurface: const Color(0xFFE7E7E7),
      onInverseSurface: const Color(0xFF1C1C1C),
      shadow: Colors.black,
      scrim: Colors.black,
    );
  }

  static ThemeData _build(ColorScheme colorScheme) {
    final radius = BorderRadius.circular(10);
    final buttonShape = RoundedRectangleBorder(borderRadius: radius);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        labelStyle: TextStyle(color: colorScheme.onSurface),
        side: BorderSide.none,
      ),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(shape: buttonShape)),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: buttonShape, side: BorderSide(color: colorScheme.outline)),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(shape: buttonShape)),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
            color: states.contains(WidgetState.selected) ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: colorScheme.outline)),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: colorScheme.outline)),
        focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: colorScheme.primary, width: 2)),
      ),
    );
  }
}
