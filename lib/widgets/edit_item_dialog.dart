import 'package:flutter/material.dart';

class EditableItemData {
  final String name;
  final String quantity;

  const EditableItemData({
    required this.name,
    required this.quantity,
  });
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
    return AlertDialog(
      title: const Text('Edit item'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Item name',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _quantityController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Qty',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            EditableItemData(
              name: _nameController.text,
              quantity: _quantityController.text,
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
