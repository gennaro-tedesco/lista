import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

InputDecoration _pillDecoration(
  BuildContext context, {
  Widget? icon,
}) {
  final theme = Theme.of(context);
  final fillColor =
      theme.inputDecorationTheme.fillColor ??
      theme.colorScheme.surfaceContainerHighest;
  final hintColor =
      theme.inputDecorationTheme.hintStyle?.color ??
      theme.colorScheme.onSurfaceVariant;

  return InputDecoration(
    hint: icon == null
        ? null
        : SizedBox(
            width: 18,
            height: 18,
            child: Align(
              alignment: Alignment.centerLeft,
              child: IconTheme(
                data: IconThemeData(color: hintColor, size: 18),
                child: icon,
              ),
            ),
          ),
    filled: true,
    fillColor: fillColor,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
      borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
    ),
  );
}

class AddItemInput extends StatelessWidget {
  final TextEditingController itemController;
  final TextEditingController quantityController;
  final FocusNode? itemFocusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final Widget? suggestions;
  final bool showActionButton;

  const AddItemInput({
    super.key,
    required this.itemController,
    required this.quantityController,
    this.itemFocusNode,
    required this.onChanged,
    required this.onSubmit,
    this.suggestions,
    this.showActionButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const quantityWidth = 100.0;
          final actionWidth = showActionButton ? 48.0 : 0.0;
          const gap = 8.0;
          final itemWidth = math.max(
            0.0,
            constraints.maxWidth -
                quantityWidth -
                actionWidth -
                (showActionButton ? gap * 2 : gap),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: itemController,
                      focusNode: itemFocusNode,
                      onChanged: onChanged,
                      onSubmitted: (_) => onSubmit(),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _pillDecoration(
                        context,
                        icon: const Icon(LucideIcons.shopping_cart),
                      ),
                    ),
                  ),
                  const SizedBox(width: gap),
                  SizedBox(
                    width: quantityWidth,
                    child: TextField(
                      controller: quantityController,
                      onSubmitted: (_) => onSubmit(),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _pillDecoration(
                        context,
                        icon: const Icon(LucideIcons.scale),
                      ),
                    ),
                  ),
                  if (showActionButton) ...[
                    const SizedBox(width: gap),
                    SizedBox(
                      width: actionWidth,
                      height: actionWidth,
                      child: IconButton.filled(
                        onPressed: onSubmit,
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.surface,
                          foregroundColor: theme.colorScheme.onSurface,
                        ),
                        icon: const Icon(Icons.add),
                        tooltip: 'Add item',
                      ),
                    ),
                  ],
                ],
              ),
              if (suggestions != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(width: itemWidth, child: suggestions),
                ),
            ],
          );
        },
      ),
    );
  }
}

class AddItemFields extends StatelessWidget {
  final TextEditingController itemController;
  final TextEditingController quantityController;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final Widget? suggestions;

  const AddItemFields({
    super.key,
    required this.itemController,
    required this.quantityController,
    required this.onChanged,
    required this.onSubmit,
    this.suggestions,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const quantityWidth = 100.0;
          const gap = 8.0;
          final itemWidth = math.max(0.0, constraints.maxWidth - quantityWidth - gap);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: itemController,
                      onChanged: onChanged,
                      onSubmitted: (_) => onSubmit(),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _pillDecoration(
                        context,
                        icon: const Icon(LucideIcons.shopping_cart),
                      ),
                    ),
                  ),
                  const SizedBox(width: gap),
                  SizedBox(
                    width: quantityWidth,
                    child: TextField(
                      controller: quantityController,
                      onSubmitted: (_) => onSubmit(),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _pillDecoration(
                        context,
                        icon: const Icon(LucideIcons.scale),
                      ),
                    ),
                  ),
                ],
              ),
              if (suggestions != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(width: itemWidth, child: suggestions),
                ),
            ],
          );
        },
      ),
    );
  }
}
