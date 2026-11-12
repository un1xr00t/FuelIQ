import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fueliq/app/fuel_iq_app.dart';

Finder tab(String label) => find.descendant(
  of: find.byType(CupertinoTabBar),
  matching: find.text(label),
);

Future<void> selectTab(WidgetTester tester, String label) async {
  await tester.tap(tab(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('all five destinations are reachable from the tab bar', (
    tester,
  ) async {
    await tester.pumpWidget(const FuelIqApp());
    expect(find.text('Your fuel overview'), findsOneWidget);

    const destinations = {
      'Stations': 'Station data unavailable',
      'Fuel Log': 'No fill-ups yet',
      'Garage': 'No vehicles yet',
      'Settings': 'Appearance',
      'Home': 'Your fuel overview',
    };

    for (final entry in destinations.entries) {
      await selectTab(tester, entry.key);
      expect(find.text(entry.value), findsOneWidget);
    }
  });

  testWidgets('Home shortcuts select the matching tab', (tester) async {
    await tester.pumpWidget(const FuelIqApp());

    const shortcuts = {
      'Open Fuel Log': 'No fill-ups yet',
      'My Garage': 'No vehicles yet',
      'Station research': 'Station data unavailable',
    };
    for (final entry in shortcuts.entries) {
      final shortcut = find.text(entry.key);
      await tester.ensureVisible(shortcut);
      await tester.tap(shortcut);
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      await selectTab(tester, 'Home');
    }
  });

  testWidgets('appearance follows system and can be overridden', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(const FuelIqApp());
    await selectTab(tester, 'Settings');

    Brightness pageBrightness() =>
        CupertinoTheme.brightnessOf(tester.element(find.text('Appearance')));

    expect(pageBrightness(), Brightness.dark);
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(pageBrightness(), Brightness.light);
    expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(pageBrightness(), Brightness.dark);
    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();
    expect(pageBrightness(), Brightness.dark);
    await selectTab(tester, 'Home');
    final homeContext = tester.element(find.text('Your fuel overview'));
    expect(CupertinoTheme.brightnessOf(homeContext), Brightness.dark);
  });

  testWidgets(
    'small iPhone layout scrolls at large text sizes in both themes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      for (final brightness in Brightness.values) {
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        await tester.pumpWidget(const FuelIqApp());
        await selectTab(tester, 'Home');
        final shortcut = find.text('Station research');
        await tester.scrollUntilVisible(shortcut.hitTestable(), 200);
        await tester.pumpAndSettle();
        await tester.tap(shortcut);
        await tester.pumpAndSettle();
        expect(find.text('Station data unavailable'), findsOneWidget);
        await selectTab(tester, 'Fuel Log');
        await selectTab(tester, 'Garage');
        await selectTab(tester, 'Settings');
        expect(tester.takeException(), isNull);
      }
    },
  );
}
