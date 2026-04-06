import '../models/shopping_list.dart';
import '../models/shopping_list_template.dart';
import '../models/stored_code.dart';

abstract interface class ListRepository {
  Future<List<ShoppingList>> getLists();
  Future<List<ShoppingListTemplate>> getTemplates();
  Future<List<String>> getLabels();
  Future<List<StoredCode>> getCodes();
  Future<void> saveList(ShoppingList list);
  Future<void> deleteList(String id);
  Future<void> saveTemplate(ShoppingListTemplate template);
  Future<void> deleteTemplate(String id);
  Future<void> saveLabels(List<String> labels);
  Future<void> saveCode(StoredCode code);
  Future<void> deleteCode(String id);
}

late final ListRepository listRepository;
