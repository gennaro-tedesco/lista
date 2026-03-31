import 'package:flutter/material.dart';
import '../../models/food_suggestion.dart';
import '../../models/shopping_list.dart';
import '../../models/shopping_list_item.dart';
import '../../services/suggestion_service.dart';
import '../../widgets/add_item_input.dart';
import '../../widgets/autocomplete_dropdown.dart';
import '../../widgets/date_selector_field.dart';
import '../../widgets/optional_title_field.dart';
import '../../widgets/shopping_list_item_tile.dart';

class CreateListPage extends StatefulWidget {
  const CreateListPage({super.key});

  @override
  State<CreateListPage> createState() => _CreateListPageState();
}

class _CreateListPageState extends State<CreateListPage> {
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _itemController = TextEditingController();
  final List<ShoppingListItem> _items = [];
  List<FoodSuggestion> _suggestions = [];
  int _idCounter = 0;

  @override
  void dispose() {
    _titleController.dispose();
    _itemController.dispose();
    super.dispose();
  }

  String _nextId() {
    _idCounter++;
    return _idCounter.toString();
  }

  void _onItemTextChanged(String value) {
    setState(() {
      _suggestions = SuggestionService.getSuggestions(value);
    });
  }

  void _addFromSuggestion(FoodSuggestion suggestion) {
    setState(() {
      _items.add(ShoppingListItem(
        id: _nextId(),
        name: suggestion.name,
        emoji: suggestion.emoji,
      ));
      _suggestions = [];
    });
    _itemController.clear();
  }

  void _addFromText() {
    final text = _itemController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _items.add(ShoppingListItem(id: _nextId(), name: text));
      _suggestions = [];
    });
    _itemController.clear();
  }

  void _toggleItem(int index) {
    setState(() {
      _items[index].isChecked = !_items[index].isChecked;
    });
  }

  void _dismissSuggestions() {
    setState(() => _suggestions = []);
  }

  void _saveList() {
    final title = _titleController.text.trim();
    final list = ShoppingList(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: _selectedDate,
      title: title.isEmpty ? null : title,
      items: List.from(_items),
    );
    Navigator.pop(context, list);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New List'),
        actions: [
          TextButton(
            onPressed: _saveList,
            child: const Text('Save'),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: _dismissSuggestions,
        behavior: HitTestBehavior.translucent,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DateSelectorField(
              selectedDate: _selectedDate,
              onDateSelected: (date) => setState(() => _selectedDate = date),
            ),
            const SizedBox(height: 12),
            OptionalTitleField(controller: _titleController),
            const SizedBox(height: 16),
            AddItemInput(
              controller: _itemController,
              onChanged: _onItemTextChanged,
              onSubmit: _addFromText,
            ),
            if (_suggestions.isNotEmpty)
              AutocompleteDropdown(
                suggestions: _suggestions,
                onSelect: _addFromSuggestion,
                onDismiss: _dismissSuggestions,
              ),
            if (_items.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(),
              ..._items.asMap().entries.map(
                    (entry) => ShoppingListItemTile(
                      item: entry.value,
                      onToggle: () => _toggleItem(entry.key),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}
