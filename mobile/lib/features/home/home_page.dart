import 'package:flutter/cupertino.dart';

import '../../data/fuel_insights.dart';
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
          _FuelActivity(
            summary: summary,
            year: now.year,
            vehicleName: vehicle?.name ?? 'All vehicles',
            selectVehicle: data.vehicles.isEmpty
                ? null
                : () => showCupertinoModalPopup<void>(
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
          ),
          const SizedBox(height: FuelTheme.gap),
          if (summary.count > 0) ...[
            _FuelBreakdown(
              insights: FuelInsights(
                data.fillUps,
                now: now,
                vehicleId: vehicle?.id,
              ),
            ),
            const SizedBox(height: FuelTheme.gap),
          ],
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

class _FuelActivity extends StatelessWidget {
  const _FuelActivity({
    required this.summary,
    required this.year,
    required this.vehicleName,
    required this.selectVehicle,
  });

  final FuelSummary summary;
  final int year;
  final String vehicleName;
  final VoidCallback? selectVehicle;

  static const _figures = [FontFeature.tabularFigures()];

  @override
  Widget build(BuildContext context) {
    final ink = FuelTheme.resolve(context, FuelTheme.ink);
    final muted = FuelTheme.resolve(context, FuelTheme.muted);
    final accent = FuelTheme.resolve(context, FuelTheme.accent);
    final border = FuelTheme.resolve(context, FuelTheme.border);
    final surface = FuelTheme.resolve(context, FuelTheme.surface);
    final inset = FuelTheme.resolve(context, FuelTheme.accentSurface);
    final caption = TextStyle(fontSize: 13, color: muted);
    final amount = FuelTheme.rowTitle.copyWith(
      color: ink,
      fontFeatures: _figures,
    );
    final months = summary.monthlySpending.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    final peak = summary.monthlySpending.values.fold<int>(
      0,
      (peak, total) => total > peak ? total : peak,
    );
    final localizations = CupertinoLocalizations.of(context);
    final latest = summary.latest;

    return FuelPanel(
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: FuelTheme.gap,
          children: [
            const Text('Fuel activity', style: FuelTheme.heading),
            if (selectVehicle != null)
              CupertinoButton(
                onPressed: selectVehicle,
                minimumSize: const Size(44, 44),
                padding: EdgeInsets.zero,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: inset,
                    border: Border.all(color: border, width: .7),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            vehicleName,
                            style: TextStyle(fontSize: 13, color: accent),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          CupertinoIcons.chevron_down,
                          size: 10,
                          color: accent,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: FuelTheme.gap),
        if (latest == null)
          Text('Your latest fill-up will appear here.', style: caption)
        else ...[
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: border, width: .7),
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(accent.withValues(alpha: .09), inset),
                  inset,
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Year-to-date spending', style: caption),
                  const SizedBox(height: 4),
                  Text(
                    dollars(summary.yearSpending),
                    style: FuelTheme.display.copyWith(
                      fontSize: 36,
                      color: ink,
                      fontFeatures: _figures,
                    ),
                  ),
                  const SizedBox(height: FuelTheme.gap),
                  ColoredBox(
                    color: border,
                    child: const SizedBox(height: .7, width: double.infinity),
                  ),
                  const SizedBox(height: FuelTheme.gap),
                  Wrap(
                    spacing: 24,
                    runSpacing: FuelTheme.compact,
                    children: [
                      _ActivityMetric(
                        label: 'Gallons logged',
                        value: fixed(summary.volume, 3),
                        caption: caption,
                        amount: amount,
                      ),
                      if (summary.averagePrice case final price?)
                        _ActivityMetric(
                          label: 'Average paid',
                          value: '${dollars(price)}/gal',
                          caption: caption,
                          amount: amount,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (months.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: FuelTheme.compact,
              children: [
                Text('Monthly spending', style: amount),
                Text('$year', style: caption),
              ],
            ),
            for (final month in months) ...[
              const SizedBox(height: FuelTheme.gap),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: FuelTheme.compact,
                children: [
                  Text(
                    localizations.datePickerMonth(month),
                    style: FuelTheme.body.copyWith(color: muted),
                  ),
                  Text(dollars(summary.monthlySpending[month]!), style: amount),
                ],
              ),
              const SizedBox(height: 5),
              ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: ColoredBox(
                    color: inset,
                    child: FractionallySizedBox(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: summary.monthlySpending[month]! / peak,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          gradient: LinearGradient(
                            colors: [accent.withValues(alpha: .55), accent],
                          ),
                        ),
                        child: const SizedBox(height: 4),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: surface,
              border: Border.all(color: border, width: .7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: FuelTheme.gap,
                runSpacing: 4,
                children: [
                  Text('Latest fill-up', style: caption),
                  Text(dollars(latest.total), style: amount),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ActivityMetric extends StatelessWidget {
  const _ActivityMetric({
    required this.label,
    required this.value,
    required this.caption,
    required this.amount,
  });

  final String label;
  final String value;
  final TextStyle caption;
  final TextStyle amount;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: caption),
      const SizedBox(height: 3),
      Text(value, style: amount),
    ],
  );
}

class _FuelBreakdown extends StatefulWidget {
  const _FuelBreakdown({required this.insights});

  final FuelInsights insights;

  @override
  State<_FuelBreakdown> createState() => _FuelBreakdownState();
}

class _FuelBreakdownState extends State<_FuelBreakdown> {
  bool _byBrand = false;

  @override
  Widget build(BuildContext context) {
    final insights = widget.insights;
    final octanes = insights.byOctane.keys.whereType<int>().toList()..sort();
    final brands = insights.byBrand.keys.toList()
      ..sort(
        (a, b) => insights.byBrand[b]!.spending.compareTo(
          insights.byBrand[a]!.spending,
        ),
      );
    final rows = _byBrand
        ? {for (final brand in brands) brand: insights.byBrand[brand]!}
        : {
            for (final octane in octanes)
              '$octane AKI': insights.byOctane[octane]!,
            'Grade unavailable': ?insights.byOctane[null],
          };
    final gap = insights.premiumGap;
    final mpg = insights.mpg;
    final cost = insights.centsPerMile;
    final body = FuelTheme.body.copyWith(
      color: FuelTheme.resolve(context, FuelTheme.muted),
    );
    return FuelSurface(
      child: Padding(
        padding: const EdgeInsets.all(FuelTheme.inset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Fuel breakdown', style: FuelTheme.heading),
            const SizedBox(height: FuelTheme.compact),
            Text('All-time · Spending and average price paid', style: body),
            const SizedBox(height: FuelTheme.compact),
            CupertinoSlidingSegmentedControl<bool>(
              groupValue: _byBrand,
              children: const {false: Text('Grade'), true: Text('Brand')},
              onValueChanged: (value) {
                if (value != null) setState(() => _byBrand = value);
              },
            ),
            for (final row in rows.entries)
              Padding(
                padding: const EdgeInsets.only(top: FuelTheme.gap),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.key, style: FuelTheme.rowTitle),
                    Text(
                      '${dollars(row.value.spending)} spent · ${dollars(row.value.centsPerGallon)}/gal',
                      style: body,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: FuelTheme.gap),
            const Text('Premium price gap', style: FuelTheme.rowTitle),
            if (gap == null)
              Text(
                'Compare 87 AKI and 91–94 AKI fill-ups for the same vehicle, station, and month.',
                style: body,
              )
            else ...[
              Text(
                gap == 0
                    ? 'Same average price per gallon'
                    : '${dollars(gap.abs())}/gal ${gap > 0 ? 'more' : 'less'} for premium',
                style: body,
              ),
              Text(
                'Estimated difference · ${insights.premiumDifference < 0 ? '−' : ''}${dollars(insights.premiumDifference.abs())}'
                ' across ${fixed(insights.comparedPremiumVolume, 3)} comparable premium gallons',
                style: body,
              ),
            ],
            const SizedBox(height: FuelTheme.gap),
            const Text('Fuel economy', style: FuelTheme.rowTitle),
            Text(
              mpg == null || cost == null
                  ? 'Log full tanks with odometer readings to see MPG and fuel cost per mile.'
                  : '${mpg.toStringAsFixed(1)} MPG · ${dollars(cost)}/mi in fuel',
              style: body,
            ),
          ],
        ),
      ),
    );
  }
}
