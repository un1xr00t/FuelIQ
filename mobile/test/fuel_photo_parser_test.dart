import 'package:flutter_test/flutter_test.dart';
import 'package:fueliq/features/fill_ups/fuel_photo_parser.dart';

void main() {
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
}
