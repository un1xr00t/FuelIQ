import '../../data/fuel_records.dart';

enum FuelPhotoField { gallons, price, total, octane }

typedef PhotoReading = ({int value, double confidence});

class PhotoText {
  const PhotoText(
    this.text, {
    this.confidence = 1,
    this.x = 0,
    this.y = 0,
    this.width = 0,
    this.height = 0,
  });

  final String text;
  final double confidence;
  final double x;
  final double y;
  final double width;
  final double height;

  double get centerY => y + height / 2;
}

final _number = RegExp(r'^\s*[:=@]?\s*\$?\s*(\d{1,5}(?:\.\d{1,3})?)\s*$');
final _misreadPrice = RegExp(r'^\s*\$?\s*(\d),\s+(\d{3})\s*$');
final _leadingNumber = RegExp(r'^\$?\s*(\d{1,5}(?:\.\d{1,3})?)\s+');
final _labelEnd = RegExp(r'^\s*[:=\$]?\s*$');
final _rules =
    {
      FuelPhotoField.gallons: [r'(?:us\s+)?gal(?:lons?|s)?\.?'],
      FuelPhotoField.price: [
        r'price\s*(?:per|/)\s*\$?\s*(?:us\s+)?gal(?:lons?)?\.?|price\s*/\s*g|\$\s*/\s*gal(?:lons?)?\.?|unit price|ppg',
      ],
      FuelPhotoField.total: [
        r'fuel total|total fuel|fuel sale',
        r'total sale|sale total|amount paid|total paid|total due|grand total|(?:\$\s*)?this sale|sale(?=\s*\$)|total',
      ],
      FuelPhotoField.octane: [
        r'(?:minimum\s+)?(?:selected\s+)?(?:fuel\s+)?(?:octane|grade|aki)(?:\s+rating)?',
      ],
    }.map(
      (field, rules) => MapEntry(
        field,
        rules
            .map(
              (rule) => RegExp(
                '^(?:$rule)'
                r'(?=\s|[:=$]|$)',
                caseSensitive: false,
              ),
            )
            .toList(),
      ),
    );

final _gallonsSuffix = RegExp(
  r'^(\d{1,5}(?:\.\d{1,3})?)\s+(?:US\s+)?gal(?:lons?|s)?\.?$',
  caseSensitive: false,
);
final _priceSuffix = RegExp(
  r'^\$?(\d{1,3}\.\d{2,3})\s*(?:/|per)\s*(?:US\s+)?gal(?:lons?)?\.?$',
  caseSensitive: false,
);
final _octaneSuffix = RegExp(
  r'^(\d{2})\s*(?:AKI|octane)$',
  caseSensitive: false,
);
final _receiptFuelLine = RegExp(
  r'^(\d{1,5}(?:\.\d{1,3})?)\s+gal(?:lons?)?\s*@\s*\$?(\d{1,3}\.\d{2,3})(?:\s*/\s*gal)?$',
  caseSensitive: false,
);
final _gradeList = RegExp(r'\b(?:8[0-9]|9[0-9])\b');

int? _value(FuelPhotoField field, String number) {
  final value = switch (field) {
    FuelPhotoField.gallons => parseFixed(number, 3, maximum: 999999),
    FuelPhotoField.price => parseFixed(number, 3, maximum: 99999),
    FuelPhotoField.total => parseFixed(number, 2, maximum: 999999),
    FuelPhotoField.octane =>
      number.length == 2 && !number.contains('.') ? int.tryParse(number) : null,
  };
  if (value == null || value <= 0) return null;
  if (field == FuelPhotoField.octane && !isUsOctane(value)) return null;
  return value;
}

PhotoReading? _nearbyValue(
  FuelPhotoField field,
  PhotoText label,
  List<PhotoText> lines,
) {
  if (label.height <= 0) return null;
  final isPumpGrade = label.text.trim().toLowerCase().startsWith(
    'minimum octane',
  );
  final candidates = <({double distance, PhotoReading reading})>[];
  for (final line in lines) {
    if (identical(label, line) || line.height <= 0) continue;
    final comma = field == FuelPhotoField.price
        ? _misreadPrice.firstMatch(line.text)
        : null;
    final number =
        _number.firstMatch(line.text)?[1] ??
        (comma == null ? null : '${comma[1]}.${comma[2]}');
    if (number == null) continue;
    // A pump sale display includes cents. A standalone integer can be a
    // seven-segment reading whose decimal point was lost by OCR.
    if (field == FuelPhotoField.total &&
        label.text.toLowerCase().contains('this sale') &&
        !number.contains('.')) {
      continue;
    }
    final value = _value(field, number);
    if (value == null) continue;

    final rowGap = line.x - (label.x + label.width);
    final verticalOffset = (line.centerY - label.centerY).abs();
    final columnGap =
        (line.centerY - label.centerY).abs() - (label.height + line.height) / 2;
    final overlap =
        line.x < label.x + label.width && label.x < line.x + line.width;
    final sameRow = rowGap >= -0.01 && verticalOffset <= label.height * 0.6;
    final sameColumn =
        (field != FuelPhotoField.octane ||
            (isPumpGrade && line.centerY < label.centerY)) &&
        overlap &&
        columnGap >= -0.01 &&
        columnGap <= (label.height + line.height);
    if (!sameRow && !sameColumn) continue;
    if (!sameRow &&
        lines.any(
          (other) =>
              !identical(other, label) &&
              !identical(other, line) &&
              !(isPumpGrade &&
                  other.text.trim().toUpperCase().endsWith('/2 METHOD')) &&
              (other.centerY - label.centerY) * (other.centerY - line.centerY) <
                  0 &&
              other.x < line.x + line.width &&
              line.x < other.x + other.width,
        )) {
      continue;
    }
    candidates.add((
      distance: sameRow ? verticalOffset + rowGap * 0.1 : 1 + columnGap,
      reading: (
        value: value,
        confidence:
            0.8 *
            (line.confidence < label.confidence
                ? line.confidence
                : label.confidence),
      ),
    ));
  }
  candidates.sort((a, b) => a.distance.compareTo(b.distance));
  if (candidates.isEmpty) return null;
  if (candidates.length > 1 &&
      candidates[1].distance - candidates.first.distance < 0.015 &&
      candidates[1].reading.value != candidates.first.reading.value) {
    return null;
  }
  return candidates.first.reading;
}

Map<FuelPhotoField, PhotoReading> parseFuelPhoto(List<PhotoText> lines) {
  final readings = <FuelPhotoField, PhotoReading>{};
  for (final field in FuelPhotoField.values) {
    final candidates = <({int priority, PhotoReading reading})>[];
    for (final line in lines) {
      final text = line.text.trim();
      final suffix = switch (field) {
        FuelPhotoField.gallons => _gallonsSuffix,
        FuelPhotoField.price => _priceSuffix,
        FuelPhotoField.octane => _octaneSuffix,
        FuelPhotoField.total => null,
      };
      final suffixNumber = suffix?.firstMatch(text)?[1];
      final receiptLine = _receiptFuelLine.firstMatch(text);
      final receiptNumber = switch (field) {
        FuelPhotoField.gallons => receiptLine?[1],
        FuelPhotoField.price => receiptLine?[2],
        _ => null,
      };
      final fuelNumber = suffixNumber ?? receiptNumber;
      if (fuelNumber != null) {
        final value = _value(field, fuelNumber);
        if (value != null) {
          candidates.add((
            priority: 0,
            reading: (value: value, confidence: line.confidence),
          ));
        }
      }

      final rules = _rules[field]!;
      final leading = field == FuelPhotoField.octane
          ? null
          : _leadingNumber.firstMatch(text);
      for (var i = 0; i < rules.length; i++) {
        if (leading != null) {
          final label = text.substring(leading.end);
          final labelMatch = rules[i].firstMatch(label);
          final value = _value(field, leading[1]!);
          if (labelMatch != null &&
              _labelEnd.hasMatch(label.substring(labelMatch.end)) &&
              value != null) {
            candidates.add((
              priority: i,
              reading: (value: value, confidence: line.confidence),
            ));
            break;
          }
        }
        final match = rules[i].firstMatch(text);
        if (match == null) continue;
        final rest = text.substring(match.end);
        if (field == FuelPhotoField.total &&
            RegExp(
              r'^\s*(tax|sav|discount|change)',
              caseSensitive: false,
            ).hasMatch(rest)) {
          continue;
        }
        final number = _number.firstMatch(rest)?[1];
        final value = number == null ? null : _value(field, number);
        final reading = value != null
            ? (value: value, confidence: line.confidence)
            : _labelEnd.hasMatch(rest)
            ? _nearbyValue(field, line, lines)
            : null;
        if (reading != null) candidates.add((priority: i, reading: reading));
        break;
      }
    }
    if (candidates.isEmpty) continue;
    final bestPriority = candidates
        .map((candidate) => candidate.priority)
        .reduce((a, b) => a < b ? a : b);
    final best = candidates
        .where((candidate) => candidate.priority == bestPriority)
        .map((candidate) => candidate.reading)
        .toList();
    if (best.any((reading) => reading.value != best.first.value)) continue;
    if (field == FuelPhotoField.octane &&
        lines.any(
          (line) =>
              _gradeList
                      .allMatches(line.text)
                      .map((match) => match[0])
                      .toSet()
                      .length >
                  1 &&
              !RegExp(r'[.$]').hasMatch(line.text),
        )) {
      continue;
    }
    readings[field] = best.reduce(
      (a, b) => a.confidence >= b.confidence ? a : b,
    );
  }
  return readings;
}
