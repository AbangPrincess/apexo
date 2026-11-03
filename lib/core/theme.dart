import 'package:flutter/material.dart';

/// The six Apexo brand colors. Screens use the roles in [AppColors], never
/// these directly, so each color keeps one meaning across the app.
abstract final class Palette {
  static const apexRed = Color(0xFFE10600);
  static const hyperOrange = Color(0xFFFF6A13);
  static const voltYellow = Color(0xFFD4FF00);
  static const asphaltBlack = Color(0xFF121316);
  static const stealthCharcoal = Color(0xFF2A2D33);
  static const carbonGray = Color(0xFF6B7079);
}

abstract final class AppColors {
  /// Brand: logo, START, selected tab, links.
  static const accent = Palette.apexRed;
  static const accentSoft = Color(0xFFFDECEB);

  /// Ink: text, primary buttons, selected chips.
  static const ink = Palette.asphaltBlack;
  static const text = Palette.asphaltBlack;
  static const textMuted = Palette.carbonGray;

  /// Light surfaces.
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF4F4F5);
  static const hairline = Color(0xFFE4E5E8);

  /// Dark surfaces: hero cards, the recording cockpit, snackbars.
  static const dark = Palette.asphaltBlack;
  static const darkRaised = Palette.stealthCharcoal;
  static const darkLine = Color(0xFF3A3E45);
  static const onDarkMuted = Color(0xFFA6AAB2);

  /// Signals. Volt means live or go, orange caution, red stop or alert,
  /// carbon parked or inactive.
  static const tracking = Palette.voltYellow;
  static const caution = Palette.hyperOrange;
  static const alert = Palette.apexRed;
  static const parked = Palette.carbonGray;

  /// The rider's own data: routes, charts, progress.
  static const data = Palette.hyperOrange;

  /// Readable text or icon color on a solid [color] fill. Volt and orange
  /// are light, so they always carry ink; red and the grays carry white.
  static Color on(Color color) =>
      color.computeLuminance() > 0.3 ? Palette.asphaltBlack : Colors.white;
}

/// 8-pt grid.
abstract final class Space {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 16.0;
  static const l = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

const double kRadius = 16;
const Duration kMotion = Duration(milliseconds: 180);
const List<FontFeature> kTabular = [FontFeature.tabularFigures()];

abstract final class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.accent).copyWith(
      primary: AppColors.accent,
      onPrimary: Colors.white,
      primaryContainer: AppColors.accentSoft,
      onPrimaryContainer: const Color(0xFF8F0400),
      secondary: AppColors.ink,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.surfaceAlt,
      onSecondaryContainer: AppColors.ink,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      onSurfaceVariant: AppColors.textMuted,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.surfaceAlt,
      surfaceContainer: AppColors.surfaceAlt,
      surfaceContainerHigh: AppColors.surfaceAlt,
      surfaceContainerHighest: AppColors.hairline,
      outline: AppColors.hairline,
      outlineVariant: AppColors.hairline,
      inverseSurface: AppColors.darkRaised,
      onInverseSurface: Colors.white,
      error: AppColors.alert,
      surfaceTint: Colors.transparent,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final text = base.textTheme.apply(bodyColor: AppColors.text, displayColor: AppColors.text);
    final rounded12 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        shape: const Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadius),
          side: const BorderSide(color: AppColors.hairline),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.hairline, thickness: 1, space: 1),
      // Primary actions are ink; red stays for the brand and for alerts.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: rounded12,
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.hairline,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: rounded12,
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.hairline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48), shape: rounded12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: 14),
        border: _inputBorder(AppColors.hairline),
        enabledBorder: _inputBorder(AppColors.hairline),
        // Focus is ink so it never looks like an error (red).
        focusedBorder: _inputBorder(AppColors.ink, 1.5),
        errorBorder: _inputBorder(AppColors.alert),
        focusedErrorBorder: _inputBorder(AppColors.alert, 1.5),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.ink,
        side: const BorderSide(color: AppColors.hairline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: text.labelLarge,
        secondaryLabelStyle: text.labelLarge?.copyWith(color: Colors.white),
        showCheckmark: false,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: AppColors.text,
          selectedBackgroundColor: AppColors.ink,
          selectedForegroundColor: Colors.white,
          side: const BorderSide(color: AppColors.hairline),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.accentSoft,
        selectedIconTheme: IconThemeData(color: AppColors.accent),
        unselectedIconTheme: IconThemeData(color: AppColors.textMuted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.darkRaised,
        actionTextColor: Palette.voltYellow,
        shape: rounded12,
        insetPadding: const EdgeInsets.all(Space.m),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textMuted,
        contentPadding: EdgeInsets.symmetric(horizontal: Space.m),
        minVerticalPadding: 12,
      ),
      badgeTheme: const BadgeThemeData(backgroundColor: AppColors.alert),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.accent),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color, width: width),
  );
}
