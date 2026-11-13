import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'fuel_photo_parser.dart';

const _channel = MethodChannel('fueliq/fuel_photo');

typedef DisplayValue = ({int value, double score});
typedef PumpDisplay = ({List<DisplayValue> totals, List<DisplayValue> gallons});
typedef FuelPhotoScan = ({
  Map<FuelPhotoField, PhotoReading> readings,
  List<PumpDisplay> displays,
  DateTime? capturedAt,
});

Future<FuelPhotoScan> scanFuelPhoto(XFile photo) async {
  if (File(photo.path).lengthSync() > 30 * 1024 * 1024) {
    throw const FormatException('Choose a photo under 30 MB.');
  }
  final response = await _channel.invokeMapMethod<String, Object?>(
    'recognize',
    photo.path,
  );
  return decodeFuelPhotoScan(response ?? const {});
}

FuelPhotoScan decodeFuelPhotoScan(Map<String, Object?> response) {
  final readings = combinePhotoReadings(
    parseFuelPhotoTextRows(response['text']),
    parseFuelPhotoTextRows(response['alternateText']),
  );
  return (
    readings: readings,
    capturedAt: parsePhotoCaptureDate(
      response['capturedAt'] as String?,
      response['captureOffset'] as String?,
    ),
    displays: [
      for (final row in (response['display'] as List? ?? []).cast<Map>())
        (
          totals: _displayValues(row['totals']),
          gallons: _displayValues(row['gallons']),
        ),
    ],
  );
}

Map<FuelPhotoField, PhotoReading> parseFuelPhotoTextRows(Object? rows) =>
    parseFuelPhoto([
      for (final row in (rows as List? ?? []).cast<Map>())
        PhotoText(
          row['text'] as String,
          confidence: (row['confidence'] as num).toDouble(),
          x: (row['x'] as num).toDouble(),
          y: (row['y'] as num).toDouble(),
          width: (row['width'] as num).toDouble(),
          height: (row['height'] as num).toDouble(),
        ),
    ]);
Map<FuelPhotoField, PhotoReading> combinePhotoReadings(
  Map<FuelPhotoField, PhotoReading> vision,
  Map<FuelPhotoField, PhotoReading> alternate,
) {
  final combined = {...alternate, ...vision};
  for (final entry in alternate.entries) {
    final original = vision[entry.key];
    if (original != null && original.value != entry.value.value) {
      combined.remove(entry.key);
    }
  }
  return combined;
}

DateTime? parsePhotoCaptureDate(String? value, String? offset) {
  if (value == null) return null;
  final parts = RegExp(
    r'^(\d{4}):(\d{2}):(\d{2}) (\d{2}:\d{2}:\d{2})$',
  ).firstMatch(value);
  if (parts == null) return null;
  final wallTime = '${parts[1]}-${parts[2]}-${parts[3]}T${parts[4]}';
  final local = DateTime.tryParse(wallTime);
  if (local == null || !local.toIso8601String().startsWith(wallTime)) {
    return null;
  }
  if (offset == null ||
      !RegExp(r'^[+-](?:0\d|1[0-4]):[0-5]\d$').hasMatch(offset)) {
    return local;
  }
  return DateTime.tryParse('$wallTime$offset')?.toLocal();
}

List<DisplayValue> _displayValues(Object? rows) => [
  for (final row in (rows as List).cast<Map>())
    (value: row['value'] as int, score: (row['score'] as num).toDouble()),
];

({int total, int gallons})? matchPumpDisplay(
  Iterable<PumpDisplay> displays, {
  required int price,
  int? knownTotal,
  int? knownGallons,
}) {
  final scores = <({int total, int gallons}), double>{};
  for (final display in displays) {
    final totals = {
      for (final total in display.totals) total.value: total.score,
    };
    for (final gallons in display.gallons) {
      if (gallons.value > 999999 ||
          (knownGallons != null && gallons.value != knownGallons)) {
        continue;
      }
      final total = (gallons.value * price + 5000) ~/ 10000;
      if (total > 999999 || (knownTotal != null && total != knownTotal)) {
        continue;
      }
      final totalScore = totals[total];
      if (totalScore == null) continue;
      final pair = (total: total, gallons: gallons.value);
      final score = totalScore + gallons.score;
      if (score > (scores[pair] ?? 0)) scores[pair] = score;
    }
  }
  final ranked = scores.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (ranked.isEmpty ||
      (ranked.length > 1 && ranked.first.value - ranked[1].value < 0.20)) {
    return null;
  }
  return ranked.first.key;
}
