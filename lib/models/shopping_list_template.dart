class ShoppingListTemplateItem {
  final String name;
  final String? quantity;
  final String? category;

  ShoppingListTemplateItem({required this.name, this.quantity, this.category});

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'category': category,
  };

  factory ShoppingListTemplateItem.fromJson(Map<String, dynamic> json) =>
      ShoppingListTemplateItem(
        name: json['name'] as String,
        quantity: json['quantity'] as String?,
        category: json['category'] as String?,
      );
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'items': items.map((i) => i.toJson()).toList(),
  };

  factory ShoppingListTemplate.fromJson(Map<String, dynamic> json) =>
      ShoppingListTemplate(
        id: json['id'] as String,
        name: json['name'] as String,
        items:
            (json['items'] as List<dynamic>?)
                ?.map(
                  (i) => ShoppingListTemplateItem.fromJson(
                    i as Map<String, dynamic>,
                  ),
                )
                .toList() ??
            [],
      );
}
