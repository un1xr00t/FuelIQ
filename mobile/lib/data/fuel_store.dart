import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'fuel_records.dart';

class FuelData {
  const FuelData({
    this.vehicles = const [],
    this.fillUps = const [],
    this.primaryId,
    this.nextId = 1,
    this.appearance = 'dark',
  });

  final List<Vehicle> vehicles;
  final List<FillUp> fillUps;
  final int? primaryId;
  final int nextId;
  final String appearance;

  int get spending => fillUps.fold(0, (sum, entry) => sum + entry.total);

  Vehicle? vehicle(int? id) => vehicles.where((v) => v.id == id).firstOrNull;

  factory FuelData.fromJson(Map<String, Object?> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported local data version.');
    }
    final vehicles = List<Vehicle>.unmodifiable(
      (json['vehicles'] as List).cast<Map<String, Object?>>().map(
        Vehicle.fromJson,
      ),
    );
    final fillUps = List<FillUp>.unmodifiable(
      (json['fillUps'] as List).cast<Map<String, Object?>>().map(
        FillUp.fromJson,
      ),
    );
    final result = FuelData(
      vehicles: vehicles,
      fillUps: fillUps,
      primaryId: json['primaryId'] as int?,
      nextId: json['nextId'] as int,
      appearance: json['appearance'] as String,
    );
    final ids = [...vehicles.map((v) => v.id), ...fillUps.map((f) => f.id)];
    if (ids.toSet().length != ids.length ||
        ids.any((id) => id <= 0 || id >= result.nextId) ||
        (vehicles.isEmpty
            ? result.primaryId != null
            : result.vehicle(result.primaryId) == null) ||
        fillUps.any((entry) => result.vehicle(entry.vehicleId) == null)) {
      throw const FormatException('Invalid local record links.');
    }
    return result;
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'vehicles': vehicles.map((vehicle) => vehicle.toJson()).toList(),
    'fillUps': fillUps.map((entry) => entry.toJson()).toList(),
    'primaryId': primaryId,
    'nextId': nextId,
    'appearance': appearance,
  };

  FuelData copyWith({
    List<Vehicle>? vehicles,
    List<FillUp>? fillUps,
    int? primaryId,
    bool clearPrimary = false,
    int? nextId,
    String? appearance,
  }) => FuelData(
    vehicles: List.unmodifiable(vehicles ?? this.vehicles),
    fillUps: List.unmodifiable(fillUps ?? this.fillUps),
    primaryId: clearPrimary ? null : primaryId ?? this.primaryId,
    nextId: nextId ?? this.nextId,
    appearance: appearance ?? this.appearance,
  );
}

class FuelStore extends ChangeNotifier {
  FuelStore({Future<File> Function()? file}) : _file = file;

  factory FuelStore.local() => FuelStore(
    file: () async {
      final directory = await getApplicationSupportDirectory();
      return File('${directory.path}/fueliq.json');
    },
  );

  final Future<File> Function()? _file;
  FuelData _data = const FuelData();
  FuelData get data => _data;
  bool _busy = false;

  Future<void> load() async {
    final file = await _file?.call();
    if (file != null && await file.exists()) {
      _data = FuelData.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, Object?>,
      );
      notifyListeners();
    }
  }

  Future<void> _commit(FuelData next) async {
    if (_busy) throw StateError('Another change is being saved. Try again.');
    _busy = true;
    try {
      final file = await _file?.call();
      if (file != null) {
        await file.parent.create(recursive: true);
        final temp = File('${file.path}.tmp');
        await temp.writeAsString(jsonEncode(next.toJson()), flush: true);
        await temp.rename(file.path);
      }
      _data = next;
      notifyListeners();
    } finally {
      _busy = false;
    }
  }

  Future<void> saveVehicle({
    int? id,
    required int year,
    required String make,
    required String model,
    required String trim,
    required String? photo,
    required bool primary,
  }) async {
    if (make.trim().isEmpty ||
        model.trim().isEmpty ||
        year < 1886 ||
        year > DateTime.now().year + 1 ||
        (id != null && data.vehicle(id) == null)) {
      throw ArgumentError('Invalid vehicle.');
    }
    final vehicle = Vehicle(
      id: id ?? data.nextId,
      year: year,
      make: make.trim(),
      model: model.trim(),
      trim: trim.trim(),
      photo: photo,
    );
    await _commit(
      data.copyWith(
        vehicles: [
          for (final existing in data.vehicles)
            if (existing.id == id) vehicle else existing,
          if (id == null) vehicle,
        ],
        primaryId: primary || data.vehicles.isEmpty ? vehicle.id : null,
        nextId: id == null ? data.nextId + 1 : null,
      ),
    );
  }

  Future<void> deleteVehicle(int id) async {
    if (data.fillUps.any((entry) => entry.vehicleId == id)) {
      throw StateError('Delete this vehicle’s fill-ups first.');
    }
    final remaining = data.vehicles
        .where((vehicle) => vehicle.id != id)
        .toList();
    await _commit(
      data.copyWith(
        vehicles: remaining,
        primaryId: data.primaryId == id ? remaining.firstOrNull?.id : null,
        clearPrimary: remaining.isEmpty,
      ),
    );
  }

  Future<void> saveFillUp({
    int? id,
    required int vehicleId,
    required DateTime date,
    required int volume,
    required int price,
    required int total,
    required bool full,
    int? odometer,
    int? octane,
    String? station,
  }) async {
    final stationLabel = station?.trim();
    if ((stationLabel?.length ?? 0) > 250 ||
        data.vehicle(vehicleId) == null ||
        volume <= 0 ||
        volume > 999999 ||
        price <= 0 ||
        price > 99999 ||
        total <= 0 ||
        total > 999999 ||
        (octane != null && !isUsOctane(octane)) ||
        (odometer != null && (odometer < 0 || odometer > 9999999)) ||
        (id != null && !data.fillUps.any((entry) => entry.id == id))) {
      throw ArgumentError('Invalid fill-up.');
    }
    final entry = FillUp(
      id: id ?? data.nextId,
      vehicleId: vehicleId,
      date: date.toUtc(),
      volume: volume,
      price: price,
      total: total,
      full: full,
      odometer: odometer,
      octane: octane,
      station: stationLabel == null || stationLabel.isEmpty
          ? null
          : stationLabel,
    );
    final entries =
        [
          for (final existing in data.fillUps)
            if (existing.id == id) entry else existing,
          if (id == null) entry,
        ]..sort((a, b) {
          final dateOrder = b.date.compareTo(a.date);
          return dateOrder == 0 ? b.id.compareTo(a.id) : dateOrder;
        });
    await _commit(
      data.copyWith(
        fillUps: entries,
        nextId: id == null ? data.nextId + 1 : null,
      ),
    );
  }

  Future<void> deleteFillUp(int id) => _commit(
    data.copyWith(
      fillUps: data.fillUps.where((entry) => entry.id != id).toList(),
    ),
  );

  Future<void> setAppearance(String value) =>
      _commit(data.copyWith(appearance: value));
}
