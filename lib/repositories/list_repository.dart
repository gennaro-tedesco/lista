import 'package:flutter/foundation.dart';
import '../models/shopping_list.dart';
import '../models/shopping_list_template.dart';
import '../models/stored_code.dart';
import '../models/user_profile.dart';

abstract interface class ListRepository {
  Future<List<ShoppingList>> getLists();
  Future<ShoppingList?> getListById(String id);
  Future<List<ShoppingListTemplate>> getTemplates();
  Future<List<String>> getLabels();
  Future<List<StoredCode>> getCodes();
  Future<void> saveList(ShoppingList list);
  Future<void> deleteList(ShoppingList list);
  Future<void> saveTemplate(ShoppingListTemplate template);
  Future<void> deleteTemplate(String id);
  Future<void> saveLabels(List<String> labels);
  Future<void> saveCode(StoredCode code);
  Future<void> deleteCode(String id);
  Future<List<UserProfile>> getUsers();
  Future<bool> listHasShares(String listId);
  Future<List<String>> getListShares(String listId);
  Future<List<String>> getTemplateShares(String templateId);
  Future<void> shareList(String listId, String withUserId);
  Future<void> unshareList(String listId, String withUserId);
  Future<void> shareTemplate(String templateId, String withUserId);
  Future<void> unshareTemplate(String templateId, String withUserId);
}

late ListRepository listRepository;
final authStateNotifier = ValueNotifier<bool>(false);
