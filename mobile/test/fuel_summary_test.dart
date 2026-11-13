import 'package:flutter_test/flutter_test.dart';
import 'package:fueliq/data/fuel_records.dart';
import 'package:fueliq/data/fuel_summary.dart';

void main() {
  test('summary scopes by vehicle and buckets dates in local time', () {
    final now = DateTime(2026, 2, 15);
    FillUp fill(int id, int vehicle, DateTime date, int volume, int total) =>
        FillUp(
          id: id,
          vehicleId: vehicle,
          date: date.toUtc(),
          volume: volume,
          price: 3500,
          total: total,
          full: false,
        );
    final records = [
      fill(1, 10, DateTime(2025, 12, 31, 23, 59), 10000, 3000),
      fill(2, 10, DateTime(2026, 1, 1), 20000, 8000),
      fill(3, 20, DateTime(2026, 2, 1), 5000, 2000),
      fill(4, 20, DateTime(2026, 3, 1), 10000, 4500),
      fill(5, 20, DateTime(2026, 2, 2), 0, 500),
    ];
    final combined = FuelSummary(records, now: now);
    expect(combined.spending, 13000);
    expect(combined.yearSpending, 10000);
    expect(combined.monthlySpending, {1: 8000, 2: 2000});
    expect(combined.volume, 35000);
    expect(combined.count, 3);
    expect(combined.averagePrice, 371);
    expect(combined.latest?.id, 3);

    final vehicle = FuelSummary(records, now: now, vehicleId: 10);
    expect(vehicle.spending, 11000);
    expect(vehicle.averagePrice, 367);
    expect(vehicle.monthlySpending, {1: 8000});
    expect(FuelSummary(records, now: now, vehicleId: 30).averagePrice, isNull);
  });
}
