import 'package:flutter/material.dart';
import '../../models/food_suggestion.dart';
import '../../models/shopping_list.dart';
import '../../models/shopping_list_item.dart';
import '../../services/suggestion_service.dart';
import '../../widgets/add_item_input.dart';
import '../../widgets/autocomplete_dropdown.dart';
import '../../widgets/date_selector_field.dart';
import '../../widgets/edit_item_dialog.dart';
import '../../widgets/shopping_list_item_tile.dart';

class CreateListPage extends StatefulWidget {
  const CreateListPage({super.key});

  @override
  State<CreateListPage> createState() => _CreateListPageState();
}

class _CreateListPageState extends State<CreateListPage> {
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final List<ShoppingListItem> _items = [];
  List<FoodSuggestion> _suggestions = [];
  int _idCounter = 0;

  @override
  void dispose() {
    _itemController.dispose();
    _quantityController.dispose();
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
        quantity: _quantityController.text.trim().isEmpty
            ? null
            : _quantityController.text.trim(),
      ));
      _suggestions = [];
    });
    _itemController.clear();
    _quantityController.clear();
  }

  void _addFromText() {
    final text = _itemController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _items.add(
        ShoppingListItem(
          id: _nextId(),
          name: text,
          quantity: _quantityController.text.trim().isEmpty
              ? null
              : _quantityController.text.trim(),
        ),
      );
      _suggestions = [];
    });
    _itemController.clear();
    _quantityController.clear();
  }

  void _toggleItem(int index) {
    setState(() {
      _items[index].isChecked = !_items[index].isChecked;
    });
  }

  void _deleteItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _editItem(int index) async {
    final item = _items[index];
    final result = await showDialog<EditableItemData>(
      context: context,
      builder: (_) => EditItemDialog(
        initialName: item.name,
        initialQuantity: item.quantity ?? '',
      ),
    );
    if (result != null && mounted) {
      final trimmedName = result.name.trim();
      if (trimmedName.isEmpty) {
        return;
      }
      setState(() {
        _items[index] = ShoppingListItem(
          id: item.id,
          name: trimmedName,
          quantity: result.quantity.trim().isEmpty ? null : result.quantity.trim(),
          isChecked: item.isChecked,
        );
      });
    }
  }

  void _dismissSuggestions() {
    setState(() => _suggestions = []);
  }

  void _saveList() {
    final list = ShoppingList(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: _selectedDate,
      items: List.from(_items),
    );
    Navigator.pop(context, list);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          onTap: _dismissSuggestions,
          behavior: HitTestBehavior.translucent,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _saveList,
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
              DateSelectorField(
                selectedDate: _selectedDate,
                onDateSelected: (date) =>
                    setState(() => _selectedDate = date),
              ),
              const SizedBox(height: 16),
              AddItemInput(
                itemController: _itemController,
                quantityController: _quantityController,
                onChanged: _onItemTextChanged,
                onSubmit: _addFromText,
              ),
              if (_suggestions.isNotEmpty)
                AutocompleteDropdown(
                  suggestions: _suggestions,
                  onSelect: _addFromSuggestion,
                ),
              if (_items.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Divider(),
                ..._items.asMap().entries.map(
                      (entry) => Dismissible(
                        key: ValueKey(entry.value.id),
                        background: Container(
                          color: Colors.transparent,
                        ),
                        secondaryBackground: Container(
                          color: Theme.of(context).colorScheme.error,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Icon(
                            Icons.delete,
                            color: Theme.of(context).colorScheme.onError,
                          ),
                        ),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _deleteItem(entry.key),
                        child: GestureDetector(
                          onLongPress: () => _editItem(entry.key),
                          child: ShoppingListItemTile(
                            item: entry.value,
                            onToggle: () => _toggleItem(entry.key),
                          ),
                        ),
                      ),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
