class ShoppingListItem {
  final String id;
  final String name;
  final String? emoji;
  bool isChecked;

  ShoppingListItem({
    required this.id,
    required this.name,
    this.emoji,
    this.isChecked = false,
  });
}
