import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../app/ai_models.dart';
import '../../services/settings_service.dart';

const _providerModels = {
  AiProviderOption.google: [googleModel],
  AiProviderOption.mistral: [mistralTranscriptionModel, mistralExtractionModel],
  AiProviderOption.groq: [groqTranscriptionModel, groqExtractionModel, groqVisionModel],
};

class AiProviderPage extends StatelessWidget {
  const AiProviderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: providerNotifier,
      builder: (context, child) {
        final theme = Theme.of(context);
        final fillColor =
            theme.inputDecorationTheme.fillColor ??
            theme.colorScheme.surfaceContainerHighest;
        final selected = providerNotifier.value;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton.filled(
              onPressed: () => Navigator.pop(context),
              style: IconButton.styleFrom(
                backgroundColor: fillColor,
                foregroundColor: theme.colorScheme.onSurface,
              ),
              tooltip: 'Back',
              icon: const Icon(LucideIcons.chevron_left, size: 22),
            ),
            title: const Text('AI provider'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Provider', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      RadioGroup<AiProviderOption>(
                        groupValue: selected,
                        onChanged: (value) {
                          if (value != null) providerNotifier.value = value;
                        },
                        child: Column(
                          children: AiProviderOption.values
                              .map(
                                (option) => RadioListTile<AiProviderOption>(
                                  value: option,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(option.displayName),
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
                      Text('Models', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (_providerModels[selected] ?? [])
                            .map(
                              (model) => Chip(
                                label: Text(
                                  model,
                                  style: theme.textTheme.bodySmall,
                                ),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            )
                            .toList(),
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
