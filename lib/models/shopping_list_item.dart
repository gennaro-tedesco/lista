class ShoppingListItem {
  final String id;
  final String name;
  final String? quantity;
  bool isChecked;

  ShoppingListItem({
    required this.id,
    required this.name,
    this.quantity,
    this.isChecked = false,
  });
}
