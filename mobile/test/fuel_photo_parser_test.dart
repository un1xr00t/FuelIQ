import 'package:fueliq/features/fill_ups/claude_vision.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fueliq/features/fill_ups/fuel_photo_parser.dart';
import 'package:fueliq/features/fill_ups/fuel_photo_scanner.dart';

void main() {
  test('decodes Claude fenced JSON and validates extracted amounts', () {
    final readings = parseClaudeReadings(
      '```json\n{"total_usd":"43.04","gallons_us":"7.971",'
      '"price_usd_per_gallon":"5.399","octane_aki":93}\n```',
    );
    expect(readings.map((field, reading) => MapEntry(field, reading.value)), {
      FuelPhotoField.total: 4304,
      FuelPhotoField.gallons: 7971,
      FuelPhotoField.price: 5399,
      FuelPhotoField.octane: 93,
    });
    expect(
      parseClaudeReadings('{"total_usd":"4304","octane_aki":100}'),
      isEmpty,
    );
  });

  test('uses alternate OCR for missing fields and omits disagreements', () {
    final readings = combinePhotoReadings(
      const {
        FuelPhotoField.octane: (value: 93, confidence: 1.0),
        FuelPhotoField.total: (value: 4504, confidence: 0.8),
      },
      const {
        FuelPhotoField.total: (value: 4304, confidence: 0.8),
        FuelPhotoField.price: (value: 5399, confidence: 0.8),
        FuelPhotoField.gallons: (value: 7971, confidence: 0.8),
      },
    );
    expect(readings[FuelPhotoField.octane]?.value, 93);
    expect(readings[FuelPhotoField.total], isNull);
    expect(readings[FuelPhotoField.price]?.value, 5399);
    expect(readings[FuelPhotoField.gallons]?.value, 7971);
  });
  test('does not treat a pump reading with missing cents as whole dollars', () {
    final readings = parseFuelPhoto(const [
      PhotoText('THIS SALE', x: .1, y: .78, width: .3, height: .04),
      PhotoText('4304', x: .15, y: .55, width: .6, height: .18),
    ]);
    expect(readings[FuelPhotoField.total], isNull);
  });
  test('parses original capture time with and without an EXIF offset', () {
    expect(
      parsePhotoCaptureDate('2025:12:03 16:20:05', '-05:00')?.toUtc(),
      DateTime.utc(2025, 12, 3, 21, 20, 5),
    );
    expect(
      parsePhotoCaptureDate('2025:12:03 16:20:05', null),
      DateTime(2025, 12, 3, 16, 20, 5),
    );
    expect(parsePhotoCaptureDate('2025:02:30 16:20:05', null), isNull);
    expect(parsePhotoCaptureDate(null, null), isNull);
  });
  test('reads a decimal price and single octane label on a grade panel', () {
    final readings = parseFuelPhoto(const [
      PhotoText('5, 189', x: .35, y: .482, width: .177, height: .05),
      PhotoText('PRICE PER GALLON', x: .36, y: .409, width: .144, height: .02),
      PhotoText(
        'MINIMUM OCTANE RATING',
        x: .345,
        y: .242,
        width: .18,
        height: .03,
      ),
      PhotoText('(R+-M)/2 METHOD', x: .386, y: .236, width: .1, height: .022),
      PhotoText('93', x: .347, y: .162, width: .186, height: .083),
    ]);
    expect(readings[FuelPhotoField.price]?.value, 5189);
    expect(readings[FuelPhotoField.octane]?.value, 93);
    expect(readings[FuelPhotoField.octane]!.confidence, lessThan(.85));
  });

  test('requires exact cents and a clear match for an unlabeled display', () {
    const display = (
      totals: [
        (value: 5015, score: 1.08),
        (value: 5013, score: .99),
        (value: 5973, score: .84),
      ],
      gallons: [(value: 9661, score: 1.04), (value: 11511, score: .89)],
    );
    expect(matchPumpDisplay([display], price: 5189), (
      total: 5013,
      gallons: 9661,
    ));
    expect(matchPumpDisplay([display], price: 5100), isNull);
    expect(matchPumpDisplay([display], price: 5189, knownTotal: 5015), isNull);
    expect(
      matchPumpDisplay([
        display,
        (
          totals: [(value: 5973, score: .98)],
          gallons: [(value: 11511, score: 1.04)],
        ),
      ], price: 5189),
      isNull,
    );
  });
  test('extracts fuel amounts from a receipt and prefers fuel total', () {
    final readings = parseFuelPhoto(const [
      PhotoText(r'9.950 GAL @ $6.030'),
      PhotoText('Grade: 93'),
      PhotoText(r'Fuel total $60.00', confidence: 0.94),
      PhotoText(r'TOTAL $65.00'),
      PhotoText(r'Total tax $0.35'),
    ]);
    expect(readings[FuelPhotoField.gallons]?.value, 9950);
    expect(readings[FuelPhotoField.price]?.value, 6030);
    expect(readings[FuelPhotoField.total], (value: 6000, confidence: 0.94));
    expect(readings[FuelPhotoField.octane]?.value, 93);
  });

  test('matches a separated pump display and leaves octane buttons blank', () {
    final readings = parseFuelPhoto(const [
      PhotoText('This Sale', x: 0.1, y: 0.75, width: 0.2, height: 0.04),
      PhotoText(r'$60.00', x: 0.5, y: 0.75, width: 0.25, height: 0.04),
      PhotoText('Gallons', x: 0.1, y: 0.6, width: 0.2, height: 0.04),
      PhotoText('9.95', x: 0.5, y: 0.6, width: 0.25, height: 0.04),
      PhotoText('87'),
      PhotoText('89'),
      PhotoText('93'),
    ]);
    expect(readings[FuelPhotoField.gallons]?.value, 9950);
    expect(readings[FuelPhotoField.total]?.value, 6000);
    expect(readings[FuelPhotoField.total]!.confidence, lessThan(0.85));
    expect(readings[FuelPhotoField.octane], isNull);
    expect(readings[FuelPhotoField.price], isNull);
  });

  test('leaves competing or unrelated receipt values blank', () {
    final readings = parseFuelPhoto(const [
      PhotoText('87 AKI'),
      PhotoText('93 AKI'),
      PhotoText(r'Total $60.00'),
      PhotoText(r'Total $75.00'),
      PhotoText(r'Subtotal $58.00'),
      PhotoText(r'Total discounts $2.00'),
      PhotoText('Pump 09'),
      PhotoText('Gallons 10.0000'),
      PhotoText('Volume 10.000'),
    ]);
    expect(readings, isEmpty);
  });

  test('recognizes a sale label with its dollar sign attached', () {
    final readings = parseFuelPhoto(const [PhotoText(r'Sale $60.00')]);
    expect(readings[FuelPhotoField.total]?.value, 6000);
  });

  test('reads pump amounts below smaller printed labels', () {
    final readings = parseFuelPhoto(const [
      PhotoText(r'$ THIS SALE', x: 0.3, y: 0.8, width: 0.2, height: 0.02),
      PhotoText('43.18', x: 0.3, y: 0.71, width: 0.2, height: 0.055),
      PhotoText('GALLONS', x: 0.3, y: 0.63, width: 0.2, height: 0.02),
      PhotoText('12.340', x: 0.3, y: 0.54, width: 0.2, height: 0.055),
      PhotoText(r'$/GAL', x: 0.3, y: 0.46, width: 0.2, height: 0.02),
      PhotoText('3.499', x: 0.3, y: 0.37, width: 0.2, height: 0.055),
    ]);
    expect(readings[FuelPhotoField.total]?.value, 4318);
    expect(readings[FuelPhotoField.gallons]?.value, 12340);
    expect(readings[FuelPhotoField.price]?.value, 3499);
    expect(readings[FuelPhotoField.price]!.confidence, lessThan(0.85));
  });

  test('reads amounts before a label in the same OCR line', () {
    final readings = parseFuelPhoto(const [
      PhotoText(r'$43.18 THIS SALE'),
      PhotoText('12.340 GALLONS'),
      PhotoText(r'3.499 $/GAL'),
      PhotoText('93 89 87'),
    ]);
    expect(readings[FuelPhotoField.total]?.value, 4318);
    expect(readings[FuelPhotoField.gallons]?.value, 12340);
    expect(readings[FuelPhotoField.price]?.value, 3499);
    expect(readings[FuelPhotoField.octane], isNull);
  });

  test('leaves equally close stacked values blank', () {
    final readings = parseFuelPhoto(const [
      PhotoText('13.000', x: 0.3, y: 0.72, width: 0.2, height: 0.03),
      PhotoText('GALLONS', x: 0.3, y: 0.66, width: 0.2, height: 0.03),
      PhotoText('12.340', x: 0.3, y: 0.60, width: 0.2, height: 0.03),
    ]);
    expect(readings[FuelPhotoField.gallons], isNull);
  });
}
