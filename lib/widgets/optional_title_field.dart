import 'package:flutter/material.dart';

class OptionalTitleField extends StatelessWidget {
  final TextEditingController controller;

  const OptionalTitleField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(hintText: 'List title (optional)'),
    );
  }
}
