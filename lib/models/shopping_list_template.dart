class ShoppingListTemplateItem {
  final String name;
  final String? quantity;

  ShoppingListTemplateItem({
    required this.name,
    this.quantity,
  });
}

class ShoppingListTemplate {
  final String id;
  final String name;
  final List<ShoppingListTemplateItem> items;

  ShoppingListTemplate({
    required this.id,
    required this.name,
    required this.items,
  });
}
