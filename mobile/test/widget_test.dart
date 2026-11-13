import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fueliq/app/fuel_iq_app.dart';
import 'package:fueliq/design_system/fuel_theme.dart';

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
    await tester.pumpAndSettle();
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
    await tester.pumpAndSettle();

    const shortcuts = {'Station research': 'Station data unavailable'};
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
    await tester.pumpAndSettle();
    await selectTab(tester, 'Settings');

    Brightness pageBrightness() =>
        CupertinoTheme.brightnessOf(tester.element(find.text('Appearance')));

    expect(pageBrightness(), Brightness.dark);
    final darkButton = tester.widget<CupertinoButton>(
      find.widgetWithText(CupertinoButton, 'Dark'),
    );
    expect(
      darkButton.foregroundColor?.toARGB32(),
      FuelTheme.ink.darkColor.toARGB32(),
    );
    final check = tester.widget<Icon>(find.byIcon(CupertinoIcons.check_mark));
    expect(check.color?.toARGB32(), FuelTheme.accent.darkColor.toARGB32());
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
    'add a vehicle and log fuel from the tabs',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(const FuelIqApp());
      await tester.pumpAndSettle();

      Future<void> tapText(String text) async {
        await tester.ensureVisible(find.text(text));
        await tester.tap(find.text(text));
        await tester.pumpAndSettle();
      }

      Future<void> enter(List<String> values) async {
        for (var i = 0; i < values.length; i++) {
          await tester.enterText(
            find.byType(CupertinoTextField).at(i),
            values[i],
          );
        }
      }

      await selectTab(tester, 'Garage');
      await tapText('Add vehicle');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const picker = MethodChannel('fueliq/photo_picker');
      var pickerOpens = 0;
      messenger.setMockMethodCallHandler(picker, (call) async {
        expect(call.method, 'pickPhoto');
        pickerOpens++;
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(picker, null));
      await tapText('Choose photo');
      expect(pickerOpens, 1);
      expect(find.byType(CupertinoActionSheet), findsNothing);
      expect(find.text('Choose photo'), findsOneWidget);
      await enter(['2024', 'Honda', 'Civic']);
      await tapText('Save vehicle');
      expect(find.text('2024 Honda Civic'), findsOneWidget);
      await selectTab(tester, 'Fuel Log');
      await tapText('Scan a fill-up');
      expect(pickerOpens, 2);
      expect(find.byType(CupertinoActionSheet), findsNothing);
      expect(find.text('Review fill-up'), findsWidgets);
      await tapText('Save fill-up');
      expect(find.text('Check this entry'), findsOneWidget);
      await tapText('OK');
      final directory = Directory.systemTemp.createTempSync('fueliq-scan-test');
      addTearDown(() => directory.deleteSync(recursive: true));
      final photo = File('${directory.path}/receipt.jpg')
        ..writeAsStringSync('photo');
      const scanner = MethodChannel('fueliq/fuel_photo');
      messenger.setMockMethodCallHandler(picker, (call) async {
        expect(call.method, 'pickPhoto');
        return photo.path;
      });
      messenger.setMockMethodCallHandler(scanner, (call) async {
        expect(call.method, 'recognize');
        expect(call.arguments, photo.path);
        return [
          for (final text in ['Gallons 9.95', r'Total $60.00', 'Grade 93'])
            {
              'text': text,
              'confidence': 0.98,
              'x': 0.0,
              'y': 0.0,
              'width': 0.0,
              'height': 0.0,
            },
        ];
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(scanner, null);
      });
      await tapText('Scan receipt or pump');
      expect(find.text('9.950'), findsOneWidget);
      expect(find.text('60.00'), findsOneWidget);
      expect(find.text('93'), findsOneWidget);
      await tapText('Calculate price from total and gallons');
      expect(find.text('6.030'), findsOneWidget);
      await enter(['10.000', '40.50', '3.999', '93']);
      await tapText('Save fill-up');
      expect(find.text('Total differs'), findsOneWidget);
      await tapText('Save entered total');
      expect(find.text(r'$40.50'), findsOneWidget);
      expect(find.textContaining('93 AKI'), findsOneWidget);
      await selectTab(tester, 'Home');
      expect(find.text(r'$40.50'), findsOneWidget);

      await selectTab(tester, 'Fuel Log');
      await tapText(r'$40.50');
      await enter(['10.000', '39.99', '3.999']);
      await tapText('Save fill-up');
      await tapText(r'$39.99');
      await tapText('Delete fill-up');
      await tapText('Delete');
      expect(find.text('No fill-ups yet'), findsOneWidget);
      await selectTab(tester, 'Home');
      expect(find.text('No fill-ups recorded yet.'), findsOneWidget);
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );

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
        await tester.pumpWidget(FuelIqApp(key: ValueKey(brightness)));
        await tester.pumpAndSettle();
        await selectTab(tester, 'Settings');
        await tester.tap(find.text('System'));
        await tester.pumpAndSettle();
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
