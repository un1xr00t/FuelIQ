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
  static const _pageSize = 20;
  int _visibleCount = _pageSize;

  bool _onScroll(ScrollNotification event, int resultCount) {
    if (event.depth == 0 &&
        event is ScrollUpdateNotification &&
        (event.scrollDelta ?? 0) > 0 &&
        event.metrics.extentAfter < 240 &&
        _visibleCount < resultCount) {
      setState(() => _visibleCount += _pageSize);
    }
    return false;
  }

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
        _visibleCount = _pageSize;
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
        _visibleCount = _pageSize;
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

  TextStyle _supportingStyle(BuildContext context) => FuelTheme.body.copyWith(
    color: FuelTheme.resolve(context, FuelTheme.muted),
    fontSize: 13,
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<StationCatalog>(
    future: _catalog,
    builder: (context, snapshot) {
      final catalog = snapshot.data;
      final results =
          catalog == null || (_query.trim().isEmpty && _location == null)
          ? <({Station station, double? miles})>[]
          : catalog
                .search(_query, location: _location)
                .where((result) => result.station.hasStreetAddress)
                .toList();
      return NotificationListener<ScrollNotification>(
        onNotification: (event) => _onScroll(event, results.length),
        child: SafeArea(
          top: false,
          bottom: false,
          child: FuelPage(
            title: 'Stations',
            contentSliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 28),
              sliver: SliverList.builder(
                itemCount: results.length < _visibleCount
                    ? results.length
                    : _visibleCount,
                itemBuilder: (context, index) {
                  final result = results[index];
                  return Center(
                    key: ValueKey(result.station.id),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: FuelTheme.contentWidth,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: FuelTheme.compact,
                        ),
                        child: StationCard(
                          station: result.station,
                          miles: result.miles,
                          onPressed: () => _openAppleMaps(result.station),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            children: [
              FuelSurface(
                glow: true,
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
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
                                color: FuelTheme.resolve(
                                  context,
                                  FuelTheme.ink,
                                ),
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
                      _visibleCount = _pageSize;
                      if (value.trim().isNotEmpty) {
                        _catalog ??= StationCatalog.load();
                      }
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
                        : () => setState(() {
                            _location = null;
                            _visibleCount = _pageSize;
                          }),
                  ),
                  if (_locationMessage case final message?) ...[
                    const SizedBox(height: FuelTheme.compact),
                    Text(message, style: _supportingStyle(context)),
                  ],
                  if (_location case final location?) ...[
                    const SizedBox(height: FuelTheme.compact),
                    Text(
                      location.accuracy > 500
                          ? 'Approximate location · nearest first'
                          : 'Nearest first · straight-line distance',
                      style: _supportingStyle(context),
                    ),
                  ],
                ],
              ),
              if (_catalog != null) ...[
                const SizedBox(height: FuelTheme.gap),
                if (snapshot.hasError) ...[
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
                ] else if (!snapshot.hasData)
                  const CupertinoActivityIndicator()
                else ...[
                  if (results.isEmpty)
                    Text(
                      _query.trim().isEmpty && _location == null
                          ? 'Enter a search or use your location.'
                          : 'No matching stations with a street address.',
                      style: _supportingStyle(context),
                    ),
                ],
              ],
            ],
          ),
        ),
      );
    },
  );
}
