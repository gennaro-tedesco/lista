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
  })  : labels = labels ?? [],
        items = items ?? [];
}
