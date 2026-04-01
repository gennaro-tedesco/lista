import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../models/food_suggestion.dart';
import '../../models/shopping_list.dart';
import '../../models/shopping_list_item.dart';
import '../../services/suggestion_service.dart';
import '../../widgets/add_item_input.dart';
import '../../widgets/autocomplete_dropdown.dart';
import '../../widgets/date_selector_field.dart';
import '../../widgets/edit_item_dialog.dart';
import '../../widgets/shopping_list_item_tile.dart';

class ShoppingListViewPage extends StatefulWidget {
  final ShoppingList list;

  const ShoppingListViewPage({super.key, required this.list});

  @override
  State<ShoppingListViewPage> createState() => _ShoppingListViewPageState();
}

class _ShoppingListViewPageState extends State<ShoppingListViewPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _totalPriceController = TextEditingController();
  static const _currencyOptions = ['€', '\$', '£', '¥', 'CHF'];
  List<FoodSuggestion> _suggestions = [];
  final GlobalKey _menuIconKey = GlobalKey();
  late final AnimationController _menuRotation;

  @override
  void initState() {
    super.initState();
    _totalPriceController.text = widget.list.totalPrice ?? '';
    _menuRotation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _itemController.dispose();
    _quantityController.dispose();
    _totalPriceController.dispose();
    _menuRotation.dispose();
    super.dispose();
  }

  String _nextId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

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

  Future<void> _openMenu() async {
    final renderBox =
        _menuIconKey.currentContext!.findRenderObject() as RenderBox;
    final iconOffset = renderBox.localToGlobal(Offset.zero);
    final iconSize = renderBox.size;
    final screenSize = MediaQuery.of(context).size;
    _menuRotation.forward();
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        iconOffset.dx,
        iconOffset.dy + iconSize.height,
        screenSize.width - iconOffset.dx - iconSize.width,
        screenSize.height - iconOffset.dy - iconSize.height,
      ),
      items: [
        const PopupMenuItem(value: 'save', child: Text('Save')),
        const PopupMenuItem(value: 'save_template', child: Text('Save as template')),
        const PopupMenuItem(value: 'from_template', child: Text('From template')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'back', child: Text('Back')),
      ],
    );
    _menuRotation.reverse();
    if (!mounted) return;
    switch (result) {
      case 'save':
      case 'back':
        Navigator.pop(context);
        return;
      case 'save_template':
      case 'from_template':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Coming soon'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      case null:
        return;
    }
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
                      padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _openMenu,
                            child: RotationTransition(
                              turns: Tween(begin: 0.0, end: 0.5)
                                  .animate(_menuRotation),
                              child: Icon(
                                key: _menuIconKey,
                                LucideIcons.menu,
                                size: 20,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
