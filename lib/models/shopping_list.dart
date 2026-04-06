import 'shopping_list_item.dart';

class ShoppingList {
  final String id;
  DateTime date;
  List<String> labels;
  bool isCompleted;
  String? totalPrice;
  String currencySymbol;
  List<ShoppingListItem> items;

  ShoppingList({
    required this.id,
    required this.date,
    List<String>? labels,
    this.isCompleted = false,
    this.totalPrice,
    this.currencySymbol = '€',
    List<ShoppingListItem>? items,
  }) : labels = labels ?? [],
       items = items ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'labels': labels,
    'isCompleted': isCompleted,
    'totalPrice': totalPrice,
    'currencySymbol': currencySymbol,
    'items': items.map((i) => i.toJson()).toList(),
  };

  factory ShoppingList.fromJson(Map<String, dynamic> json) => ShoppingList(
    id: json['id'] as String,
    date: DateTime.parse(json['date'] as String),
    labels: (json['labels'] as List<dynamic>?)?.cast<String>() ?? [],
    isCompleted: json['isCompleted'] as bool? ?? false,
    totalPrice: json['totalPrice'] as String?,
    currencySymbol: json['currencySymbol'] as String? ?? '€',
    items:
        (json['items'] as List<dynamic>?)
            ?.map((i) => ShoppingListItem.fromJson(i as Map<String, dynamic>))
            .toList() ??
        [],
  );
}
