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
  final Set<String> _collapsedCategories = {};

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
                category: item.category,
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

  String _signatureFromTemplateItems(List<ShoppingListTemplateItem> items) =>
      items
          .map((item) => '${item.name.trim()}|${(item.quantity ?? '').trim()}')
          .join('||');

  bool get _canSaveTemplate =>
      _items.isNotEmpty &&
      !_templateSignatures.contains(_signatureFromItems(_items));

  bool get _hasCategories => _items.any((item) => item.category != null);

  Map<String, List<ShoppingListItem>> get _groupedItems {
    final map = <String, List<ShoppingListItem>>{};
    for (final item in _items) {
      map.putIfAbsent(item.category ?? 'Other', () => []).add(item);
    }
    return Map.fromEntries(
      kCategoryOrder
          .where(map.containsKey)
          .map((cat) => MapEntry(cat, map[cat]!)),
    );
  }

  void _toggleItem(String id) {
    final item = _items.firstWhere((i) => i.id == id);
    setState(() => item.isChecked = !item.isChecked);
  }

  void _deleteItem(String id) {
    setState(() => _items.removeWhere((i) => i.id == id));
  }

  Future<void> _editItem(String id) async {
    final item = _items.firstWhere((i) => i.id == id);
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
        final idx = _items.indexWhere((i) => i.id == id);
        _items[idx] = ShoppingListItem(
          id: item.id,
          name: trimmedName,
          quantity:
              result.quantity.trim().isEmpty ? null : result.quantity.trim(),
          isChecked: item.isChecked,
          category: item.category,
        );
      });
    }
  }

  void _changeCategory(String id, String? newCategory) {
    setState(() {
      _items.firstWhere((i) => i.id == id).category = newCategory;
    });
  }

  void _toggleCollapse(String category) {
    setState(() {
      if (_collapsedCategories.contains(category)) {
        _collapsedCategories.remove(category);
      } else {
        _collapsedCategories.add(category);
      }
    });
  }

  IconData _categoryIcon(String category) => switch (category) {
        'Fruit' => LucideIcons.apple,
        'Vegetable' => LucideIcons.carrot,
        'Drinks' => LucideIcons.glass_water,
        'Meat' => LucideIcons.beef,
        'Fish & Seafood' => LucideIcons.fish,
        'Dairy' => LucideIcons.milk,
        'Bakery' => LucideIcons.croissant,
        'Pantry' => LucideIcons.package,
        'Other' => LucideIcons.package,
        _ => LucideIcons.package,
      };

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
        category: suggestion.category,
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
      _collapsedCategories.clear();
      _items.addAll(
        template.items
            .map(
              (item) => ShoppingListItem(
                id: _nextId(),
                name: item.name,
                quantity: item.quantity,
                category: item.category,
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

  Future<void> _showCategoryMenu(
    BuildContext context,
    ShoppingListItem item,
    Offset tapPosition,
  ) async {
    final screenSize = MediaQuery.sizeOf(context);
    final theme = Theme.of(context);
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        tapPosition.dx,
        tapPosition.dy,
        screenSize.width - tapPosition.dx,
        screenSize.height - tapPosition.dy,
      ),
      items: kCategoryOrder
          .map(
            (cat) => PopupMenuItem<String>(
              value: cat,
              child: Row(
                children: [
                  if ((item.category ?? 'Other') == cat)
                    Icon(Icons.check, size: 16,
                        color: theme.colorScheme.primary)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  Text(cat),
                ],
              ),
            ),
          )
          .toList(),
    );
    if (!mounted || result == null) return;
    _changeCategory(item.id, result == 'Other' ? null : result);
  }

  Widget _categoryPicker(BuildContext context, ShoppingListItem item) {
    final theme = Theme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) =>
          _showCategoryMenu(context, item, details.globalPosition),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(
          Icons.keyboard_arrow_down,
          color: theme.colorScheme.outline.withValues(alpha: 0.5),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildItemRow(BuildContext context, ShoppingListItem item,
      {bool withHandle = false}) {
    final theme = Theme.of(context);
    return Dismissible(
      key: ValueKey(item.id),
      background: Container(color: Colors.transparent),
      secondaryBackground: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete, color: theme.colorScheme.onError),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteItem(item.id),
      child: GestureDetector(
        onLongPress: () => _editItem(item.id),
        child: ShoppingListItemTile(
          item: item,
          onToggle: () => _toggleItem(item.id),
          leading: withHandle ? _categoryPicker(context, item) : null,
        ),
      ),
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    String category,
    List<ShoppingListItem> items,
  ) {
    final theme = Theme.of(context);
    final checked = items.where((i) => i.isChecked).length;
    final total = items.length;
    final isCollapsed = _collapsedCategories.contains(category);
    final allDone = total > 0 && checked == total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: GestureDetector(
              onTap: () => _toggleCollapse(category),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      _categoryIcon(category),
                      size: 18,
                      color: allDone
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      category,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: allDone
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (total > 0)
                      if (allDone)
                        Row(
                          children: [
                            Icon(LucideIcons.circle_check,
                                size: 14, color: theme.colorScheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              '$checked/$total',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          '$checked/$total',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    const Spacer(),
                    Icon(
                      isCollapsed
                          ? LucideIcons.chevron_right
                          : LucideIcons.chevron_down,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!isCollapsed)
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                child: _buildItemRow(context, item, withHandle: true),
              ),
            ),
        ],
      ),
    );
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
                    if (_hasCategories) ...[
                      const SizedBox(height: 4),
                      for (final entry in _groupedItems.entries)
                        _buildCategorySection(
                            context, entry.key, entry.value),
                      const SizedBox(height: 8),
                    ] else if (_items.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ..._items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                          child: _buildItemRow(context, item),
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
                        icon: Image.asset('images/templates.png',
                            width: 48, height: 48),
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
