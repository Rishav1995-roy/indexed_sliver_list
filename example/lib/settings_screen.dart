import 'package:flutter/material.dart';

import 'settings.dart';

/// The "Customize" tab: alignment, estimate, separators, axis and theme.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings});
  final DemoSettings settings;

  static const List<Color> seeds = <Color>[
    Colors.indigo,
    Colors.teal,
    Colors.deepOrange,
    Colors.pink,
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (BuildContext context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text('Jump alignment: ${settings.alignment.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleMedium),
          const Text(
              '0.0 puts the target at the top, 0.5 centres it, 1.0 puts it at the bottom.'),
          Slider(
            value: settings.alignment,
            onChanged: (double v) => settings.alignment = v,
          ),
          SwitchListTile(
            title: const Text('Animate instead of jump'),
            value: settings.animate,
            onChanged: (bool v) => settings.animate = v,
          ),
          SwitchListTile(
            title: const Text('Separators between cards'),
            value: settings.separators,
            onChanged: (bool v) => settings.separators = v,
          ),
          SwitchListTile(
            title: const Text('Horizontal feed'),
            value: settings.horizontal,
            onChanged: (bool v) => settings.horizontal = v,
          ),
          const SizedBox(height: 8),
          Text('estimatedItemExtent: ${settings.estimate.round()}',
              style: Theme.of(context).textTheme.titleMedium),
          const Text('Height assumed for cards that were never laid out.'),
          Slider(
            min: 40,
            max: 400,
            value: settings.estimate,
            onChanged: (double v) => settings.estimate = v,
          ),
          const SizedBox(height: 8),
          Text('Theme color', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: <Widget>[
              for (final Color c in seeds)
                GestureDetector(
                  onTap: () => settings.seed = c,
                  child: CircleAvatar(
                    backgroundColor: c,
                    child: settings.seed == c
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
