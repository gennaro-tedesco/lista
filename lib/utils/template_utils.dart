import '../models/shopping_list_item.dart';
import '../models/shopping_list_template.dart';

String signatureFromItems(List<ShoppingListItem> items) => items
    .map((item) => '${item.name.trim()}|${(item.quantity ?? '').trim()}')
    .join('||');

String signatureFromTemplateItems(List<ShoppingListTemplateItem> items) => items
    .map((item) => '${item.name.trim()}|${(item.quantity ?? '').trim()}')
    .join('||');
