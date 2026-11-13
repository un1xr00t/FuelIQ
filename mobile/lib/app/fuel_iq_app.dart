import 'package:flutter/cupertino.dart';

import '../data/fuel_store.dart';
import '../design_system/fuel_page.dart';
import '../design_system/record_controls.dart';
import '../features/fill_ups/fuel_log_page.dart';
import '../features/garage/garage_page.dart';
import '../design_system/fuel_theme.dart';
import '../features/home/home_page.dart';
import '../features/settings/settings_page.dart';
import '../features/stations/stations_page.dart';

class FuelIqApp extends StatefulWidget {
  const FuelIqApp({super.key, this.store});

  final FuelStore? store;

  @override
  State<FuelIqApp> createState() => _FuelIqAppState();
}

class _FuelIqAppState extends State<FuelIqApp> {
  late final _store = widget.store ?? FuelStore();
  late Future<void> _load = _store.load();

  @override
  void dispose() {
    if (widget.store == null) _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _store,
    builder: (context, _) => CupertinoApp(
      title: 'FuelIQ',
      debugShowCheckedModeBanner: false,
      theme: FuelTheme.data(
        Appearance.saved(_store.data.appearance).brightness,
      ),
      home: FutureBuilder<void>(
        future: _load,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const CupertinoPageScaffold(
              child: Center(child: CupertinoActivityIndicator()),
            );
          }
          if (snapshot.hasError) {
            return FuelPage(
              title: 'FuelIQ',
              children: [
                const FuelEmptyState(
                  icon: CupertinoIcons.exclamationmark_circle,
                  title: 'Couldn’t open your saved data',
                  message: 'Try loading it again.',
                ),
                CupertinoButton(
                  onPressed: () => setState(() => _load = _store.load()),
                  child: const Text('Retry'),
                ),
              ],
            );
          }
          return _AppShell(store: _store);
        },
      ),
    ),
  );
}

enum _Destination {
  home('Home', CupertinoIcons.house, CupertinoIcons.house_fill),
  stations('Stations', CupertinoIcons.location, CupertinoIcons.location_fill),
  fuelLog('Fuel Log', CupertinoIcons.drop, CupertinoIcons.drop_fill),
  garage('Garage', CupertinoIcons.car_detailed, CupertinoIcons.car_fill),
  settings('Settings', CupertinoIcons.gear_alt, CupertinoIcons.gear_alt_fill);

  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  BottomNavigationBarItem get tab => BottomNavigationBarItem(
    label: label,
    icon: Icon(icon),
    activeIcon: Icon(selectedIcon),
  );
}

class _AppShell extends StatefulWidget {
  const _AppShell({required this.store});

  final FuelStore store;

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  final _tabs = CupertinoTabController();

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _open(_Destination destination) => _tabs.index = destination.index;

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      controller: _tabs,
      tabBar: CupertinoTabBar(
        backgroundColor: FuelTheme.surface,
        activeColor: FuelTheme.accent,
        inactiveColor: FuelTheme.muted,
        border: const Border(
          top: BorderSide(color: FuelTheme.border, width: 0),
        ),
        items: [for (final destination in _Destination.values) destination.tab],
      ),
      tabBuilder: (context, index) => CupertinoTabView(
        builder: (context) => switch (_Destination.values[index]) {
          _Destination.home => HomePage(
            store: widget.store,
            openGarage: () => _open(_Destination.garage),
            openFuelLog: () => _open(_Destination.fuelLog),
            openStations: () => _open(_Destination.stations),
          ),
          _Destination.stations => const StationsPage(),
          _Destination.fuelLog => FuelLogPage(
            store: widget.store,
            openGarage: () => _open(_Destination.garage),
          ),
          _Destination.garage => GaragePage(store: widget.store),
          _Destination.settings => ListenableBuilder(
            listenable: widget.store,
            builder: (context, _) => SettingsPage(
              store: widget.store,
              appearance: Appearance.saved(widget.store.data.appearance),
              hideStationAddresses: widget.store.data.hideStationAddresses,
              onHideStationAddressesChanged: (value) async {
                try {
                  await widget.store.setHideStationAddresses(value);
                } catch (_) {
                  if (context.mounted) {
                    await showRecordError(
                      context,
                      'Could not save privacy setting.',
                    );
                  }
                }
              },
              onAppearanceChanged: (value) async {
                try {
                  await widget.store.setAppearance(value.name);
                } catch (_) {
                  if (context.mounted) {
                    await showRecordError(
                      context,
                      'Could not save appearance. Try again.',
                    );
                  }
                }
              },
            ),
          ),
        },
      ),
    );
  }
}
