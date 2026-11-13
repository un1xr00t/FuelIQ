import 'package:flutter/cupertino.dart';

abstract final class FuelTheme {
  static const canvas = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFE9E9EB),
    darkColor: Color(0xFF101112),
  );
  static const surface = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF131415),
  );
  static const ink = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF18191B),
    darkColor: Color(0xFFF4F4F5),
  );
  static const muted = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF53555A),
    darkColor: Color(0xFFACADB0),
  );
  static const border = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFD1D2D5),
    darkColor: Color(0xFF323437),
  );
  static const accent = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF166B33),
    darkColor: Color(0xFF42D568),
  );
  static const accentSurface = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF1F1F3),
    darkColor: Color(0xFF1C1D1F),
  );

  static const onAccent = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF102516),
  );

  static const pearl = Color(0xFFF5F5F6);
  static const pearlInk = Color(0xFF17181A);
  static const pearlMuted = Color(0xFF505257);
  static const actionStart = Color(0xFF228940);
  static const actionEnd = Color(0xFF1A7936);

  static const compact = 8.0;
  static const gap = 12.0;
  static const inset = 20.0;
  static const sectionGap = 28.0;
  static const radius = 30.0;
  static const contentWidth = 600.0;

  static const body = TextStyle(fontSize: 16, height: 1.35);
  static const rowTitle = TextStyle(fontSize: 17, fontWeight: FontWeight.w500);
  static const heading = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.35,
  );
  static const wordmark = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.8,
    height: 1.1,
  );
  static const display = TextStyle(
    fontSize: 29,
    height: 1.08,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.9,
  );

  static CupertinoThemeData data(Brightness? brightness) => CupertinoThemeData(
    brightness: brightness,
    primaryColor: accent,
    primaryContrastingColor: onAccent,
    scaffoldBackgroundColor: canvas,
    barBackgroundColor: canvas,
    textTheme: CupertinoTextThemeData(
      navLargeTitleTextStyle: display.copyWith(color: ink),
      navTitleTextStyle: rowTitle.copyWith(color: ink),
    ),
  );

  static Color resolve(BuildContext context, Color color) =>
      CupertinoDynamicColor.resolve(color, context);
}
