import 'package:flutter/cupertino.dart';

import '../../design_system/fuel_page.dart';
import '../../design_system/fuel_theme.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.openGarage,
    required this.openFuelLog,
    required this.openStations,
  });

  final VoidCallback openGarage;
  final VoidCallback openFuelLog;
  final VoidCallback openStations;

  @override
  Widget build(BuildContext context) {
    return FuelPage(
      title: 'FuelIQ',
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FuelTheme.heroRadius),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [FuelTheme.heroTop, FuelTheme.heroBottom],
            ),
            boxShadow: const [FuelTheme.heroShadow],
          ),
          child: Padding(
            padding: const EdgeInsets.all(FuelTheme.sectionGap),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ExcludeSemantics(
                  child: Icon(
                    CupertinoIcons.speedometer,
                    color: FuelTheme.heroAccent,
                    size: 44,
                  ),
                ),
                const SizedBox(height: FuelTheme.inset),
                Semantics(
                  header: true,
                  child: Text(
                    'Your fuel overview',
                    style: FuelTheme.display.copyWith(color: FuelTheme.heroInk),
                  ),
                ),
                const SizedBox(height: FuelTheme.compact),
                Text(
                  'No fill-ups recorded yet.',
                  style: FuelTheme.body.copyWith(color: FuelTheme.heroMuted),
                ),
                const SizedBox(height: FuelTheme.inset),
                CupertinoButton(
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: FuelTheme.inset,
                    vertical: FuelTheme.gap,
                  ),
                  color: FuelTheme.heroAccent,
                  foregroundColor: FuelTheme.heroBottom,
                  borderRadius: BorderRadius.circular(FuelTheme.gap),
                  onPressed: openFuelLog,
                  child: const Text('Open Fuel Log', style: FuelTheme.rowTitle),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: FuelTheme.sectionGap),
        _Destination(
          title: 'My Garage',
          description: 'Vehicle profiles',
          icon: CupertinoIcons.car_detailed,
          onPressed: openGarage,
        ),
        const SizedBox(height: FuelTheme.gap),
        _Destination(
          title: 'Station research',
          description: 'Station and fuel information',
          icon: CupertinoIcons.location,
          onPressed: openStations,
        ),
      ],
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.title,
    required this.description,
    required this.icon,
    required this.onPressed,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FuelSurface(
      child: CupertinoButton(
        padding: const EdgeInsets.all(FuelTheme.gap),
        onPressed: onPressed,
        child: Row(
          children: [
            FuelIconTile(icon),
            const SizedBox(width: FuelTheme.gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: FuelTheme.rowTitle.copyWith(
                      color: FuelTheme.resolve(context, FuelTheme.ink),
                    ),
                  ),
                  Text(
                    description,
                    style: FuelTheme.body.copyWith(
                      color: FuelTheme.resolve(context, FuelTheme.muted),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: FuelTheme.compact),
            ExcludeSemantics(
              child: Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: FuelTheme.resolve(context, FuelTheme.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
