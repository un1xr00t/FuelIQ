import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fueliq/features/fill_ups/fuel_photo_parser.dart';
import 'package:fueliq/features/fill_ups/fuel_photo_scanner.dart';

void main() {
  final fixture = Platform.environment['FUELIQ_PUMP_SCAN_JSON'];
  test(
    'reports scanner output against expected fill-up fields',
    () {
      final photos = (jsonDecode(File(fixture!).readAsStringSync()) as List)
          .cast<Map<String, Object?>>();
      final scans = photos.map(decodeFuelPhotoScan).toList();
      for (final (index, photo) in photos.indexed) {
        final scan = scans[index];
        stdout.writeln('Photo ${index + 1}, capture ${scan.capturedAt}');
        if (photo['visionError'] case final error?) {
          stdout.writeln('Apple Vision error $error');
        }
        for (final source in ['text', 'alternateText']) {
          final rows = (photo[source] as List?) ?? [];
          stdout.writeln('$source ${rows.map((row) => row['text']).toList()}');
          stdout.writeln('Parsed ${parseFuelPhotoTextRows(rows)}');
        }
        for (final display in scan.displays) {
          final totals = [...display.totals]
            ..sort((a, b) => b.score.compareTo(a.score));
          final gallons = [...display.gallons]
            ..sort((a, b) => b.score.compareTo(a.score));
          stdout.writeln('Display totals ${totals.take(3).toList()}');
          stdout.writeln('Display gallons ${gallons.take(3).toList()}');
        }
        expect(photo['error'], isNull);
      }
      final readings = <FuelPhotoField, PhotoReading>{};
      final conflicts = <FuelPhotoField>{};
      for (final scan in scans) {
        for (final entry in scan.readings.entries) {
          if (conflicts.contains(entry.key)) continue;
          final current = readings[entry.key];
          if (current != null && current.value != entry.value.value) {
            conflicts.add(entry.key);
            readings.remove(entry.key);
          } else {
            readings[entry.key] = entry.value;
          }
        }
      }
      final price = readings[FuelPhotoField.price]?.value;
      if (price != null &&
          !conflicts.contains(FuelPhotoField.total) &&
          !conflicts.contains(FuelPhotoField.gallons)) {
        final display = matchPumpDisplay(
          scans.expand((scan) => scan.displays),
          price: price,
          knownTotal: readings[FuelPhotoField.total]?.value,
          knownGallons: readings[FuelPhotoField.gallons]?.value,
        );
        if (display != null) {
          readings[FuelPhotoField.total] ??= (
            value: display.total,
            confidence: .7,
          );
          readings[FuelPhotoField.gallons] ??= (
            value: display.gallons,
            confidence: .7,
          );
        }
      }
      final actual = readings.map(
        (field, reading) => MapEntry(field.name, reading.value),
      );
      stdout.writeln('Final fields $actual. Conflicts $conflicts');
      final expected = Platform.environment['FUELIQ_PUMP_EXPECTED_JSON'];
      if (expected != null) expect(actual, jsonDecode(expected));
    },
    skip: fixture == null ? 'Set FUELIQ_PUMP_SCAN_JSON to run locally.' : false,
  );
}
