import 'package:flutter/material.dart';

class AddItemInput extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  const AddItemInput({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            onSubmitted: (_) => onSubmit(),
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Add an item',
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
