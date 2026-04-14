import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

class NoteSheet extends StatefulWidget {
  final String initialText;

  const NoteSheet({super.key, required this.initialText});

  @override
  State<NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<NoteSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Note', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: null,
            minLines: 5,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(hintText: 'Write a note…'),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.x),
              ),
              IconButton(
                onPressed: () =>
                    Navigator.pop(context, _controller.text.trim()),
                icon: const Icon(LucideIcons.check),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
