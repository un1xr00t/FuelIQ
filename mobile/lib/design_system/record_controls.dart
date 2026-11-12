import 'package:flutter/cupertino.dart';

import 'fuel_page.dart';
import 'fuel_theme.dart';

class RecordRow extends StatelessWidget {
  const RecordRow({
    super.key,
    required this.title,
    required this.detail,
    required this.icon,
    required this.onPressed,
    this.thumbnail,
  });

  final String title;
  final String detail;
  final IconData icon;
  final VoidCallback onPressed;
  final Widget? thumbnail;

  @override
  Widget build(BuildContext context) => FuelSurface(
    child: CupertinoButton(
      padding: const EdgeInsets.all(FuelTheme.gap),
      onPressed: onPressed,
      child: Row(
        children: [
          thumbnail ?? FuelIconTile(icon),
          const SizedBox(width: FuelTheme.gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: FuelTheme.rowTitle.copyWith(
                    color: FuelTheme.resolve(context, FuelTheme.ink),
                  ),
                ),
                Text(
                  detail,
                  style: FuelTheme.body.copyWith(
                    color: FuelTheme.resolve(context, FuelTheme.muted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: FuelTheme.compact),
          ExcludeSemantics(
            child: Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: FuelTheme.resolve(context, FuelTheme.muted),
            ),
          ),
        ],
      ),
    ),
  );
}

class RecordField extends StatelessWidget {
  const RecordField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.maxLength,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int? maxLength;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: FuelTheme.gap),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(child: Text(label, style: FuelTheme.body)),
        const SizedBox(height: FuelTheme.compact),
        Semantics(
          label: label,
          child: CupertinoTextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLength: maxLength,
            padding: const EdgeInsets.all(FuelTheme.gap),
            style: FuelTheme.body.copyWith(
              color: FuelTheme.resolve(context, FuelTheme.ink),
            ),
          ),
        ),
      ],
    ),
  );
}

Future<void> showRecordError(BuildContext context, String message) =>
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Check this entry'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );

Future<bool> confirmRecordAction(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  bool destructive = false,
}) async =>
    await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: destructive,
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;
