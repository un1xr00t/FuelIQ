import 'package:flutter/cupertino.dart';

import '../../data/fuel_records.dart';
import '../../data/fuel_store.dart';
import '../../data/fuel_summary.dart';
import '../../design_system/fuel_page.dart';
import '../../design_system/fuel_theme.dart';
import '../../design_system/record_controls.dart';
import '../garage/vehicle_photo.dart';

class HomePage extends StatefulWidget {
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
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int? _vehicleId;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final data = widget.store.data;
      final vehicle = data.vehicle(_vehicleId);
      final now = DateTime.now();
      final summary = FuelSummary(
        data.fillUps,
        now: now,
        vehicleId: vehicle?.id,
      );
      final months = summary.monthlySpending.keys.toList()..sort();
      final localizations = CupertinoLocalizations.of(context);
      final primary = data.vehicle(data.primaryId);
      return FuelPage(
        title: 'FuelIQ',
        silver: true,
        graphiteHeader: true,
        header: LayoutBuilder(
          builder: (context, constraints) {
            final photo = primary?.photo;
            final profile = CupertinoButton(
              padding: const EdgeInsets.all(8),
              foregroundColor: FuelTheme.resolve(context, FuelTheme.pearlInk),
              onPressed: widget.openGarage,
              child: Column(
                children: [
                  ClipOval(
                    child: photo != null
                        ? VehiclePhoto(photo, size: 112)
                        : const SizedBox.square(
                            dimension: 112,
                            child: Icon(CupertinoIcons.car_detailed, size: 30),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    primary?.name ?? 'Your vehicle',
                    textAlign: TextAlign.center,
                    style: FuelTheme.rowTitle,
                  ),
                  if (primary != null)
                    Text(
                      'Primary vehicle',
                      style: FuelTheme.body.copyWith(
                        color: FuelTheme.resolve(context, FuelTheme.pearlMuted),
                      ),
                    ),
                ],
              ),
            );
            final stats = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Your fuel overview',
                  style: TextStyle(
                    fontSize: 13,
                    color: FuelTheme.resolve(context, FuelTheme.pearlMuted),
                  ),
                ),
                const SizedBox(height: 10),
                _SummaryValue(
                  label: 'All-time spending',
                  value: dollars(summary.spending),
                ),
                const SizedBox(height: 8),
                ColoredBox(
                  color: FuelTheme.resolve(context, FuelTheme.border),
                  child: const SizedBox(height: .7),
                ),
                const SizedBox(height: 8),
                _SummaryValue(
                  label: 'Fill-ups',
                  value: summary.count.toString(),
                ),
                if (summary.count == 0)
                  Text(
                    'No fill-ups recorded yet.',
                    style: TextStyle(
                      fontSize: 13,
                      color: FuelTheme.resolve(context, FuelTheme.pearlMuted),
                    ),
                  ),
              ],
            );
            if (constraints.maxWidth < 260 ||
                MediaQuery.textScalerOf(context).scale(16) > 24) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [profile, stats],
              );
            }
            return IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(child: profile),
                  const SizedBox(width: 10),
                  ColoredBox(
                    color: FuelTheme.resolve(context, FuelTheme.border),
                    child: const SizedBox(width: .7, height: double.infinity),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: stats),
                ],
              ),
            );
          },
        ),
        children: [
          FuelPanel(
            children: [
              const Text('Fuel activity', style: FuelTheme.heading),
              if (data.vehicles.isNotEmpty)
                CupertinoButton(
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.zero,
                  onPressed: () => showCupertinoModalPopup<void>(
                    context: context,
                    builder: (context) => CupertinoActionSheet(
                      title: const Text('Filter fuel activity'),
                      actions: [
                        for (final option in [null, ...data.vehicles])
                          CupertinoActionSheetAction(
                            onPressed: () {
                              setState(() => _vehicleId = option?.id);
                              Navigator.pop(context);
                            },
                            child: Text(option?.name ?? 'All vehicles'),
                          ),
                      ],
                      cancelButton: CupertinoActionSheetAction(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ),
                  child: Text(vehicle?.name ?? 'All vehicles'),
                ),
              const SizedBox(height: 16),
              Text(
                '${fixed(summary.volume, 3)} gallons logged',
                style: FuelTheme.rowTitle,
              ),
              const SizedBox(height: 8),
              Text(
                summary.count == 0
                    ? 'Your latest fill-up will appear here.'
                    : 'Latest fill-up · ${dollars(summary.latest!.total)}',
                style: FuelTheme.body,
              ),
              const SizedBox(height: 12),
              Text('Year-to-date spending · ${dollars(summary.yearSpending)}'),
              if (summary.averagePrice case final price?)
                Text('Average paid · ${dollars(price)}/gal'),
              if (months.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Monthly spending · ${now.year}',
                  style: FuelTheme.rowTitle,
                ),
                for (final month in months)
                  Text(
                    '${localizations.datePickerMonth(month)} · '
                    '${dollars(summary.monthlySpending[month]!)}',
                  ),
              ],
            ],
          ),
          const SizedBox(height: FuelTheme.gap),

          FuelSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RecordRow(
                  title: 'Station research',
                  detail: 'Station and fuel information',
                  icon: CupertinoIcons.location,
                  onPressed: widget.openStations,
                  framed: false,
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: FuelTheme.body.copyWith(
          color: FuelTheme.resolve(context, FuelTheme.pearlMuted),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: FuelTheme.display.copyWith(
          color: FuelTheme.resolve(context, FuelTheme.pearlInk),
        ),
      ),
    ],
  );
}
