import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'fuel_photo_parser.dart';

const _channel = MethodChannel('fueliq/fuel_photo');

Future<Map<FuelPhotoField, PhotoReading>> scanFuelPhoto(XFile photo) async {
  if (File(photo.path).lengthSync() > 30 * 1024 * 1024) {
    throw const FormatException('Choose a photo under 30 MB.');
  }
  final rows = await _channel.invokeListMethod<Map<Object?, Object?>>(
    'recognize',
    photo.path,
  );
  return parseFuelPhoto([
    for (final row in rows ?? const <Map<Object?, Object?>>[])
      PhotoText(
        row['text'] as String,
        confidence: (row['confidence'] as num).toDouble(),
        x: (row['x'] as num).toDouble(),
        y: (row['y'] as num).toDouble(),
        width: (row['width'] as num).toDouble(),
        height: (row['height'] as num).toDouble(),
      ),
  ]);
}
