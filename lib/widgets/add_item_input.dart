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
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: itemController,
            onChanged: onChanged,
            onSubmitted: (_) => onSubmit(),
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Add an item',
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 108,
          child: TextField(
            controller: quantityController,
            onSubmitted: (_) => onSubmit(),
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Qty',
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: onSubmit,
          icon: const Icon(Icons.add),
          tooltip: 'Add item',
        ),
      ],
    );
  }
}
