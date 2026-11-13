import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

const _pickerChannel = MethodChannel('fueliq/photo_picker');

Future<XFile?> showPhotoPicker(
  BuildContext context, {
  required String title,
}) async {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    try {
      final path = await _pickerChannel.invokeMethod<String>('pickPhoto');
      return path == null ? null : XFile(path);
    } on PlatformException catch (error) {
      if (error.code != 'inline_picker_unsupported') rethrow;
    }
    if (!context.mounted) return null;
  }
  final source = await _choosePhotoSource(context, title: title);
  if (source == null || !context.mounted) return null;
  return ImagePicker().pickImage(source: source, requestFullMetadata: false);
}

Future<List<XFile?>> showFuelPhotoPicker(BuildContext context) async {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    try {
      final paths = await _pickerChannel.invokeListMethod<String?>(
        'pickFuelPhotos',
      );
      return [
        for (final path in paths ?? []) path == null ? null : XFile(path),
      ];
    } on PlatformException catch (error) {
      if (error.code != 'inline_picker_unsupported') rethrow;
    }
    if (!context.mounted) return [];
  }
  final source = await _choosePhotoSource(context, title: 'Scan a fill-up');
  if (source == null || !context.mounted) return [];
  final picker = ImagePicker();
  if (source == ImageSource.gallery) {
    return picker.pickMultiImage(requestFullMetadata: false);
  }
  final photo = await picker.pickImage(
    source: source,
    requestFullMetadata: false,
  );
  return [?photo];
}

Future<ImageSource?> _choosePhotoSource(
  BuildContext context, {
  required String title,
}) => showCupertinoModalPopup<ImageSource>(
  context: context,
  builder: (sheetContext) => CupertinoActionSheet(
    title: Text(title),
    actions: [
      CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(sheetContext, ImageSource.camera),
        child: const Text('Take photo'),
      ),
      CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(sheetContext, ImageSource.gallery),
        child: const Text('Choose from Photos'),
      ),
    ],
    cancelButton: CupertinoActionSheetAction(
      onPressed: () => Navigator.pop(sheetContext),
      child: const Text('Cancel'),
    ),
  ),
);

Future<void> discardPickedPhoto(XFile photo) async {
  final file = File(photo.path).absolute;
  // Both iOS pickers return an app-owned copy in the temporary directory.
  if (!Platform.isIOS ||
      file.parent.path != Directory.systemTemp.absolute.path) {
    return;
  }
  try {
    await file.delete();
  } on FileSystemException {
    // iOS can purge the temporary directory if immediate removal fails.
  }
}
