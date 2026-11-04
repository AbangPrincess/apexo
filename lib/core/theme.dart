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

/// The roles that change between the light and dark themes. Brand and
/// signal colors stay the same in both.
class Neutrals {
  const Neutrals({
    required this.ink,
    required this.onInk,
    required this.text,
    required this.textMuted,
    required this.surface,
    required this.surfaceAlt,
    required this.hairline,
    required this.accentSoft,
    required this.dark,
  });

  final Color ink;
  final Color onInk;
  final Color text;
  final Color textMuted;
  final Color surface;
  final Color surfaceAlt;
  final Color hairline;
  final Color accentSoft;
  final Color dark;

  static const day = Neutrals(
    ink: Palette.asphaltBlack,
    onInk: Color(0xFFFFFFFF),
    text: Palette.asphaltBlack,
    textMuted: Palette.carbonGray,
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF4F4F5),
    hairline: Color(0xFFE4E5E8),
    accentSoft: Color(0xFFFDECEB),
    dark: Palette.asphaltBlack,
  );

  /// Asphalt surfaces; ink turns light so primary buttons stay the
  /// strongest thing on screen. Muted text keeps at least 7:1 contrast.
  static const night = Neutrals(
    ink: Color(0xFFF4F4F5),
    onInk: Palette.asphaltBlack,
    text: Color(0xFFF4F4F5),
    textMuted: Color(0xFFA6AAB2),
    surface: Palette.asphaltBlack,
    surfaceAlt: Color(0xFF1D1F23),
    hairline: Color(0xFF34373D),
    accentSoft: Color(0xFF3A1514),
    dark: Color(0xFF1D1F23),
  );
}

abstract final class AppColors {
  static Neutrals _n = Neutrals.day;

  static Brightness get brightness =>
      identical(_n, Neutrals.night) ? Brightness.dark : Brightness.light;

  /// Switches the neutral roles; the app calls this when the theme changes.
  static void use(Brightness b) => _n = b == Brightness.dark ? Neutrals.night : Neutrals.day;

  /// Brand: logo, START, selected tab, links.
  static const accent = Palette.apexRed;
  static Color get accentSoft => _n.accentSoft;

  /// Ink: text, primary buttons, selected chips. [onInk] goes on top of it.
  static Color get ink => _n.ink;
  static Color get onInk => _n.onInk;
  static Color get text => _n.text;
  static Color get textMuted => _n.textMuted;

  static Color get surface => _n.surface;
  static Color get surfaceAlt => _n.surfaceAlt;
  static Color get hairline => _n.hairline;

  /// Dark surfaces: hero cards, the recording cockpit, snackbars.
  static Color get dark => _n.dark;
  static const darkRaised = Palette.stealthCharcoal;
  static const darkLine = Color(0xFF3A3E45);
  static const onDarkMuted = Color(0xFFA6AAB2);

  /// Dots and outlines drawn on map tiles, which are light in both themes.
  static const mapInk = Palette.asphaltBlack;

  /// Signals. Volt means live or go, orange caution, red stop or alert,
  /// carbon parked or inactive.
  static const tracking = Palette.voltYellow;
  static const caution = Palette.hyperOrange;
  static const alert = Palette.apexRed;
  static const parked = Palette.carbonGray;

  /// The rider's own data: routes, charts, progress.
  static const data = Palette.hyperOrange;

  /// Readable text or icon color on a solid [color] fill. Volt and orange
  /// are light, so they always carry asphalt; red and the grays carry white.
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
