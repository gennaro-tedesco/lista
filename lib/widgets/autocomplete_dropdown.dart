import 'package:flutter/material.dart';
import '../models/food_suggestion.dart';

class AutocompleteDropdown extends StatelessWidget {
  final List<FoodSuggestion> suggestions;
  final ValueChanged<FoodSuggestion> onSelect;
  final VoidCallback onDismiss;

  const AutocompleteDropdown({
    super.key,
    required this.suggestions,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 4),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...suggestions.map(
            (s) => ListTile(
              dense: true,
              title: Text('${s.emoji}  ${s.name}'),
              onTap: () => onSelect(s),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onDismiss,
              child: const Text('Dismiss'),
            ),
          ),
        ],
      ),
    );
  }
}
