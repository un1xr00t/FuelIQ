import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fueliq/data/fuel_records.dart';
import 'package:fueliq/data/fuel_store.dart';

void main() {
  test('fixed-point pricing rounds to cents and preserves entered amounts', () {
    expect(parseFixed('10,123', 3, maximum: 999999), 10123);
    expect(parseFixed('3.999', 2, maximum: 999999), isNull);
    expect(parseFixed('-1.00', 2, maximum: 999999), isNull);
    final entry = FillUp(
      id: 1,
      vehicleId: 1,
      date: DateTime.utc(2026),
      volume: 10123,
      price: 3999,
      total: 4088,
      full: false,
    );
    expect(entry.expectedTotal, 4048);
    expect(entry.hasDiscrepancy, isTrue);
    expect(dollars(entry.total), r'$40.88');
  });

  test('vehicles, photos, appearance and fill-ups survive reopening', () async {
    final dir = await Directory.systemTemp.createTemp('fueliq-test');
    addTearDown(() => dir.delete(recursive: true));
    Future<File> file() async => File('${dir.path}/fuel.json');
    final store = FuelStore(file: file);
    await store.load();
    await store.saveVehicle(
      year: 2024,
      make: 'Honda',
      model: 'Civic',
      trim: 'Sport',
      photo: 'aW1hZ2U=',
      primary: false,
    );
    final first = store.data.primaryId!;
    await store.saveVehicle(
      year: 2022,
      make: 'Ford',
      model: 'Bronco',
      trim: '',
      photo: null,
      primary: true,
    );
    final second = store.data.primaryId!;
    await store.setAppearance('light');
    expect(store.data.hideStationAddresses, isTrue);
    await store.setHideStationAddresses(false);
    await store.saveFillUp(
      vehicleId: first,
      date: DateTime.utc(2026, 9, 10),
      volume: 10000,
      price: 3999,
      total: 3999,
      full: false,
      odometer: 20120,
      octane: 93,
      station: ' Shell on Main Street ',
    );
    store.dispose();

    final reopened = FuelStore(file: file);
    await reopened.load();
    expect(reopened.data.primaryId, second);
    expect(reopened.data.vehicle(first)?.photo, 'aW1hZ2U=');
    expect(reopened.data.appearance, 'light');
    expect(reopened.data.hideStationAddresses, isFalse);
    expect(reopened.data.spending, 3999);
    expect(reopened.data.fillUps.single.full, isFalse);
    expect(reopened.data.fillUps.single.octane, 93);
    expect(reopened.data.fillUps.single.station, 'Shell on Main Street');

    final backup = File('${dir.path}/backup.json');
    await reopened.writeBackup(backup);
    Future<File> freshFile() async => File('${dir.path}/reinstalled.json');
    final fresh = FuelStore(file: freshFile);
    addTearDown(fresh.dispose);
    await fresh.load();
    final restored = await fresh.readBackup(backup);
    await fresh.restoreBackup(restored, current: fresh.data);
    await fresh.load();
    expect(fresh.data.toJson(), reopened.data.toJson());

    final beforeChange = fresh.data;
    await fresh.setAppearance('dark');
    expect(
      () => fresh.restoreBackup(restored, current: beforeChange),
      throwsStateError,
    );
    final invalid = await backup.writeAsString('{"version":2}');
    await expectLater(fresh.readBackup(invalid), throwsFormatException);
    expect(fresh.data.fillUps.single.station, 'Shell on Main Street');
    expect(fresh.data.appearance, 'dark');

    await expectLater(reopened.deleteVehicle(first), throwsStateError);
    final entry = reopened.data.fillUps.single;
    await reopened.saveFillUp(
      id: entry.id,
      vehicleId: first,
      date: entry.date,
      volume: 11000,
      price: 3999,
      total: 4399,
      full: true,
    );
    expect(reopened.data.spending, 4399);
    await reopened.deleteFillUp(entry.id);
    await reopened.deleteVehicle(second);
    expect(reopened.data.primaryId, first);
    await reopened.deleteVehicle(first);
    expect(reopened.data.primaryId, isNull);
    reopened.dispose();
  });
}
