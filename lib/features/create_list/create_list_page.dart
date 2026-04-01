import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../models/food_suggestion.dart';
import '../../models/shopping_list.dart';
import '../../models/shopping_list_item.dart';
import '../../models/shopping_list_template.dart';
import '../../services/suggestion_service.dart';
import '../../widgets/add_item_input.dart';
import '../../widgets/autocomplete_dropdown.dart';
import '../../widgets/date_selector_field.dart';
import '../../widgets/edit_item_dialog.dart';
import '../../widgets/shopping_list_item_tile.dart';

class CreateListPage extends StatefulWidget {
  final Future<void> Function(String name, List<ShoppingListItem> items)?
      onSaveTemplate;
  final List<ShoppingListItem>? initialItems;
  final List<ShoppingListTemplate> existingTemplates;

  const CreateListPage({
    super.key,
    this.onSaveTemplate,
    this.initialItems,
    this.existingTemplates = const [],
  });

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
  late final Set<String> _templateSignatures;

  @override
  void initState() {
    super.initState();
    _templateSignatures = widget.existingTemplates
        .map((template) => _signatureFromTemplateItems(template.items))
        .toSet();
    if (widget.initialItems != null) {
      _items.addAll(
        widget.initialItems!
            .map(
              (item) => ShoppingListItem(
                id: item.id,
                name: item.name,
                quantity: item.quantity,
                isChecked: item.isChecked,
              ),
            )
            .toList(),
      );
      _idCounter = _items.length;
    }
  }

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

  String _signatureFromItems(List<ShoppingListItem> items) => items
      .map((item) => '${item.name.trim()}|${(item.quantity ?? '').trim()}')
      .join('||');

  String _signatureFromTemplateItems(List<ShoppingListTemplateItem> items) => items
      .map((item) => '${item.name.trim()}|${(item.quantity ?? '').trim()}')
      .join('||');

  bool get _canSaveTemplate =>
      _items.isNotEmpty && !_templateSignatures.contains(_signatureFromItems(_items));

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
      if (trimmedName.isEmpty) return;
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

  Future<void> _selectTemplate() async {
    if (widget.existingTemplates.isEmpty) return;
    final template = await showDialog<ShoppingListTemplate>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Templates'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: widget.existingTemplates
                .map(
                  (t) => ListTile(
                    title: Text(t.name),
                    subtitle: Text(
                      '${t.items.length} item${t.items.length == 1 ? '' : 's'}',
                    ),
                    onTap: () => Navigator.pop(context, t),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
    if (!mounted || template == null) return;
    setState(() {
      _items.clear();
      _idCounter = 0;
      _items.addAll(
        template.items
            .map(
              (item) => ShoppingListItem(
                id: _nextId(),
                name: item.name,
                quantity: item.quantity,
              ),
            )
            .toList(),
      );
    });
  }

  void _saveList() {
    final list = ShoppingList(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: _selectedDate,
      items: List.from(_items),
    );
    Navigator.pop(context, list);
  }

  Future<void> _saveAsTemplate() async {
    if (widget.onSaveTemplate == null || !_canSaveTemplate) {
      return;
    }
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save as template'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Template name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!mounted || name == null || name.isEmpty) {
      return;
    }
    await widget.onSaveTemplate!(name, List<ShoppingListItem>.from(_items));
    if (!mounted) {
      return;
    }
    setState(() {
      _templateSignatures.add(_signatureFromItems(_items));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          onTap: _dismissSuggestions,
          behavior: HitTestBehavior.translucent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: DateSelectorField(
                              selectedDate: _selectedDate,
                              onDateSelected: (date) =>
                                  setState(() => _selectedDate = date),
                            ),
                          ),
                          const SizedBox(height: 16),
                          AddItemInput(
                            itemController: _itemController,
                            quantityController: _quantityController,
                            onChanged: _onItemTextChanged,
                            onSubmit: _addFromText,
                            suggestions: _suggestions.isNotEmpty
                                ? AutocompleteDropdown(
                                    suggestions: _suggestions,
                                    onSelect: _addFromSuggestion,
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                    if (_items.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ..._items.asMap().entries.map(
                            (entry) => Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                              child: Dismissible(
                                key: ValueKey(entry.value.id),
                                background: Container(color: Colors.transparent),
                                secondaryBackground: Container(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.error,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.centerRight,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 20),
                                  child: Icon(
                                    Icons.delete,
                                    color: theme.colorScheme.onError,
                                  ),
                                ),
                                direction: DismissDirection.endToStart,
                                onDismissed: (_) => _deleteItem(entry.key),
                                child: GestureDetector(
                                  onLongPress: () => _editItem(entry.key),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ShoppingListItemTile(
                                      item: entry.value,
                                      onToggle: () => _toggleItem(entry.key),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: _canSaveTemplate ? _saveAsTemplate : null,
                    tooltip: 'Save as template',
                    icon: Icon(
                      LucideIcons.star,
                      color: _canSaveTemplate
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton.filled(
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: theme.colorScheme.surface,
                        foregroundColor: theme.colorScheme.onSurface,
                      ),
                      tooltip: 'Back',
                      icon: const Icon(LucideIcons.chevron_left, size: 22),
                    ),
                    if (widget.existingTemplates.isNotEmpty)
                      IconButton.filled(
                        onPressed: _selectTemplate,
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.surface,
                          foregroundColor: theme.colorScheme.onSurface,
                        ),
                        tooltip: 'Templates',
                        icon: Image.asset('images/templates.png', width: 48, height: 48),
                      ),
                    IconButton.filled(
                      onPressed: _saveList,
                      style: IconButton.styleFrom(
                        backgroundColor: theme.colorScheme.surface,
                        foregroundColor: theme.colorScheme.onSurface,
                      ),
                      tooltip: 'Save',
                      icon: const Icon(LucideIcons.check, size: 22),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
