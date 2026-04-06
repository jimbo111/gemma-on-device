import 'package:flutter/material.dart';

/// Central theme definition for On-Device AI.
///
/// This app is dark-only. All color values are sourced from the React Native
/// design reference so the two implementations stay visually in sync.
abstract final class AppTheme {
  // ---------------------------------------------------------------------------
  // Color constants — reference these directly in widgets for one-off overrides
  // ---------------------------------------------------------------------------

  /// True black scaffold / page background.
  static const Color background = Color(0xFF000000);

  /// Default card / list-item surface.
  static const Color surface = Color(0xFF181818);

  /// Elevated dialogs, bottom sheets, input fields.
  static const Color surfaceElevated = Color(0xFF1E1E1E);

  /// Primary accent — also used as the user chat bubble background.
  static const Color accent = Color(0xFF47A1E6);

  /// AI response chat bubble background.
  static const Color bubble = Color(0xFF181818);

  /// User chat bubble background (alias for [accent]).
  static const Color userBubble = accent;

  /// Positive / success state.
  static const Color success = Color(0xFF5BC682);

  /// Error / destructive state.
  static const Color error = Color(0xFFCD5454);

  /// Full-opacity body text.
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// 50 % opacity secondary / hint text  (rgba 255,255,255,0.5).
  static const Color textSecondary = Color(0x80FFFFFF);

  /// Subtle shadow color  (rgba 0,0,0,0.08).
  static const Color shadow = Color(0x14000000);

  // ---------------------------------------------------------------------------
  // Shared shape geometry
  // ---------------------------------------------------------------------------

  /// Default corner radius for cards and bottom sheets (24 dp).
  static const double radiusDefault = 24.0;

  /// Larger corner radius for prominent containers (32 dp).
  static const double radiusLarge = 32.0;

  /// Small corner radius for chips, badges (12 dp).
  static const double radiusSmall = 12.0;

  // ---------------------------------------------------------------------------
  // ThemeData
  // ---------------------------------------------------------------------------

  static ThemeData get darkTheme {
    // Build an explicit ColorScheme rather than using fromSeed so that every
    // generated surface/container slot maps to an intentional design value.
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,

      // Brand colors
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

      // Error
      error: error,
      onError: textPrimary,
      errorContainer: Color(0xFF3B1A1A),
      onErrorContainer: error,

      // Backgrounds and surfaces
      // surface → used by Card, Dialog, BottomSheet, etc.
      surface: surface,
      onSurface: textPrimary,
      // surfaceContainerHigh → used by ChatBubble for AI messages
      surfaceContainerHighest: surfaceElevated,
      surfaceContainerHigh: bubble,
      surfaceContainer: surface,
      surfaceContainerLow: surface,
      surfaceContainerLowest: background,
      surfaceDim: background,
      surfaceBright: surfaceElevated,

      // Scheme background (deprecated slot, kept for back-compat widgets)
      // ignore: deprecated_member_use
      background: background,
      // ignore: deprecated_member_use
      onBackground: textPrimary,

      outline: Color(0xFF2C2C2C),
      outlineVariant: Color(0xFF1F1F1F),

      shadow: shadow,
      scrim: Color(0xFF000000),

      inverseSurface: textPrimary,
      onInverseSurface: background,
      inversePrimary: accent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,

      // Scaffold
      scaffoldBackgroundColor: background,

      // AppBar
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

      // Cards
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusDefault)),
        ),
        margin: EdgeInsets.zero,
      ),

      // Dialogs
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceElevated,
        elevation: 8,
        shadowColor: shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusLarge)),
        ),
        titleTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        contentTextStyle: const TextStyle(
          color: textSecondary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
      ),

      // Bottom sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceElevated,
        modalBackgroundColor: surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusLarge),
          ),
        ),
      ),

      // Input / text fields
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

      // Elevated button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: textPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radiusDefault)),
          ),
        ),
      ),

      // Text button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radiusSmall)),
          ),
        ),
      ),

      // Outlined button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: const BorderSide(color: accent, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radiusDefault)),
          ),
        ),
      ),

      // Icon button
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textPrimary,
          highlightColor: Colors.white10,
        ),
      ),

      // List tiles
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        textColor: textPrimary,
        iconColor: textSecondary,
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: Color(0xFF1F1F1F),
        thickness: 1,
        space: 1,
      ),

      // Progress indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: surface,
        circularTrackColor: surface,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: accent,
        disabledColor: surface,
        labelStyle: const TextStyle(
          color: textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusSmall)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // Snack bar
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

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? accent : textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? accent.withValues(alpha: 0.3)
              : surface;
        }),
      ),

      // Typography — system font with bold weighting emphasis
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
