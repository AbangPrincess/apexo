import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

/// Material themes built from the brand roles in [AppColors] and the
/// light and dark [Neutrals].
abstract final class AppTheme {
  static ThemeData light() => _build(Neutrals.day, Brightness.light);
  static ThemeData dark() => _build(Neutrals.night, Brightness.dark);

  static ThemeData _build(Neutrals n, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.accent, brightness: brightness)
        .copyWith(
          primary: AppColors.accent,
          onPrimary: Colors.white,
          primaryContainer: n.accentSoft,
          onPrimaryContainer: brightness == Brightness.dark
              ? const Color(0xFFFFB4A9)
              : const Color(0xFF8F0400),
          secondary: n.ink,
          onSecondary: n.onInk,
          secondaryContainer: n.surfaceAlt,
          onSecondaryContainer: n.ink,
          surface: n.surface,
          onSurface: n.text,
          onSurfaceVariant: n.textMuted,
          surfaceContainerLowest: n.surface,
          surfaceContainerLow: n.surfaceAlt,
          surfaceContainer: n.surfaceAlt,
          surfaceContainerHigh: n.surfaceAlt,
          surfaceContainerHighest: n.hairline,
          outline: n.hairline,
          outlineVariant: n.hairline,
          inverseSurface: AppColors.darkRaised,
          onInverseSurface: Colors.white,
          error: AppColors.alert,
          surfaceTint: Colors.transparent,
        );
    // The iPhone app uses the phone's own font (San Francisco), like most
    // iOS apps. Everywhere else Inter, bundled in assets/fonts: the closest
    // free match, soft and round, with tabular digits. Sizes follow iOS
    // (17 body, 15 subhead, 13 footnote) with iOS-tight letter spacing
    // instead of Material's wide tracking.
    final iosApp = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: iosApp ? null : 'Inter',
    );
    final m = base.textTheme.apply(bodyColor: n.text, displayColor: n.text);
    TextStyle? w(TextStyle? s, FontWeight weight, {double? size, double spacing = 0}) =>
        s?.copyWith(fontWeight: weight, fontSize: size, letterSpacing: spacing);
    final text = m.copyWith(
      displayLarge: w(m.displayLarge, FontWeight.w700, spacing: -1),
      displayMedium: w(m.displayMedium, FontWeight.w700, spacing: -0.8),
      displaySmall: w(m.displaySmall, FontWeight.w700, spacing: -0.6),
      headlineLarge: w(m.headlineLarge, FontWeight.w700, spacing: -0.6),
      headlineMedium: w(m.headlineMedium, FontWeight.w700, spacing: -0.5),
      headlineSmall: w(m.headlineSmall, FontWeight.w700, spacing: -0.4),
      titleLarge: w(m.titleLarge, FontWeight.w700, spacing: -0.3),
      titleMedium: w(m.titleMedium, FontWeight.w600, size: 17, spacing: -0.2),
      titleSmall: w(m.titleSmall, FontWeight.w600, size: 15, spacing: -0.1),
      bodyLarge: w(m.bodyLarge, FontWeight.w400, size: 17, spacing: -0.2),
      bodyMedium: w(m.bodyMedium, FontWeight.w400, size: 15, spacing: -0.1),
      bodySmall: w(m.bodySmall, FontWeight.w400, size: 13),
      labelLarge: w(m.labelLarge, FontWeight.w600, size: 15, spacing: -0.1),
      labelMedium: w(m.labelMedium, FontWeight.w500, size: 13),
      labelSmall: w(m.labelSmall, FontWeight.w500, size: 12),
    );
    final rounded12 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));

    return base.copyWith(
      scaffoldBackgroundColor: n.surface,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: n.surface,
        foregroundColor: n.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        shape: Border(bottom: BorderSide(color: n.hairline)),
      ),
      cardTheme: CardThemeData(
        color: n.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadius),
          side: BorderSide(color: n.hairline),
        ),
      ),
      dividerTheme: DividerThemeData(color: n.hairline, thickness: 1, space: 1),
      // Primary actions are ink; red stays for the brand and for alerts.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: rounded12,
          backgroundColor: n.ink,
          foregroundColor: n.onInk,
          disabledBackgroundColor: n.hairline,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: rounded12,
          foregroundColor: n.text,
          side: BorderSide(color: n.hairline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: rounded12,
          // Red text on asphalt is too dim for small labels; use light ink.
          foregroundColor: brightness == Brightness.dark ? n.ink : null,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: n.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: 14),
        border: _inputBorder(n.hairline),
        enabledBorder: _inputBorder(n.hairline),
        // Focus is ink so it never looks like an error (red).
        focusedBorder: _inputBorder(n.ink, 1.5),
        errorBorder: _inputBorder(AppColors.alert),
        focusedErrorBorder: _inputBorder(AppColors.alert, 1.5),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: n.surface,
        selectedColor: n.ink,
        side: BorderSide(color: n.hairline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: text.labelLarge,
        secondaryLabelStyle: text.labelLarge?.copyWith(color: n.onInk),
        showCheckmark: false,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: n.text,
          selectedBackgroundColor: n.ink,
          selectedForegroundColor: n.onInk,
          side: BorderSide(color: n.hairline),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: n.surface,
        indicatorColor: n.accentSoft,
        selectedIconTheme: const IconThemeData(color: AppColors.accent),
        unselectedIconTheme: IconThemeData(color: n.textMuted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.darkRaised,
        actionTextColor: Palette.voltYellow,
        shape: rounded12,
        insetPadding: const EdgeInsets.all(Space.m),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: n.textMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.m),
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
