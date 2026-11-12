import 'package:flutter/cupertino.dart';

import '../../design_system/fuel_page.dart';
import '../../design_system/fuel_theme.dart';

enum Appearance {
  system('System', null),
  light('Light', Brightness.light),
  dark('Dark', Brightness.dark);

  const Appearance(this.label, this.brightness);

  final String label;
  final Brightness? brightness;
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.appearance,
    required this.onAppearanceChanged,
  });

  final Appearance appearance;
  final ValueChanged<Appearance> onAppearanceChanged;

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
                      foregroundColor: FuelTheme.ink,
                      onPressed: () => onAppearanceChanged(option),
                      child: Row(
                        children: [
                          Expanded(child: Text(option.label)),
                          if (option == appearance)
                            const ExcludeSemantics(
                              child: Icon(
                                CupertinoIcons.check_mark,
                                color: FuelTheme.accent,
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
      ],
    );
  }
}
