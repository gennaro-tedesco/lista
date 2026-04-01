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

class ShoppingListViewPage extends StatefulWidget {
  final ShoppingList list;
  final Future<void> Function(String name, List<ShoppingListItem> items)?
      onSaveTemplate;
  final List<ShoppingListTemplate> existingTemplates;

  const ShoppingListViewPage({
    super.key,
    required this.list,
    this.onSaveTemplate,
    this.existingTemplates = const [],
  });

  @override
  State<ShoppingListViewPage> createState() => _ShoppingListViewPageState();
}

class _ShoppingListViewPageState extends State<ShoppingListViewPage> {
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _totalPriceController = TextEditingController();
  static const _currencyOptions = ['€', '\$', '£', '¥', 'CHF'];
  List<FoodSuggestion> _suggestions = [];
  late final Set<String> _templateSignatures;

  @override
  void initState() {
    super.initState();
    _totalPriceController.text = widget.list.totalPrice ?? '';
    _templateSignatures = widget.existingTemplates
        .map((template) => _signatureFromTemplateItems(template.items))
        .toSet();
  }

  @override
  void dispose() {
    _itemController.dispose();
    _quantityController.dispose();
    _totalPriceController.dispose();
    super.dispose();
  }

  String _nextId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  String _signatureFromItems(List<ShoppingListItem> items) => items
      .map((item) => '${item.name.trim()}|${(item.quantity ?? '').trim()}')
      .join('||');

  String _signatureFromTemplateItems(List<ShoppingListTemplateItem> items) => items
      .map((item) => '${item.name.trim()}|${(item.quantity ?? '').trim()}')
      .join('||');

  bool get _canSaveTemplate =>
      widget.list.items.isNotEmpty &&
      !_templateSignatures.contains(_signatureFromItems(widget.list.items));

  void _onItemTextChanged(String value) {
    setState(() {
      _suggestions = SuggestionService.getSuggestions(value);
    });
  }

  void _addFromSuggestion(FoodSuggestion suggestion) {
    setState(() {
      widget.list.items.add(
        ShoppingListItem(
          id: _nextId(),
          name: suggestion.name,
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

  void _addFromText() {
    final text = _itemController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      widget.list.items.add(
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

  void _toggle(int index) {
    setState(() {
      widget.list.items[index].isChecked = !widget.list.items[index].isChecked;
    });
  }

  void _deleteItem(int index) {
    setState(() {
      widget.list.items.removeAt(index);
    });
  }

  void _dismissSuggestions() {
    setState(() => _suggestions = []);
  }

  void _updateTotalPrice(String value) {
    widget.list.totalPrice = value.trim().isEmpty ? null : value.trim();
  }

  void _updateCurrency(String? value) {
    if (value == null) {
      return;
    }
    setState(() {
      widget.list.currencySymbol = value;
    });
  }

  void _markCompleted(bool value) {
    setState(() {
      widget.list.isCompleted = value;
      _updateTotalPrice(_totalPriceController.text);
    });
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _editItem(int index) async {
    final item = widget.list.items[index];
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
        widget.list.items[index] = ShoppingListItem(
          id: item.id,
          name: trimmedName,
          quantity: result.quantity.trim().isEmpty ? null : result.quantity.trim(),
          isChecked: item.isChecked,
        );
      });
    }
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
    await widget.onSaveTemplate!(
      name,
      List<ShoppingListItem>.from(widget.list.items),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _templateSignatures.add(_signatureFromItems(widget.list.items));
    });
  }

  String get _currencySymbol => widget.list.currencySymbol;

  Widget _buildListItemRow(BuildContext context, int index) {
    final theme = Theme.of(context);
    final item = widget.list.items[index];
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
      onDismissed: (_) => _deleteItem(index),
      child: GestureDetector(
        onLongPress: () => _editItem(index),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ShoppingListItemTile(
            item: item,
            onToggle: () => _toggle(index),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = widget.list.items;
    final checked = items.where((i) => i.isChecked).length;

    final fillColor = theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;

    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          onTap: _dismissSuggestions,
          behavior: HitTestBehavior.translucent,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: DateSelectorField(
                              selectedDate: widget.list.date,
                              onDateSelected: (date) =>
                                  setState(() => widget.list.date = date),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$checked of ${items.length} item${items.length == 1 ? '' : 's'} checked',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: checked == items.length && items.isNotEmpty
                                  ? theme.colorScheme.primary
                                  : null,
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
                    const SizedBox(height: 8),
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Text(
                            'No items in this list',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    else
                      for (var i = 0; i < items.length; i++)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                          child: _buildListItemRow(context, i),
                        ),
                    const SizedBox(height: 8),
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _totalPriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Total price',
                          filled: true,
                          fillColor: fillColor,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: BorderSide(
                              color: theme.colorScheme.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                        onChanged: _updateTotalPrice,
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownMenu<String>(
                      initialSelection: _currencySymbol,
                      onSelected: _updateCurrency,
                      width: 96,
                      inputDecorationTheme: InputDecorationTheme(
                        filled: true,
                        fillColor: fillColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      dropdownMenuEntries: _currencyOptions
                          .map((c) => DropdownMenuEntry<String>(
                                value: c,
                                label: c,
                              ))
                          .toList(),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () => _markCompleted(!widget.list.isCompleted),
                      style: IconButton.styleFrom(
                        backgroundColor: theme.colorScheme.surface,
                        foregroundColor: theme.colorScheme.onSurface,
                      ),
                      tooltip: widget.list.isCompleted ? 'Re-open' : 'Complete',
                      icon: Icon(
                        widget.list.isCompleted
                            ? LucideIcons.rotate_ccw
                            : LucideIcons.circle_check,
                        size: 22,
                      ),
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
