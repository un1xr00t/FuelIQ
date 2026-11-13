class Vehicle {
  const Vehicle({
    required this.id,
    required this.year,
    required this.make,
    required this.model,
    this.trim = '',
    this.photo,
  });

  final int id;
  final int year;
  final String make;
  final String model;
  final String trim;
  final String? photo;

  String get name => '$year $make $model';

  factory Vehicle.fromJson(Map<String, Object?> json) => Vehicle(
    id: json['id'] as int,
    year: json['year'] as int,
    make: json['make'] as String,
    model: json['model'] as String,
    trim: json['trim'] as String,
    photo: json['photo'] as String?,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'year': year,
    'make': make,
    'model': model,
    'trim': trim,
    'photo': photo,
  };
}

class FillUp {
  const FillUp({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.volume,
    required this.price,
    required this.total,
    required this.full,
    this.odometer,
    this.octane,
    this.station,
  });

  final int id;
  final int vehicleId;
  final DateTime date;
  final int volume; // Thousandths of a US gallon.
  final int price; // Thousandths of a US dollar per gallon.
  final int total; // US cents paid.
  final bool full;
  final int? odometer;
  final int? octane;
  final String? station;

  factory FillUp.fromJson(Map<String, Object?> json) => FillUp(
    id: json['id'] as int,
    vehicleId: json['vehicleId'] as int,
    date: DateTime.parse(json['date'] as String).toUtc(),
    volume: json['volume'] as int,
    price: json['price'] as int,
    total: json['total'] as int,
    full: json['full'] as bool,
    odometer: json['odometer'] as int?,
    octane: json['octane'] as int?,
    station: json['station'] as String?,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'vehicleId': vehicleId,
    'date': date.toUtc().toIso8601String(),
    'volume': volume,
    'price': price,
    'total': total,
    'full': full,
    'odometer': odometer,
    if (octane != null) 'octane': octane,
    if (station != null) 'station': station,
  };

  int get expectedTotal => (volume * price + 5000) ~/ 10000;
  bool get hasDiscrepancy => (total - expectedTotal).abs() > 2;
}

bool isUsOctane(int value) => value >= 85 && value <= 99;

int? parseFixed(String input, int places, {required int maximum}) {
  final match = RegExp(
    r'^(\d{0,8})(?:[.,](\d{1,3}))?$',
  ).firstMatch(input.trim());
  if (match == null) return null;
  final whole = match[1]!;
  final fraction = match[2] ?? '';
  if ((whole.isEmpty && fraction.isEmpty) || fraction.length > places) {
    return null;
  }
  final scaled = int.parse(
    '${whole.isEmpty ? '0' : whole}${fraction.padRight(places, '0')}',
  );
  return scaled <= maximum ? scaled : null;
}

String fixed(int value, int places) {
  final digits = value.toString().padLeft(places + 1, '0');
  final split = digits.length - places;
  return '${digits.substring(0, split)}.${digits.substring(split)}';
}

String dollars(int cents) => '\$${fixed(cents, 2)}';
