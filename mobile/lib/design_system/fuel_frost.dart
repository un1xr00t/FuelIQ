import 'dart:ui';

import 'package:flutter/cupertino.dart';

import 'fuel_theme.dart';

/// Shared material scope for FuelIQ pages and their cards.
class FuelFrost extends InheritedWidget {
  const FuelFrost({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FuelFrost>() != null;

  @override
  bool updateShouldNotify(FuelFrost oldWidget) => false;
}

class FuelFrostBackground extends StatelessWidget {
  const FuelFrostBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: dark ? const Color(0xFF101C21) : const Color(0xFFE7EDEE),
        ),
        for (final haze in [
          (const Alignment(-1.2, -.95), const Color(0xFF9CA77F), .43),
          (const Alignment(1.1, -.85), const Color(0xFF9890CA), .38),
          (const Alignment(1.2, .75), const Color(0xFF63B0CB), .32),
        ])
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: haze.$1,
                radius: 1.15,
                colors: [
                  haze.$2.withValues(alpha: dark ? haze.$3 : haze.$3 * .65),
                  haze.$2.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        child,
      ],
    );
  }
}

class FuelFrostSurface extends StatelessWidget {
  const FuelFrostSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(FuelTheme.radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FuelTheme.radius),
            border: Border.all(
              color: const Color(
                0xFFFFFFFF,
              ).withValues(alpha: dark ? .09 : .55),
              width: .7,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? [const Color(0xB32E3A3E), const Color(0x99202C32)]
                  : [const Color(0xCCFFFFFF), const Color(0x99FFFFFF)],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
