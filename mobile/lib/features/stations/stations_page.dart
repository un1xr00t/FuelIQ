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

  Future<void> _openAppleMaps(Station station) async {
    try {
      if (await _channel.invokeMethod<bool>('openStationInMaps', {
            'name': station.name,
            'address': station.address,
            'latitude': station.latitude,
            'longitude': station.longitude,
          }) ==
          true) {
        return;
      }
    } on PlatformException {
      // Show the destination if Maps could not open.
    } on MissingPluginException {
      // Apple Maps is available through the iOS app.
    }
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Couldn’t open Apple Maps'),
        content: Text(
          station.address.isEmpty
              ? '${station.latitude}, ${station.longitude}'
              : station.address,
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

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
                  'This listing has no certification data. Check the exact location in the official Station Finder.',
                ),
                const SizedBox(height: FuelTheme.compact),
                FuelAction(
                  label: 'Open official Station Finder',
                  onPressed: _openTopTierFinder,
                ),
                const SizedBox(height: FuelTheme.compact),
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
    style: _supportingStyle(context),
  );

  TextStyle _supportingStyle(BuildContext context) => FuelTheme.body.copyWith(
    color: FuelTheme.resolve(context, FuelTheme.muted),
    fontSize: 13,
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: FuelPage(
      title: 'Stations',
      children: [
        FuelSurface(
          glow: true,
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            onPressed: _openTopTierFinder,
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Image.asset(
                    'assets/stations/logos/top-tier.png',
                    width: 48,
                    height: 48,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stack) =>
                        const FuelIconTile(CupertinoIcons.location),
                  ),
                ),
                const SizedBox(width: FuelTheme.compact),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOP TIER™',
                        style: FuelTheme.rowTitle.copyWith(
                          color: FuelTheme.resolve(context, FuelTheme.ink),
                        ),
                      ),
                      Text(
                        'Open official Station Finder',
                        style: _supportingStyle(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: FuelTheme.compact),
                const ExcludeSemantics(
                  child: Icon(CupertinoIcons.arrow_up_right, size: 17),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: FuelTheme.gap),
        FuelPanel(
          children: [
            const Text('Pennsylvania pilot', style: FuelTheme.rowTitle),
            const SizedBox(height: FuelTheme.compact),
            CupertinoSearchTextField(
              placeholder: 'Name, brand, address or ZIP',
              onChanged: (value) => setState(() {
                _query = value;
                if (value.trim().isNotEmpty) _catalog ??= StationCatalog.load();
              }),
            ),
            const SizedBox(height: FuelTheme.compact),
            FuelAction(
              label: _locating
                  ? 'Finding your location…'
                  : _location == null
                  ? 'Use my location'
                  : 'Search all Pennsylvania',
              onPressed: _locating
                  ? null
                  : _location == null
                  ? _nearby
                  : () => setState(() => _location = null),
            ),
            if (_locationMessage case final message?) ...[
              const SizedBox(height: FuelTheme.compact),
              Text(message, style: _supportingStyle(context)),
            ],
            if (_location case final location?) ...[
              const SizedBox(height: FuelTheme.compact),
              Text(
                location.accuracy > 500
                    ? 'Approximate location · within 25 mi'
                    : 'Within 25 mi · straight-line distance',
                style: _supportingStyle(context),
              ),
            ],
          ],
        ),
        if (_catalog != null) ...[
          const SizedBox(height: FuelTheme.gap),
          FutureBuilder<StationCatalog>(
            future: _catalog,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Column(
                  children: [
                    Text(
                      'Station data unavailable',
                      style: _supportingStyle(context),
                    ),
                    const SizedBox(height: FuelTheme.compact),
                    FuelAction(
                      label: 'Retry',
                      onPressed: () =>
                          setState(() => _catalog = StationCatalog.load()),
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
                      style: _supportingStyle(context),
                    ),
                  const SizedBox(height: 8),
                  for (final result in results)
                    Padding(
                      padding: const EdgeInsets.only(bottom: FuelTheme.compact),
                      child: StationCard(
                        station: result.station,
                        miles: result.miles,
                        onPressed: () => _openAppleMaps(result.station),
                        onCheckStatus: () =>
                            _detail(result.station, catalog.asOf),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    ),
  );
}
