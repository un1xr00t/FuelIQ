import 'fuel_records.dart';

class FuelTotals {
  int spending = 0;
  int volume = 0;

  void add(FillUp entry) {
    spending += entry.total;
    volume += entry.volume;
  }

  int get centsPerGallon => (spending * 1000 + volume ~/ 2) ~/ volume;
}

class FuelInsights {
  FuelInsights(
    Iterable<FillUp> entries, {
    required DateTime now,
    int? vehicleId,
  }) {
    final vehicles = <int, List<FillUp>>{};
    final comparisons = <(int, String, int, int), Map<bool, FuelTotals>>{};
    for (final entry in entries) {
      if ((vehicleId != null && entry.vehicleId != vehicleId) ||
          entry.date.isAfter(now) ||
          entry.total <= 0 ||
          entry.volume <= 0) {
        continue;
      }
      vehicles.putIfAbsent(entry.vehicleId, () => []).add(entry);
      final octane = entry.octane;
      final brand = entry.stationBrand?.trim();
      final brandKey = brand?.toLowerCase() ?? '';
      final brandLabel = brand == null || brand.isEmpty
          ? 'Brand unavailable'
          : _brandLabels.putIfAbsent(brandKey, () => brand);
      byBrand.putIfAbsent(brandLabel, FuelTotals.new).add(entry);
      byOctane.putIfAbsent(octane, FuelTotals.new).add(entry);

      final stationId = entry.stationId;
      if (stationId != null &&
          octane != null &&
          (octane == 87 || octane >= 91 && octane <= 94)) {
        final date = entry.date.toLocal();
        comparisons
            .putIfAbsent((
              entry.vehicleId,
              stationId,
              date.year,
              date.month,
            ), () => {})
            .putIfAbsent(octane >= 91, FuelTotals.new)
            .add(entry);
      }
    }
    for (final comparison in comparisons.values) {
      final regular = comparison[false];
      final premium = comparison[true];
      if (regular == null || premium == null) continue;
      final regularAtPremiumVolume =
          (regular.spending * premium.volume + regular.volume ~/ 2) ~/
          regular.volume;
      premiumDifference += premium.spending - regularAtPremiumVolume;
      comparedPremiumVolume += premium.volume;
    }
    for (final entries in vehicles.values) {
      _addFullTankIntervals(entries);
    }
  }

  final byOctane = <int?, FuelTotals>{};
  final byBrand = <String, FuelTotals>{};
  final _brandLabels = <String, String>{};
  int premiumDifference = 0;
  int comparedPremiumVolume = 0;
  int _miles = 0;
  int _volume = 0;
  int _spending = 0;

  int? get premiumGap => comparedPremiumVolume == 0
      ? null
      : (premiumDifference * 1000 / comparedPremiumVolume).round();
  double? get mpg => _miles == 0 ? null : _miles * 1000 / _volume;
  int? get centsPerMile =>
      _miles == 0 ? null : (_spending + _miles ~/ 2) ~/ _miles;

  void _addFullTankIntervals(List<FillUp> entries) {
    entries.sort((a, b) {
      final date = a.date.compareTo(b.date);
      return date == 0 ? a.id.compareTo(b.id) : date;
    });
    int? start;
    int? lastOdometer;
    var volume = 0;
    var spending = 0;
    for (final entry in entries) {
      final odometer = entry.odometer;
      if (odometer != null && lastOdometer != null && odometer < lastOdometer) {
        start = null;
      }
      if (odometer != null) lastOdometer = odometer;
      volume += entry.volume;
      spending += entry.total;
      if (!entry.full) continue;
      if (start != null && odometer != null && odometer > start) {
        _miles += odometer - start;
        _volume += volume;
        _spending += spending;
      }
      start = odometer;
      volume = 0;
      spending = 0;
    }
  }
}
