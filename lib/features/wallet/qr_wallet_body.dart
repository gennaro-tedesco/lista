import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../models/stored_code.dart';

class QrWalletBody extends StatelessWidget {
  final List<StoredCode> codes;
  final void Function(StoredCode) onView;
  final void Function(StoredCode) onDelete;

  const QrWalletBody({
    super.key,
    required this.codes,
    required this.onView,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (codes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.wallet,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 16),
            Text(
              'No codes yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text('Tap + to add one', style: theme.textTheme.bodySmall),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: codes.length,
      itemBuilder: (context, index) => _CodeCard(
        code: codes[index],
        onTap: () => onView(codes[index]),
        onLongPress: () => onDelete(codes[index]),
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  final StoredCode code;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _CodeCard({
    required this.code,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = File(code.imagePath);
    return Card(
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: file.existsSync()
                    ? Image.file(
                        file,
                        fit: BoxFit.contain,
                        width: double.infinity,
                      )
                    : const Center(child: Icon(Icons.broken_image, size: 48)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                code.name,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
