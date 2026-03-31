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
    return ListTile(
      leading: Checkbox(
        value: item.isChecked,
        onChanged: (_) => onToggle(),
      ),
      title: Text(
        item.emoji != null ? '${item.emoji}  ${item.name}' : item.name,
        style: item.isChecked
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              )
            : null,
      ),
      onTap: onToggle,
    );
  }
}
