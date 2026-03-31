import 'shopping_list_item.dart';

class ShoppingList {
  final String id;
  DateTime date;
  String? title;
  bool isCompleted;
  String? totalPrice;
  String currencySymbol;
  List<ShoppingListItem> items;

  ShoppingList({
    required this.id,
    required this.date,
    this.title,
    this.isCompleted = false,
    this.totalPrice,
    this.currencySymbol = '€',
    List<ShoppingListItem>? items,
  }) : items = items ?? [];
}
