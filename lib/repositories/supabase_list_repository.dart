import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/shopping_list.dart';
import '../models/shopping_list_item.dart';
import '../models/shopping_list_template.dart';
import '../models/stored_code.dart';
import '../models/user_profile.dart';
import 'list_repository.dart';
import 'local_list_repository.dart';

const _uuid = Uuid();

class SupabaseListRepository implements ListRepository {
  final SupabaseClient _client;
  final LocalListRepository _local;

  SupabaseListRepository._(this._client, this._local);

  static Future<SupabaseListRepository> create() async {
    final local = LocalListRepository();
    await local.init();
    return SupabaseListRepository._(Supabase.instance.client, local);
  }

  ShoppingList _listFromRow(Map<String, dynamic> row) {
    final items = (row['shopping_list_items'] as List<dynamic>? ?? [])
        .map(
          (i) => ShoppingListItem(
            id: i['id'] as String,
            name: i['name'] as String,
            quantity: i['quantity'] as String?,
            isChecked: i['is_checked'] as bool? ?? false,
            category: i['category'] as String?,
          ),
        )
        .toList();
    return ShoppingList(
      id: row['id'] as String,
      date: DateTime.parse(row['date'] as String),
      labels: (row['labels'] as List<dynamic>?)?.cast<String>() ?? [],
      isCompleted: row['is_completed'] as bool? ?? false,
      totalPrice: row['total_price'] as String?,
      currencySymbol: row['currency_symbol'] as String? ?? '€',
      items: items,
    );
  }

  ShoppingListTemplate _templateFromRow(Map<String, dynamic> row) {
    final items = (row['shopping_list_template_items'] as List<dynamic>? ?? [])
        .map(
          (i) => ShoppingListTemplateItem(
            name: i['name'] as String,
            quantity: i['quantity'] as String?,
            category: i['category'] as String?,
          ),
        )
        .toList();
    return ShoppingListTemplate(
      id: row['id'] as String,
      name: row['name'] as String,
      items: items,
    );
  }

  @override
  Future<List<ShoppingList>> getLists() async {
    final data = await _client
        .from('shopping_lists')
        .select('*, shopping_list_items(*)');
    return data.map(_listFromRow).toList();
  }

  @override
  Future<void> saveList(ShoppingList list) async {
    await _client.from('shopping_lists').upsert({
      'id': list.id,
      'owner_id': _client.auth.currentUser!.id,
      'date': list.date.toIso8601String(),
      'is_completed': list.isCompleted,
      'total_price': list.totalPrice,
      'currency_symbol': list.currencySymbol,
      'labels': list.labels,
    });
    await _client.from('shopping_list_items').delete().eq('list_id', list.id);
    if (list.items.isNotEmpty) {
      await _client
          .from('shopping_list_items')
          .insert(
            list.items
                .map(
                  (item) => {
                    'id': item.id,
                    'list_id': list.id,
                    'name': item.name,
                    'quantity': item.quantity,
                    'category': item.category,
                    'is_checked': item.isChecked,
                  },
                )
                .toList(),
          );
    }
  }

  @override
  Future<void> deleteList(String id) async {
    await _client.from('shopping_lists').delete().eq('id', id);
  }

  @override
  Future<List<ShoppingListTemplate>> getTemplates() async {
    final data = await _client
        .from('shopping_list_templates')
        .select('*, shopping_list_template_items(*)');
    return data.map(_templateFromRow).toList();
  }

  @override
  Future<void> saveTemplate(ShoppingListTemplate template) async {
    await _client.from('shopping_list_templates').upsert({
      'id': template.id,
      'owner_id': _client.auth.currentUser!.id,
      'name': template.name,
    });
    await _client
        .from('shopping_list_template_items')
        .delete()
        .eq('template_id', template.id);
    if (template.items.isNotEmpty) {
      await _client
          .from('shopping_list_template_items')
          .insert(
            template.items
                .map(
                  (item) => {
                    'id': _uuid.v4(),
                    'template_id': template.id,
                    'name': item.name,
                    'quantity': item.quantity,
                    'category': item.category,
                  },
                )
                .toList(),
          );
    }
  }

  @override
  Future<void> deleteTemplate(String id) async {
    await _client.from('shopping_list_templates').delete().eq('id', id);
  }

  @override
  Future<List<String>> getLabels() async {
    final data = await _client
        .from('labels')
        .select('name')
        .order('sort_order');
    return data.map<String>((row) => row['name'] as String).toList();
  }

  @override
  Future<void> saveLabels(List<String> labels) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('labels').delete().eq('owner_id', userId);
    if (labels.isNotEmpty) {
      await _client
          .from('labels')
          .insert(
            labels
                .asMap()
                .entries
                .map(
                  (e) => {
                    'owner_id': userId,
                    'name': e.value,
                    'sort_order': e.key,
                  },
                )
                .toList(),
          );
    }
  }

  @override
  Future<List<StoredCode>> getCodes() => _local.getCodes();

  @override
  Future<void> saveCode(StoredCode code) => _local.saveCode(code);

  @override
  Future<void> deleteCode(String id) => _local.deleteCode(id);

  @override
  Future<List<UserProfile>> getUsers() async {
    final data = await _client
        .from('profiles')
        .select('id, email')
        .neq('id', _client.auth.currentUser!.id);
    return data
        .map(
          (row) => UserProfile(
            id: row['id'] as String,
            email: row['email'] as String,
          ),
        )
        .toList();
  }

  @override
  Future<void> shareList(String listId, String withUserId) async {
    await _client.from('list_shares').upsert({
      'list_id': listId,
      'shared_with_user_id': withUserId,
    });
  }

  @override
  Future<void> unshareList(String listId, String withUserId) async {
    await _client
        .from('list_shares')
        .delete()
        .eq('list_id', listId)
        .eq('shared_with_user_id', withUserId);
  }

  @override
  Future<void> shareTemplate(String templateId, String withUserId) async {
    await _client.from('template_shares').upsert({
      'template_id': templateId,
      'shared_with_user_id': withUserId,
    });
  }

  @override
  Future<void> unshareTemplate(String templateId, String withUserId) async {
    await _client
        .from('template_shares')
        .delete()
        .eq('template_id', templateId)
        .eq('shared_with_user_id', withUserId);
  }
}
