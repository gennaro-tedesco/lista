import 'package:flutter/material.dart';
import '../../models/shopping_list.dart';
import '../../widgets/shopping_list_item_tile.dart';

class ShoppingListViewPage extends StatefulWidget {
  final ShoppingList list;

  const ShoppingListViewPage({super.key, required this.list});

  @override
  State<ShoppingListViewPage> createState() => _ShoppingListViewPageState();
}

class _ShoppingListViewPageState extends State<ShoppingListViewPage> {
  void _toggle(int index) {
    setState(() {
      widget.list.items[index].isChecked = !widget.list.items[index].isChecked;
    });
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = widget.list.items;
    final checked = items.where((i) => i.isChecked).length;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    onPressed: () => Navigator.pop(context),
                    color: theme.colorScheme.onSurface,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(widget.list.date),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.list.title ?? 'Shopping List',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$checked of ${items.length} item${items.length == 1 ? '' : 's'} checked',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: checked == items.length && items.isNotEmpty
                          ? theme.colorScheme.primary
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    'No items in this list',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ...items.asMap().entries.map(
                    (entry) => ShoppingListItemTile(
                      item: entry.value,
                      onToggle: () => _toggle(entry.key),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
