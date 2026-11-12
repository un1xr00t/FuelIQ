import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

const _pickerChannel = MethodChannel('fueliq/photo_picker');

Future<XFile?> showPhotoPicker(
  BuildContext context, {
  required String title,
  String? message,
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
  final source = await showCupertinoModalPopup<ImageSource>(
    context: context,
    builder: (sheetContext) => CupertinoActionSheet(
      title: Text(title),
      message: message == null ? null : Text(message),
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
  if (source == null || !context.mounted) return null;
  return ImagePicker().pickImage(source: source, requestFullMetadata: false);
}

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
