import 'package:flutter/cupertino.dart';

import '../../data/fuel_records.dart';
import '../../data/fuel_store.dart';
import '../../design_system/fuel_page.dart';
import '../../design_system/fuel_theme.dart';
import '../../design_system/record_controls.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.store,
    required this.openGarage,
    required this.openFuelLog,
    required this.openStations,
  });

  final FuelStore store;
  final VoidCallback openGarage;
  final VoidCallback openFuelLog;
  final VoidCallback openStations;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final data = store.data;
      final primary = data.vehicle(data.primaryId);
      return FuelPage(
        title: 'FuelIQ',
        children: [
          FuelSurface(
            child: Padding(
              padding: const EdgeInsets.all(FuelTheme.sectionGap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text('Your fuel overview', style: FuelTheme.display),
                  ),
                  const SizedBox(height: FuelTheme.compact),
                  Text(
                    data.fillUps.isEmpty
                        ? 'No fill-ups recorded yet.'
                        : 'All-time spending · ${data.fillUps.length} fill-ups',
                    style: FuelTheme.body.copyWith(
                      color: FuelTheme.resolve(context, FuelTheme.muted),
                    ),
                  ),
                  if (data.fillUps.isNotEmpty) ...[
                    const SizedBox(height: FuelTheme.gap),
                    Text(dollars(data.spending), style: FuelTheme.display),
                  ],
                  const SizedBox(height: FuelTheme.inset),
                  CupertinoButton.filled(
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: FuelTheme.inset,
                      vertical: FuelTheme.gap,
                    ),
                    borderRadius: BorderRadius.circular(FuelTheme.gap),
                    onPressed: openFuelLog,
                    child: const Text(
                      'Open Fuel Log',
                      style: FuelTheme.rowTitle,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: FuelTheme.sectionGap),
          RecordRow(
            title: 'My Garage',
            detail: primary?.name ?? 'Add your first vehicle',
            icon: CupertinoIcons.car_detailed,
            onPressed: openGarage,
          ),
          const SizedBox(height: FuelTheme.gap),
          RecordRow(
            title: 'Station research',
            detail: 'Station and fuel information',
            icon: CupertinoIcons.location,
            onPressed: openStations,
          ),
        ],
      );
    },
  );
}
