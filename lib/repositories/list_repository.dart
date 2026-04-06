import '../models/shopping_list.dart';
import '../models/shopping_list_template.dart';

abstract interface class ListRepository {
  Future<List<ShoppingList>> getLists();
  Future<List<ShoppingListTemplate>> getTemplates();
  Future<List<String>> getLabels();
  Future<void> saveList(ShoppingList list);
  Future<void> deleteList(String id);
  Future<void> saveTemplate(ShoppingListTemplate template);
  Future<void> deleteTemplate(String id);
  Future<void> saveLabels(List<String> labels);
}

late final ListRepository listRepository;
