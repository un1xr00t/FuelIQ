import 'fuel_records.dart';

class FuelSummary {
  FuelSummary(
    Iterable<FillUp> entries, {
    required DateTime now,
    int? vehicleId,
  }) {
    final localNow = now.toLocal();
    for (final entry in entries) {
      if (vehicleId != null && entry.vehicleId != vehicleId) continue;
      final date = entry.date.toLocal();
      if (date.isAfter(localNow) || entry.total <= 0 || entry.volume <= 0) {
        continue;
      }
      spending += entry.total;
      volume += entry.volume;
      count++;
      if (latest == null || entry.date.isAfter(latest!.date)) latest = entry;
      if (date.year == localNow.year) {
        yearSpending += entry.total;
        monthlySpending.update(
          date.month,
          (total) => total + entry.total,
          ifAbsent: () => entry.total,
        );
      }
    }
  }

  int spending = 0;
  int yearSpending = 0;
  int volume = 0;
  int count = 0;
  FillUp? latest;
  final monthlySpending = <int, int>{};

  // Actual cents paid divided by gallons, rounded to cents per gallon.
  int? get averagePrice =>
      volume == 0 ? null : (spending * 1000 + volume ~/ 2) ~/ volume;
}
