import 'package:flutter/material.dart';

class AddItemInput extends StatelessWidget {
  final TextEditingController itemController;
  final TextEditingController quantityController;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  const AddItemInput({
    super.key,
    required this.itemController,
    required this.quantityController,
    required this.onChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fillColor = theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;

    InputDecoration pill(String hint) => InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: fillColor,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide:
                BorderSide(color: theme.colorScheme.primary, width: 1.5),
          ),
        );

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: itemController,
            onChanged: onChanged,
            onSubmitted: (_) => onSubmit(),
            textCapitalization: TextCapitalization.sentences,
            decoration: pill('Add an item'),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: TextField(
            controller: quantityController,
            onSubmitted: (_) => onSubmit(),
            textCapitalization: TextCapitalization.sentences,
            decoration: pill('Qty'),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: onSubmit,
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.surface,
            foregroundColor: theme.colorScheme.onSurface,
          ),
          icon: const Icon(Icons.add),
          tooltip: 'Add item',
        ),
      ],
    );
  }
}
