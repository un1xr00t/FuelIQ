import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/fuel_store.dart';
import '../../design_system/fuel_page.dart';
import '../../design_system/fuel_theme.dart';
import '../../design_system/record_controls.dart';
import '../fill_ups/claude_vision.dart';

enum Appearance {
  system('System', null),
  light('Light', Brightness.light),
  dark('Dark', Brightness.dark);

  const Appearance(this.label, this.brightness);

  final String label;
  final Brightness? brightness;

  static Appearance saved(String value) =>
      values.where((option) => option.name == value).firstOrNull ?? dark;
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.store,
    required this.appearance,
    required this.onAppearanceChanged,
    required this.hideStationAddresses,
    required this.onHideStationAddressesChanged,
  });

  final FuelStore store;
  final Appearance appearance;
  final ValueChanged<Appearance> onAppearanceChanged;
  final bool hideStationAddresses;
  final ValueChanged<bool> onHideStationAddressesChanged;

  Future<void> _configureClaude(BuildContext context) async {
    final bool configured;
    try {
      configured = await hasClaudeVisionKey();
    } on PlatformException {
      if (context.mounted) {
        await showRecordError(
          context,
          'Could not read the saved API key. Unlock your iPhone and try again.',
        );
      }
      return;
    }
    if (!context.mounted) return;
    var enteredKey = '';
    final key = await showCupertinoDialog<String>(
      context: context,
      builder: (dialog) => CupertinoAlertDialog(
        title: const Text('Claude Vision'),
        content: Column(
          children: [
            Text(
              configured
                  ? 'API key saved in Keychain. Enter a new key below to replace it.'
                  : 'With a key saved, Fuel Log sends selected photo images to Anthropic for paid Haiku scans. Capture metadata stays on your phone.',
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              onChanged: (value) => enteredKey = value,
              placeholder: configured ? 'New API key' : 'Anthropic API key',
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          if (configured)
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(dialog, ''),
              child: const Text('Remove key'),
            ),
          CupertinoDialogAction(
            onPressed: () {
              final value = enteredKey.trim();
              if (value.isNotEmpty) Navigator.pop(dialog, value);
            },
            child: const Text('Save key'),
          ),
        ],
      ),
    );
    if (key == null) return;
    final saved = await saveClaudeVisionKey(key);
    if (!context.mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialog) => CupertinoAlertDialog(
        title: Text(
          saved
              ? (key.isEmpty
                    ? 'Claude Vision disabled'
                    : 'Claude Vision enabled')
              : 'Could not update API key',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FuelPage(
      title: 'Settings',
      children: [
        FuelSurface(
          child: Padding(
            padding: const EdgeInsets.all(FuelTheme.inset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: const Text('Appearance', style: FuelTheme.heading),
                ),
                const SizedBox(height: FuelTheme.gap),
                for (final option in Appearance.values)
                  Semantics(
                    selected: option == appearance,
                    child: CupertinoButton(
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(
                        vertical: FuelTheme.gap,
                      ),
                      foregroundColor: FuelTheme.resolve(
                        context,
                        FuelTheme.ink,
                      ),
                      onPressed: () => onAppearanceChanged(option),
                      child: Row(
                        children: [
                          Expanded(child: Text(option.label)),
                          if (option == appearance)
                            ExcludeSemantics(
                              child: Icon(
                                CupertinoIcons.check_mark,
                                color: FuelTheme.resolve(
                                  context,
                                  FuelTheme.accent,
                                ),
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        FuelSurface(
          child: Padding(
            padding: const EdgeInsets.all(FuelTheme.inset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: const Text('Privacy', style: FuelTheme.heading),
                ),
                const SizedBox(height: FuelTheme.gap),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Hide fuel log station addresses'),
                    ),
                    const SizedBox(width: FuelTheme.gap),
                    Semantics(
                      label: 'Hide fuel log station addresses',
                      child: CupertinoSwitch(
                        value: hideStationAddresses,
                        onChanged: onHideStationAddressesChanged,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        FuelSurface(
          child: CupertinoButton(
            onPressed: () => _configureClaude(context),
            child: const Text('Claude Vision API key'),
          ),
        ),
        if (Platform.isIOS) _BackupControls(store: store),
      ],
    );
  }
}

class _BackupControls extends StatefulWidget {
  const _BackupControls({required this.store});

  final FuelStore store;

  @override
  State<_BackupControls> createState() => _BackupControlsState();
}

class _BackupControlsState extends State<_BackupControls> {
  static const _channel = MethodChannel('fueliq/backup');
  bool _busy = false;

  Future<void> _export() async {
    final cache = await getTemporaryDirectory();
    final directory = await cache.createTemp('fueliq-backup-');
    try {
      final date = DateTime.now().toIso8601String().substring(0, 10);
      final file = File('${directory.path}/FuelIQ-backup-$date.json');
      await widget.store.writeBackup(file);
      if (!mounted) return;
      await _channel.invokeMethod<bool>('export', file.path);
    } finally {
      try {
        await directory.delete(recursive: true);
      } on FileSystemException {
        // iOS can purge the temporary copy.
      }
    }
  }

  Future<void> _restore() async {
    final path = await _channel.invokeMethod<String>('import');
    if (path == null || !mounted) return;
    final backup = await widget.store.readBackup(File(path));
    if (!mounted) return;
    final current = widget.store.data;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialog) => CupertinoAlertDialog(
        title: const Text('Restore this backup?'),
        content: Text(
          'This backup contains ${backup.fillUps.length} fill-ups and '
          '${backup.vehicles.length} vehicles. Restoring replaces the '
          'current fill-ups, Garage, and app preferences.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction:
                current.fillUps.isNotEmpty || current.vehicles.isNotEmpty,
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.store.restoreBackup(backup, current: current);
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialog) => CupertinoAlertDialog(
        title: const Text('Backup restored'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _run({required bool restoring}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await (restoring ? _restore() : _export());
    } catch (_) {
      if (mounted) {
        await showRecordError(
          context,
          restoring
              ? 'Could not restore the backup. Choose a valid FuelIQ backup and try again.'
              : 'Could not export the backup. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FuelSurface(
    child: Padding(
      padding: const EdgeInsets.all(FuelTheme.inset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: const Text('Backup', style: FuelTheme.heading),
          ),
          const SizedBox(height: FuelTheme.gap),
          const Text(
            'Save a copy of your fill-ups and Garage in iCloud Drive to restore after reinstalling.',
          ),
          CupertinoButton(
            onPressed: _busy ? null : () => _run(restoring: false),
            child: const Text('Export backup'),
          ),
          CupertinoButton(
            onPressed: _busy ? null : () => _run(restoring: true),
            child: const Text('Restore backup'),
          ),
        ],
      ),
    ),
  );
}
