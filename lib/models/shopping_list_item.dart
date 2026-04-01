class ShoppingListItem {
  final String id;
  final String name;
  final String? quantity;
  bool isChecked;
  String? category;

  ShoppingListItem({
    required this.id,
    required this.name,
    this.quantity,
    this.isChecked = false,
    this.category,
  });
}
