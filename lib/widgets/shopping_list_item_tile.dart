import 'package:flutter/material.dart';
import '../models/shopping_list_item.dart';

class ShoppingListItemTile extends StatelessWidget {
  final ShoppingListItem item;
  final VoidCallback onToggle;

  const ShoppingListItemTile({
    super.key,
    required this.item,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    return ListTile(
      leading: Checkbox(
        value: item.isChecked,
        onChanged: (_) => onToggle(),
      ),
      title: Text(
        item.name,
        style: item.isChecked
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                color: textColor.withValues(alpha: 0.4),
              )
            : null,
      ),
      trailing: item.quantity == null || item.quantity!.isEmpty
          ? null
          : Text(
              item.quantity!,
              style: item.isChecked
                  ? TextStyle(color: textColor.withValues(alpha: 0.4))
                  : null,
            ),
      onTap: onToggle,
    );
  }
}
