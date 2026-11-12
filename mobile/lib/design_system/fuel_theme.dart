import 'package:flutter/cupertino.dart';

abstract final class FuelTheme {
  static const canvas = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF1F5FC),
    darkColor: Color(0xFF000000),
  );
  static const surface = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF141416),
  );
  static const ink = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF14213A),
    darkColor: Color(0xFFF5F5F7),
  );
  static const muted = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF445571),
    darkColor: Color(0xFFAEAEB6),
  );
  static const border = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFD7E0EF),
    darkColor: Color(0xFF303035),
  );
  static const accent = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF1850AF),
    darkColor: Color(0xFF8BB9FF),
  );
  static const accentSurface = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFE3EEFF),
    darkColor: Color(0xFF152641),
  );

  static const onAccent = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF071223),
  );

  static const compact = 8.0;
  static const gap = 12.0;
  static const inset = 20.0;
  static const sectionGap = 28.0;
  static const radius = 20.0;
  static const contentWidth = 600.0;

  static const body = TextStyle(fontSize: 16, height: 1.35);
  static const rowTitle = TextStyle(fontSize: 17, fontWeight: FontWeight.w600);
  static const heading = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.35,
  );
  static const display = TextStyle(
    fontSize: 31,
    height: 1.08,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.9,
  );

  static CupertinoThemeData data(Brightness? brightness) => CupertinoThemeData(
    brightness: brightness,
    primaryColor: accent,
    primaryContrastingColor: onAccent,
    scaffoldBackgroundColor: canvas,
    barBackgroundColor: canvas,
  );

  static Color resolve(BuildContext context, Color color) =>
      CupertinoDynamicColor.resolve(color, context);
}
