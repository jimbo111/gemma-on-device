import 'package:flutter/material.dart';

/// Design tokens and [ThemeData] for the app. Dark-only.
abstract final class AppTheme {
  static const Color background = Color(0xFF000000);

  /// Status strip under the app bar.
  static const Color surfaceSunken = Color(0xFF0C0C0C);

  /// Cards, input bar, AI chat bubble.
  static const Color surface = Color(0xFF181818);

  /// Text field fill.
  static const Color surfaceElevated = Color(0xFF1E1E1E);

  /// Progress track.
  static const Color track = Color(0xFF2A2A2A);

  /// Disabled button fill.
  static const Color disabled = Color(0xFF333333);

  /// Primary accent; also the user chat bubble.
  static const Color accent = Color(0xFF47A1E6);

  static const Color success = Color(0xFF5BC682);
  static const Color error = Color(0xFFCD5454);

  static const Color textPrimary = Color(0xFFFFFFFF);

  /// AI message body text (90% white).
  static const Color textBody = Color(0xE6FFFFFF);

  /// Secondary / hint text (50% white).
  static const Color textSecondary = Color(0x80FFFFFF);

  static const double radiusDefault = 24.0;
  static const double radiusSmall = 12.0;

  /// Chat bubble corners; the tail corner sits on the sender's side.
  static const double radiusBubble = 20.0;
  static const double radiusBubbleTail = 4.0;

  static ThemeData get darkTheme {
    // Build an explicit ColorScheme rather than using fromSeed so that every
    // generated surface/container slot maps to an intentional design value.
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,

      primary: accent,
      onPrimary: textPrimary,
      primaryContainer: surfaceElevated,
      onPrimaryContainer: textPrimary,

      secondary: accent,
      onSecondary: textPrimary,
      secondaryContainer: surface,
      onSecondaryContainer: textPrimary,

      tertiary: success,
      onTertiary: textPrimary,
      tertiaryContainer: surface,
      onTertiaryContainer: textPrimary,

      error: error,
      onError: textPrimary,
      errorContainer: Color(0xFF3B1A1A),
      onErrorContainer: error,

      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: surfaceElevated,
      surfaceContainerHigh: surface,
      surfaceContainer: surface,
      surfaceContainerLow: surface,
      surfaceContainerLowest: background,
      surfaceDim: background,
      surfaceBright: surfaceElevated,

      outline: Color(0xFF2C2C2C),
      outlineVariant: Color(0xFF1F1F1F),

      shadow: Color(0x14000000),
      scrim: Color(0xFF000000),

      inverseSurface: textPrimary,
      onInverseSurface: background,
      inversePrimary: accent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,

      scaffoldBackgroundColor: background,

      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        hintStyle: const TextStyle(
          color: textSecondary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radiusSmall)),
          ),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textPrimary,
          highlightColor: Colors.white10,
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: surface,
        circularTrackColor: surface,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceElevated,
        contentTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        actionTextColor: accent,
        elevation: 4,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusSmall)),
        ),
      ),

      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: textPrimary,
          fontSize: 57,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.5,
          height: 1.12,
        ),
        displayMedium: TextStyle(
          color: textPrimary,
          fontSize: 45,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.16,
        ),
        displaySmall: TextStyle(
          color: textPrimary,
          fontSize: 36,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          height: 1.22,
        ),
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.25,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          height: 1.29,
        ),
        headlineSmall: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          height: 1.33,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          height: 1.27,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
          height: 1.5,
        ),
        titleSmall: TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          height: 1.43,
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          height: 1.43,
        ),
        bodySmall: TextStyle(
          color: textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.1,
          height: 1.33,
        ),
        labelLarge: TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          height: 1.43,
        ),
        labelMedium: TextStyle(
          color: textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          height: 1.33,
        ),
        labelSmall: TextStyle(
          color: textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          height: 1.45,
        ),
      ),
    );
  }
}
