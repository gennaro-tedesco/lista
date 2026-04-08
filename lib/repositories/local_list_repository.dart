import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/shopping_list.dart';
import '../models/shopping_list_template.dart';
import '../models/stored_code.dart';
import '../models/user_profile.dart';
import 'list_repository.dart';

class LocalListRepository implements ListRepository {
  late final File _file;
  List<ShoppingList> _lists = [];
  List<ShoppingListTemplate> _templates = [];
  List<String> _labels = [];
  List<StoredCode> _codes = [];

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/lista_data.json');
    if (!await _file.exists()) return;
    try {
      final json =
          jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
      _lists =
          (json['lists'] as List<dynamic>?)
              ?.map((e) => ShoppingList.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      _templates =
          (json['templates'] as List<dynamic>?)
              ?.map(
                (e) => ShoppingListTemplate.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [];
      _labels = (json['labels'] as List<dynamic>?)?.cast<String>() ?? [];
      _codes =
          (json['codes'] as List<dynamic>?)
              ?.map((e) => StoredCode.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
    } catch (_) {
      _lists = [];
      _templates = [];
      _labels = [];
      _codes = [];
    }
  }

  Future<void> _persist() => _file.writeAsString(
    jsonEncode({
      'lists': _lists.map((e) => e.toJson()).toList(),
      'templates': _templates.map((e) => e.toJson()).toList(),
      'labels': _labels,
      'codes': _codes.map((e) => e.toJson()).toList(),
    }),
  );

  @override
  Future<List<ShoppingList>> getLists() async => _lists;

  @override
  Future<List<ShoppingListTemplate>> getTemplates() async => _templates;

  @override
  Future<List<String>> getLabels() async => _labels;

  @override
  Future<List<StoredCode>> getCodes() async => _codes;

  @override
  Future<void> saveList(ShoppingList list) async {
    final idx = _lists.indexWhere((e) => e.id == list.id);
    if (idx == -1) {
      _lists.add(list);
    } else {
      _lists[idx] = list;
    }
    await _persist();
  }

  @override
  Future<void> deleteList(String id) async {
    _lists.removeWhere((e) => e.id == id);
    await _persist();
  }

  @override
  Future<void> saveTemplate(ShoppingListTemplate template) async {
    final idx = _templates.indexWhere((e) => e.id == template.id);
    if (idx == -1) {
      _templates.add(template);
    } else {
      _templates[idx] = template;
    }
    await _persist();
  }

  @override
  Future<void> deleteTemplate(String id) async {
    _templates.removeWhere((e) => e.id == id);
    await _persist();
  }

  @override
  Future<void> saveLabels(List<String> labels) async {
    _labels = List.from(labels);
    await _persist();
  }

  @override
  Future<void> saveCode(StoredCode code) async {
    final idx = _codes.indexWhere((e) => e.id == code.id);
    if (idx == -1) {
      _codes.add(code);
    } else {
      _codes[idx] = code;
    }
    await _persist();
  }

  @override
  Future<void> deleteCode(String id) async {
    _codes.removeWhere((e) => e.id == id);
    await _persist();
  }

  @override
  Future<List<UserProfile>> getUsers() async => [];

  @override
  Future<void> shareList(String listId, String withUserId) async {}

  @override
  Future<void> unshareList(String listId, String withUserId) async {}

  @override
  Future<void> shareTemplate(String templateId, String withUserId) async {}

  @override
  Future<void> unshareTemplate(String templateId, String withUserId) async {}
}

Future<LocalListRepository> createLocalListRepository() async {
  final repo = LocalListRepository();
  await repo.init();
  return repo;
}
