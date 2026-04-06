import 'package:flutter/material.dart';
import '../models/shopping_list_item.dart';

class ShoppingListItemTile extends StatelessWidget {
  final ShoppingListItem item;
  final VoidCallback onToggle;
  final VoidCallback? onNameTap;
  final Widget? leading;
  final Widget? trailing;

  const ShoppingListItemTile({
    super.key,
    required this.item,
    required this.onToggle,
    this.onNameTap,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dimColor = theme.colorScheme.onSurface.withValues(alpha: 0.35);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.isChecked
                    ? theme.colorScheme.primary
                    : Colors.transparent,
                border: Border.all(
                  color: item.isChecked
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                  width: 2,
                ),
              ),
              child: item.isChecked
                  ? Icon(
                      Icons.check,
                      size: 14,
                      color: theme.colorScheme.onPrimary,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onNameTap,
              child: Text(
                item.name,
                style: item.isChecked
                    ? theme.textTheme.bodyLarge?.copyWith(
                        decoration: TextDecoration.lineThrough,
                        decorationColor: dimColor,
                        color: dimColor,
                      )
                    : theme.textTheme.bodyLarge,
              ),
            ),
          ),
          if (item.quantity != null && item.quantity!.isNotEmpty) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: item.isChecked
                    ? theme.colorScheme.outline.withValues(alpha: 0.15)
                    : theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                item.quantity!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: item.isChecked ? dimColor : theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (trailing != null) ...[const SizedBox(width: 4), trailing!],
        ],
      ),
    );
  }
}
