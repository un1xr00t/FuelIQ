import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../data/fuel_records.dart';
import '../../data/fuel_store.dart';
import '../../design_system/fuel_page.dart';
import '../../design_system/fuel_theme.dart';
import '../fuel_research/fuel_report.dart';
import '../fuel_research/fuel_report_page.dart';
import 'station_catalog.dart';

class StationDetailPage extends StatefulWidget {
  const StationDetailPage({
    super.key,
    required this.station,
    required this.store,
    required this.catalogDate,
    required this.openDirections,
  });

  final Station station;
  final FuelStore store;
  final DateTime catalogDate;
  final VoidCallback openDirections;

  @override
  State<StationDetailPage> createState() => _StationDetailPageState();
}

typedef _TankRecord = ({
  String facilityId,
  String facilityName,
  int siteId,
  String date,
});

class _StationDetailPageState extends State<StationDetailPage> {
  late final _record = _loadRecord();

  Future<_TankRecord?> _loadRecord() async {
    final asset = await rootBundle.loadString(
      'assets/stations/pa_dep_pilot.json',
    );
    final data = jsonDecode(asset) as Map<String, dynamic>;
    for (final row in (data['matches'] as List).cast<Map<String, dynamic>>()) {
      if (row['stationId'] == widget.station.id) {
        final id = row['facilityId'] as String;
        if (!RegExp(r'^\d{2}-\d{5}$').hasMatch(id)) {
          throw const FormatException('Invalid PA DEP facility ID.');
        }
        return (
          facilityId: id,
          facilityName: row['facilityName'] as String,
          siteId: row['siteId'] as int,
          date: data['retrievedOn'] as String,
        );
      }
    }
    return null;
  }

  Future<void> _openRecord(String facilityId) async {
    const channel = MethodChannel('fueliq/station_location');
    try {
      if (await channel.invokeMethod<bool>('openDepTankRecord', facilityId) ==
          true) {
        return;
      }
    } on PlatformException {
      // Keep the facility ID visible for manual lookup.
    } on MissingPluginException {
      // Opening the source is supported by the iOS app.
    }
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Couldn’t open the PA DEP record'),
        content: Text('Search PA DEP storage tank data for $facilityId.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final station = widget.station;
    final report = FuelReport.forBrand(station.brand);
    final catalogDate = widget.catalogDate
        .toUtc()
        .toIso8601String()
        .split('T')
        .first;
    final ink = FuelTheme.resolve(context, FuelTheme.ink);
    final muted = FuelTheme.resolve(context, FuelTheme.muted);
    final title = FuelTheme.rowTitle.copyWith(color: ink);
    final body = FuelTheme.body.copyWith(color: muted);
    return FuelPage(
      title: 'Station details',
      children: [
        FuelSurface(
          child: Padding(
            padding: const EdgeInsets.all(FuelTheme.inset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(station.name, style: title),
                const SizedBox(height: FuelTheme.compact),
                Text(station.address, style: body),
                const SizedBox(height: FuelTheme.compact),
                Text(
                  'OpenStreetMap contributors · $catalogDate UTC',
                  style: body,
                ),
                const SizedBox(height: FuelTheme.compact),
                Text(
                  station.fuelGrades.isEmpty
                      ? 'Fuel grades · Unavailable'
                      : 'Reported fuels · ${station.fuelGrades.map((grade) => grade.description).join(', ')}',
                  style: body,
                ),
                for (final fuel in station.afdcFuels) ...[
                  const SizedBox(height: FuelTheme.compact),
                  Text(
                    '${fuel.label} · DOE AFDC #${fuel.id} · Confirmed ${fuel.confirmed}',
                    style: body,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: FuelTheme.gap),
        if (report != null)
          CupertinoButton(
            onPressed: () => Navigator.of(context).push(
              CupertinoPageRoute<void>(
                builder: (context) => FuelReportPage(report: report),
              ),
            ),
            child: const Text('Fuel report'),
          ),
        FuelAction(
          label: 'Open in Apple Maps',
          onPressed: widget.openDirections,
        ),
        const SizedBox(height: FuelTheme.gap),
        ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final entries =
                widget.store.data.fillUps
                    .where((entry) => entry.stationId == station.id)
                    .toList()
                  ..sort((a, b) {
                    final date = b.date.compareTo(a.date);
                    return date == 0 ? b.id.compareTo(a.id) : date;
                  });
            if (entries.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: FuelTheme.gap),
              child: FuelSurface(
                child: Padding(
                  padding: const EdgeInsets.all(FuelTheme.inset),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your fill-ups here', style: title),
                      const SizedBox(height: FuelTheme.compact),
                      Text(
                        'Last price paid · \$${fixed(entries.first.price, 3)}/gal',
                        style: body,
                      ),
                      for (final entry in entries.take(5))
                        Padding(
                          padding: const EdgeInsets.only(
                            top: FuelTheme.compact,
                          ),
                          child: Text(
                            '${CupertinoLocalizations.of(context).datePickerMediumDate(entry.date.toLocal())}'
                            ' · ${fixed(entry.volume, 3)} gal · ${dollars(entry.total)}',
                            style: body,
                          ),
                        ),
                      if (entries.length > 5)
                        Text(
                          'Showing the 5 most recent of ${entries.length} fill-ups.',
                          style: body,
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        FuelSurface(
          child: Padding(
            padding: const EdgeInsets.all(FuelTheme.inset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tank registration', style: title),
                const SizedBox(height: FuelTheme.compact),
                FutureBuilder<_TankRecord?>(
                  future: _record,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const CupertinoActivityIndicator();
                    }
                    final record = snapshot.data;
                    if (record == null) return Text('Unavailable', style: body);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(record.facilityName, style: body),
                        Text(
                          'Facility ID ${record.facilityId} · Site ID ${record.siteId}',
                          style: body,
                        ),
                        Text('PA DEP · Retrieved ${record.date}', style: body),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => _openRecord(record.facilityId),
                          child: const Text('View PA DEP tank record'),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: FuelTheme.compact),
                Text('Inspection outcomes · Unavailable', style: body),
                Text('Station TOP TIER status · Unavailable', style: body),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
