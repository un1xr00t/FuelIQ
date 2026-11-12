import 'package:flutter/cupertino.dart';

import '../design_system/fuel_page.dart';
import '../design_system/fuel_theme.dart';
import '../features/home/home_page.dart';
import '../features/settings/settings_page.dart';

class FuelIqApp extends StatefulWidget {
  const FuelIqApp({super.key});

  @override
  State<FuelIqApp> createState() => _FuelIqAppState();
}

class _FuelIqAppState extends State<FuelIqApp> {
  final _appearance = ValueNotifier(Appearance.system);

  @override
  void dispose() {
    _appearance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _appearance,
      builder: (context, appearance, child) {
        return CupertinoApp(
          title: 'FuelIQ',
          debugShowCheckedModeBanner: false,
          theme: FuelTheme.data(appearance.brightness),
          home: _AppShell(appearance: _appearance),
        );
      },
    );
  }
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
  const _AppShell({required this.appearance});

  final ValueNotifier<Appearance> appearance;

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
            openGarage: () => _open(_Destination.garage),
            openFuelLog: () => _open(_Destination.fuelLog),
            openStations: () => _open(_Destination.stations),
          ),
          _Destination.stations => const FuelPage(
            title: 'Stations',
            children: [
              FuelEmptyState(
                icon: CupertinoIcons.location,
                title: 'Station data unavailable',
                message: 'Station search needs a verified data source.',
              ),
            ],
          ),
          _Destination.fuelLog => const FuelPage(
            title: 'Fuel Log',
            children: [
              FuelEmptyState(
                icon: CupertinoIcons.drop,
                title: 'No fill-ups yet',
                message:
                    'Manual fill-up logging is coming in a later milestone.',
              ),
            ],
          ),
          _Destination.garage => const FuelPage(
            title: 'My Garage',
            children: [
              FuelEmptyState(
                icon: CupertinoIcons.car_detailed,
                title: 'No vehicles yet',
                message: 'Vehicle profiles are coming in the next milestone.',
              ),
            ],
          ),
          _Destination.settings => ValueListenableBuilder(
            valueListenable: widget.appearance,
            builder: (context, appearance, child) => SettingsPage(
              appearance: appearance,
              onAppearanceChanged: (value) => widget.appearance.value = value,
            ),
          ),
        },
      ),
    );
  }
}
