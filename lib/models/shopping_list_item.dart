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

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'isChecked': isChecked,
    'category': category,
  };

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) =>
      ShoppingListItem(
        id: json['id'] as String,
        name: json['name'] as String,
        quantity: json['quantity'] as String?,
        isChecked: json['isChecked'] as bool? ?? false,
        category: json['category'] as String?,
      );
}
