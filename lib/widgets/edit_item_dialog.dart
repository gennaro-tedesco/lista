import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'centered_popup_shell.dart';

class EditableItemData {
  final String name;
  final String quantity;

  const EditableItemData({required this.name, required this.quantity});
}

class EditItemDialog extends StatefulWidget {
  final String initialName;
  final String initialQuantity;

  const EditItemDialog({
    super.key,
    required this.initialName,
    required this.initialQuantity,
  });

  @override
  State<EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<EditItemDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;

  void _submit() {
    Navigator.pop(
      context,
      EditableItemData(
        name: _nameController.text,
        quantity: _quantityController.text,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _quantityController = TextEditingController(text: widget.initialQuantity);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;
    final hintColor =
        theme.inputDecorationTheme.hintStyle?.color ??
        theme.colorScheme.onSurfaceVariant;

    InputDecoration pill({Widget? icon}) => InputDecoration(
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

    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: CenteredPopupShell(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    autofocus: true,
                    onSubmitted: (_) => _submit(),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: pill(
                      icon: const Icon(LucideIcons.shopping_cart),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _quantityController,
                    onSubmitted: (_) => _submit(),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: pill(icon: const Icon(LucideIcons.scale)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton.filled(
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: fillColor,
                    foregroundColor: theme.colorScheme.onSurface,
                  ),
                  icon: const Icon(LucideIcons.chevron_left, size: 22),
                ),
                const Spacer(),
                IconButton.filled(
                  onPressed: _submit,
                  style: IconButton.styleFrom(
                    backgroundColor: fillColor,
                    foregroundColor: theme.colorScheme.onSurface,
                  ),
                  icon: const Icon(LucideIcons.check, size: 22),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
