import 'package:flutter/material.dart';
import '../models/food_suggestion.dart';

class AutocompleteDropdown extends StatelessWidget {
  final List<FoodSuggestion> suggestions;
  final ValueChanged<FoodSuggestion> onSelect;

  const AutocompleteDropdown({
    super.key,
    required this.suggestions,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: suggestions.map((s) {
            return InkWell(
              onTap: () => onSelect(s),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 13,
                ),
                child: Text(s.name, style: theme.textTheme.bodyMedium),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
