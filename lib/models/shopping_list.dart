import 'shopping_list_item.dart';

class ShoppingList {
  final String id;
  DateTime date;
  String? title;
  List<ShoppingListItem> items;

  ShoppingList({
    required this.id,
    required this.date,
    this.title,
    List<ShoppingListItem>? items,
  }) : items = items ?? [];
}
