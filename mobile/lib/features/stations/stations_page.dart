import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../design_system/fuel_page.dart';
import '../../design_system/fuel_theme.dart';
import 'station_card.dart';
import 'station_catalog.dart';

class StationsPage extends StatefulWidget {
  const StationsPage({super.key});

  @override
  State<StationsPage> createState() => _StationsPageState();
}

class _StationsPageState extends State<StationsPage> {
  static const _channel = MethodChannel('fueliq/station_location');
  Future<StationCatalog>? _catalog;
  StationLocation? _location;
  String _query = '';
  String? _locationMessage;
  bool _locating = false;

  Future<void> _openTopTierFinder() async {
    try {
      if (await _channel.invokeMethod<bool>('openTopTierFinder') == true) {
        return;
      }
    } on PlatformException {
      // Offer the address if iOS cannot open the browser.
    } on MissingPluginException {
      // The native link is only available on iOS.
    }
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Open TOP TIER™ in your browser'),
        content: const Text('stationfinder.toptiergas.com'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _nearby() async {
    setState(() {
      _locating = true;
      _locationMessage = null;
    });
    try {
      final fix = await _channel.invokeMapMethod<String, double>(
        'currentLocation',
      );
      if (!mounted || fix == null) return;
      setState(() {
        _location = (
          latitude: fix['latitude']!,
          longitude: fix['longitude']!,
          accuracy: fix['accuracy']!,
        );
        _catalog ??= StationCatalog.load();
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _location = null;
        _locationMessage = switch (error.code) {
          'denied' =>
            'Location access is off. Enable it in iOS Settings or search by text.',
          'restricted' => 'Location access is restricted. Search by text.',
          _ => 'Couldn’t get your location. Try again or search by text.',
        };
      });
    } on MissingPluginException {
      if (mounted) {
        setState(
          () => _locationMessage = 'Location is unavailable. Search by text.',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _detail(Station station, DateTime asOf) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => FuelPage(
          title: station.name,
          children: [
            FuelPanel(
              children: [
                if (station.brand.isNotEmpty) Text(station.brand),
                Text(
                  station.address.isEmpty
                      ? 'Address unavailable'
                      : station.address,
                ),
                const SizedBox(height: 12),
                const Text(
                  'TOP TIER™ status unavailable. Look up this address in the official Station Finder.',
                ),
                CupertinoButton(
                  onPressed: _openTopTierFinder,
                  child: const Text('Open official Station Finder'),
                ),
                const Text('Fuel grades and prices unavailable.'),
                const SizedBox(height: 12),
                _attribution(asOf),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _attribution(DateTime asOf) => Text(
    '© OpenStreetMap contributors · ODbL 1.0\n'
    'openstreetmap.org/copyright\n'
    'Geofabrik extract · ${asOf.toUtc().toIso8601String().split('T').first} UTC',
    style: FuelTheme.body,
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: FuelPage(
      title: 'Stations',
      children: [
        FuelPanel(
          glow: true,
          children: [
            Text('TOP TIER™ Station Finder', style: FuelTheme.rowTitle),
            const SizedBox(height: FuelTheme.compact),
            const Text(
              'Check a specific address for TOP TIER™ Approved Gasoline.',
            ),
            const SizedBox(height: FuelTheme.gap),
            FuelAction(
              label: 'Open official Station Finder',
              onPressed: _openTopTierFinder,
            ),
          ],
        ),
        const SizedBox(height: FuelTheme.gap),
        const Text('Pennsylvania pilot'),
        const Text(
          'Local listings may be out of date. TOP TIER™ status is unavailable.',
        ),
        const SizedBox(height: 8),
        CupertinoSearchTextField(
          placeholder: 'Name, brand, address or ZIP',
          onChanged: (value) => setState(() {
            _query = value;
            if (value.trim().isNotEmpty) _catalog ??= StationCatalog.load();
          }),
        ),
        CupertinoButton(
          onPressed: _locating ? null : _nearby,
          child: _locating
              ? const CupertinoActivityIndicator()
              : const Text('Use my location'),
        ),
        if (_locationMessage case final message?) Text(message),
        if (_location case final location?) ...[
          Text(
            location.accuracy > 500
                ? 'Approximate location · within 25 mi'
                : 'Within 25 mi · straight-line distance',
          ),
          CupertinoButton(
            onPressed: () => setState(() => _location = null),
            child: const Text('Search all Pennsylvania'),
          ),
        ],
        if (_catalog == null)
          const Text('Search Pennsylvania stations by text or location.')
        else
          FutureBuilder<StationCatalog>(
            future: _catalog,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Column(
                  children: [
                    const Text('Station data unavailable'),
                    CupertinoButton(
                      onPressed: () =>
                          setState(() => _catalog = StationCatalog.load()),
                      child: const Text('Retry'),
                    ),
                  ],
                );
              }
              if (!snapshot.hasData) return const CupertinoActivityIndicator();
              final catalog = snapshot.data!;
              final results = _query.trim().isEmpty && _location == null
                  ? <({Station station, double? miles})>[]
                  : catalog.search(_query, location: _location);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (results.isEmpty)
                    Text(
                      _query.trim().isEmpty && _location == null
                          ? 'Enter a search or use your location.'
                          : 'No matching stations in the Pennsylvania catalog.',
                    ),
                  const SizedBox(height: 8),
                  _attribution(catalog.asOf),
                  const SizedBox(height: FuelTheme.compact),
                  for (final result in results)
                    Padding(
                      padding: const EdgeInsets.only(bottom: FuelTheme.compact),
                      child: StationCard(
                        station: result.station,
                        miles: result.miles,
                        onPressed: () => _detail(result.station, catalog.asOf),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    ),
  );
}
