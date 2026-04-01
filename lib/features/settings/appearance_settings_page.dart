import 'package:flutter/material.dart';
import '../../app/themes.dart';

class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([themeNotifier, uiFontScaleNotifier]),
      builder: (context, child) {
        final theme = Theme.of(context);
        return Scaffold(
          appBar: AppBar(title: const Text('Appearance')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Theme', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      RadioGroup<AppThemeOption>(
                        groupValue: themeNotifier.value,
                        onChanged: (value) {
                          if (value != null) {
                            themeNotifier.value = value;
                          }
                        },
                        child: Column(
                          children: AppThemeOption.values
                              .map(
                                (option) => RadioListTile<AppThemeOption>(
                                  value: option,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(option.label),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Font Size', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        '${(uiFontScaleNotifier.value * 100).round()}%',
                        style: theme.textTheme.bodySmall,
                      ),
                      Slider(
                        min: 0.85,
                        max: 1.35,
                        divisions: 10,
                        value: uiFontScaleNotifier.value,
                        onChanged: (value) {
                          uiFontScaleNotifier.value = value;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
