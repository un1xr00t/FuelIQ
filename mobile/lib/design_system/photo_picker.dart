import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';

Future<XFile?> showPhotoPicker(
  BuildContext context, {
  required String title,
  String? message,
}) async {
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
  // image_picker_ios returns an app-owned copy in the temporary directory.
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
