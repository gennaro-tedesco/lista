import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../models/shopping_list_item.dart';

IconData categoryIcon(String category) => switch (category) {
  'Fruit' => LucideIcons.apple,
  'Vegetable' => LucideIcons.carrot,
  'Drinks' => LucideIcons.glass_water,
  'Meat' => LucideIcons.beef,
  'Fish & Seafood' => LucideIcons.fish,
  'Dairy' => LucideIcons.milk,
  'Bakery' => LucideIcons.croissant,
  _ => LucideIcons.package,
};

class CategorySection extends StatelessWidget {
  final String category;
  final List<ShoppingListItem> items;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;
  final Widget Function(BuildContext context, ShoppingListItem item)
  itemBuilder;

  const CategorySection({
    super.key,
    required this.category,
    required this.items,
    required this.isCollapsed,
    required this.onToggleCollapse,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checked = items.where((i) => i.isChecked).length;
    final total = items.length;
    final allDone = total > 0 && checked == total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: GestureDetector(
              onTap: onToggleCollapse,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      categoryIcon(category),
                      size: 18,
                      color: allDone
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      category,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: allDone
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (total > 0)
                      if (allDone)
                        Row(
                          children: [
                            Icon(
                              LucideIcons.circle_check,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$checked/$total',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          '$checked/$total',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    const Spacer(),
                    Icon(
                      isCollapsed
                          ? LucideIcons.chevron_right
                          : LucideIcons.chevron_down,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!isCollapsed)
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                child: itemBuilder(context, item),
              ),
            ),
        ],
      ),
    );
  }
}
