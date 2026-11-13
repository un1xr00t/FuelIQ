import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

typedef StationLocation = ({
  double latitude,
  double longitude,
  double accuracy,
});

class Station {
  const Station(
    this.id,
    this.name,
    this.brand,
    this.address,
    this.latitude,
    this.longitude,
  );

  final String id;
  final String name;
  final String brand;
  final String address;
  final double latitude;
  final double longitude;

  bool get isNamed => !const {
    'fuel station',
    'gas station',
  }.contains(name.trim().toLowerCase());

  bool get hasStreetAddress =>
      RegExp(r'^\d+\S*\s+[^,\d]').hasMatch(address.trim());

  double milesFrom(StationLocation location) {
    const radians = math.pi / 180;
    final lat = location.latitude * radians;
    final stationLat = latitude * radians;
    final latSin = math.sin((stationLat - lat) / 2);
    final lonSin = math.sin((longitude - location.longitude) * radians / 2);
    final a =
        latSin * latSin +
        math.cos(lat) * math.cos(stationLat) * lonSin * lonSin;
    return 3958.76 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
  }
}

class StationCatalog {
  const StationCatalog._(this.asOf, this.stations, this._approvedBrandKeys);

  final DateTime asOf;
  final List<Station> stations;
  final Set<String> _approvedBrandKeys;

  static Future<StationCatalog> load() async {
    final assets = await Future.wait([
      rootBundle.loadString('assets/stations/pennsylvania.json'),
      rootBundle.loadString('assets/stations/toptier_gasoline_brands.json'),
    ]);
    return parse(assets[0], assets[1]);
  }

  static String _brandKey(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  static StationCatalog parse(String json, String brandsJson) {
    final brandData = jsonDecode(brandsJson) as Map<String, dynamic>;
    final brands = brandData['brands'] as List;
    final approvedBrandKeys = {
      for (final brand in brands.cast<Map<String, dynamic>>())
        for (final key in (brand['match_keys'] as List).cast<String>())
          _brandKey(key),
    };
    if (approvedBrandKeys.isEmpty || approvedBrandKeys.contains('')) {
      throw const FormatException('Invalid TOP TIER gasoline brand list.');
    }

    final data = jsonDecode(json) as Map<String, dynamic>;
    final rows = data['stations'] as List;
    if (data['version'] != 1 || rows.isEmpty) {
      throw const FormatException('Unsupported or empty station catalog.');
    }
    final ids = <String>{};
    final stations = <Station>[];
    for (final row in rows.cast<Map<String, dynamic>>()) {
      final id = row['id'] as String;
      final name = row['name'] as String;
      final lat = (row['latitude'] as num).toDouble();
      final lon = (row['longitude'] as num).toDouble();
      if (!RegExp(r'^(node|way|relation)/[1-9][0-9]*$').hasMatch(id) ||
          !ids.add(id) ||
          name.trim().isEmpty ||
          !lat.isFinite ||
          lat.abs() > 90 ||
          !lon.isFinite ||
          lon.abs() > 180) {
        throw const FormatException('Invalid station record.');
      }
      stations.add(
        Station(
          id,
          name,
          row['brand'] as String,
          row['address'] as String,
          lat,
          lon,
        ),
      );
    }
    return StationCatalog._(
      DateTime.parse(data['asOf'] as String),
      List.unmodifiable(stations),
      Set.unmodifiable(approvedBrandKeys),
    );
  }

  List<({Station station, double? miles})> search(
    String query, {
    StationLocation? location,
  }) {
    final terms = query.toLowerCase().trim().split(RegExp(r'\s+'));
    final results = <({Station station, double? miles})>[];
    for (final station in stations) {
      if (!station.isNamed ||
          !_approvedBrandKeys.contains(_brandKey(station.brand))) {
        continue;
      }
      final text = '${station.name} ${station.brand} ${station.address}'
          .toLowerCase();
      if (!terms.every(text.contains)) continue;
      final miles = location == null ? null : station.milesFrom(location);
      results.add((station: station, miles: miles));
    }
    results.sort((a, b) {
      if (a.miles != null) {
        final comparison = a.miles!.compareTo(b.miles!);
        if (comparison != 0) return comparison;
      }
      final name = a.station.name.compareTo(b.station.name);
      return name == 0 ? a.station.id.compareTo(b.station.id) : name;
    });
    return results;
  }
}
