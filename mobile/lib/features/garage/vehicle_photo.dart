import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';

Future<String> prepareVehiclePhoto(XFile file) async {
  if (await file.length() > 20 * 1024 * 1024) {
    throw const FormatException('Choose an image under 20 MB.');
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(
    await file.readAsBytes(),
  );
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      if (descriptor.width * descriptor.height > 50000000) {
        throw const FormatException('Choose a smaller image.');
      }
      final scale = math.min(
        1.0,
        720 / math.max(descriptor.width, descriptor.height),
      );
      final codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).round()),
        targetHeight: math.max(1, (descriptor.height * scale).round()),
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          final png = await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (png == null) {
            throw const FormatException('Image could not be saved.');
          }
          return base64Encode(
            png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
          );
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } finally {
      descriptor.dispose();
    }
  } finally {
    buffer.dispose();
  }
}

class VehiclePhoto extends StatelessWidget {
  const VehiclePhoto(this.photo, {super.key, required this.size});
  final String photo;
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.memory(
      base64Decode(photo),
      width: size,
      height: size,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => SizedBox.square(
        dimension: size,
        child: const Icon(CupertinoIcons.car_detailed),
      ),
    ),
  );
}
