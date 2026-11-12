import 'package:flutter/cupertino.dart';

abstract final class FuelTheme {
  static const canvas = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF4F3EF),
    darkColor: Color(0xFF141615),
  );
  static const surface = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF202321),
  );
  static const ink = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF181C19),
    darkColor: Color(0xFFF6F4EE),
  );
  static const muted = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF555D57),
    darkColor: Color(0xFFB1B9B3),
  );
  static const border = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFE1E1DA),
    darkColor: Color(0xFF353B36),
  );
  static const accent = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF9C3818),
    darkColor: Color(0xFFFFAC88),
  );
  static const accentSurface = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFAEAE1),
    darkColor: Color(0xFF402B23),
  );

  static const heroTop = Color(0xFF27342D);
  static const heroBottom = Color(0xFF141A17);
  static const heroInk = Color(0xFFFFF8EE);
  static const heroMuted = Color(0xFFD1DAD3);
  static const heroAccent = Color(0xFFFFAD87);
  static const heroShadow = BoxShadow(
    color: Color(0x220D1912),
    blurRadius: 24,
    offset: Offset(0, 12),
  );

  static const compact = 8.0;
  static const gap = 12.0;
  static const inset = 20.0;
  static const sectionGap = 28.0;
  static const radius = 20.0;
  static const heroRadius = 28.0;
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
    scaffoldBackgroundColor: canvas,
    barBackgroundColor: canvas,
  );

  static Color resolve(BuildContext context, Color color) =>
      CupertinoDynamicColor.resolve(color, context);
}
