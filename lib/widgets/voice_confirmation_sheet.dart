import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../services/voice_service.dart';
import 'centered_popup_shell.dart';

enum ExtractionSource { voice, image }

class VoiceConfirmationSheet extends StatefulWidget {
  final List<ExtractedItem> items;
  final ExtractionSource source;

  const VoiceConfirmationSheet({
    super.key,
    required this.items,
    required this.source,
  });

  static Future<List<ExtractedItem>?> show(
    BuildContext context,
    List<ExtractedItem> items, {
    required ExtractionSource source,
  }) {
    return showGeneralDialog<List<ExtractedItem>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black38,
      pageBuilder: (dialogContext, _, _) {
        final maxHeight = MediaQuery.sizeOf(dialogContext).height * 0.7;
        return MediaQuery.removeViewInsets(
          context: dialogContext,
          removeLeft: true,
          removeTop: true,
          removeRight: true,
          removeBottom: true,
          child: GestureDetector(
            onTap: () => Navigator.pop(dialogContext),
            behavior: HitTestBehavior.opaque,
            child: Material(
              color: Colors.transparent,
              child: Center(
                child: GestureDetector(
                  onTap: () {},
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: CenteredPopupShell(
                        child: VoiceConfirmationSheet(
                          items: items,
                          source: source,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  State<VoiceConfirmationSheet> createState() => _VoiceConfirmationSheetState();
}

class _VoiceConfirmationSheetState extends State<VoiceConfirmationSheet> {
  late final List<ExtractedItem> _items;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              widget.source == ExtractionSource.voice
                  ? LucideIcons.mic
                  : LucideIcons.camera,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              widget.source == ExtractionSource.voice
                  ? 'Voice input'
                  : 'Image input',
              style: theme.textTheme.headlineSmall,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'No items recognised',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          Flexible(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _items.length,
                itemBuilder: (_, i) {
                  final item = _items[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                        if (item.quantityString != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              item.quantityString!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(
                            LucideIcons.x,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () => setState(() => _items.removeAt(i)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(LucideIcons.x, size: 20),
            ),
            IconButton(
              onPressed: _items.isEmpty
                  ? null
                  : () => Navigator.pop(
                      context,
                      List<ExtractedItem>.from(_items),
                    ),
              icon: Icon(LucideIcons.check, size: 20),
            ),
          ],
        ),
      ],
    );
  }
}
