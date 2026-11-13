import 'package:flutter/cupertino.dart';

import '../../design_system/fuel_page.dart';
import '../../design_system/fuel_theme.dart';
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
    required this.appearance,
    required this.onAppearanceChanged,
  });

  final Appearance appearance;
  final ValueChanged<Appearance> onAppearanceChanged;

  Future<void> _configureClaude(BuildContext context) async {
    final configured = await hasClaudeVisionKey();
    if (!context.mounted) return;
    var enteredKey = '';
    final key = await showCupertinoDialog<String>(
      context: context,
      builder: (dialog) => CupertinoAlertDialog(
        title: const Text('Claude Vision'),
        content: Column(
          children: [
            const Text(
              'With a key saved, Fuel Log sends selected photo images to Anthropic for paid Haiku scans. Capture metadata stays on your phone.',
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              onChanged: (value) => enteredKey = value,
              placeholder: 'Anthropic API key',
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
          child: CupertinoButton(
            onPressed: () => _configureClaude(context),
            child: const Text('Claude Vision API key'),
          ),
        ),
      ],
    );
  }
}
