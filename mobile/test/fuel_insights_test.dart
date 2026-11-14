import 'package:flutter_test/flutter_test.dart';
import 'package:fueliq/data/fuel_insights.dart';
import 'package:fueliq/data/fuel_records.dart';

FillUp entry(
  int day, {
  int vehicle = 1,
  String? stationId = 'node/1',
  int? octane = 87,
  int volume = 10000,
  int total = 3000,
  int? odometer,
  bool full = true,
}) => FillUp(
  id: day,
  vehicleId: vehicle,
  date: DateTime(2026, 1, day),
  volume: volume,
  price: 3000,
  total: total,
  full: full,
  octane: octane,
  odometer: odometer,
  stationId: stationId,
  stationBrand: stationId == null ? null : 'Shell',
);

void main() {
  test('premium comparison uses same station, vehicle and month', () {
    final insights = FuelInsights(
      [
        entry(1),
        entry(2, octane: 93, volume: 20000, total: 8000),
        entry(3, octane: 93, stationId: 'node/2'),
        entry(4, octane: 93, vehicle: 2),
        entry(32, octane: 93),
        entry(5, stationId: null, octane: null),
      ],
      now: DateTime(2026, 2, 10),
      vehicleId: 1,
    );
    expect(insights.premiumGap, 100);
    expect(insights.premiumDifference, 2000);
    expect(insights.comparedPremiumVolume, 20000);
    expect(insights.byOctane[93]!.centsPerGallon, 350);
    expect(insights.byBrand['Brand unavailable']!.spending, 3000);
  });

  test(
    'fuel economy includes partial tanks inside a full-to-full interval',
    () {
      final insights = FuelInsights([
        entry(1, odometer: 1000),
        entry(2, volume: 5000, total: 1500, full: false),
        entry(3, odometer: 1300),
        entry(4, full: false),
      ], now: DateTime(2026, 2));
      expect(insights.mpg, 20);
      expect(insights.centsPerMile, 15);
    },
  );

  test('station identity round-trips and older entries remain readable', () {
    final json = entry(1).toJson();
    expect(FillUp.fromJson(json).stationId, 'node/1');
    expect(FillUp.fromJson(json).stationBrand, 'Shell');
    json.remove('stationId');
    json.remove('stationBrand');
    expect(FillUp.fromJson(json).stationId, isNull);
  });
}
