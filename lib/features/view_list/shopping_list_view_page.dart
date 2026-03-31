import 'package:flutter/material.dart';
import '../../models/food_suggestion.dart';
import '../../models/shopping_list.dart';
import '../../models/shopping_list_item.dart';
import '../../services/suggestion_service.dart';
import '../../widgets/add_item_input.dart';
import '../../widgets/autocomplete_dropdown.dart';
import '../../widgets/edit_item_dialog.dart';
import '../../widgets/shopping_list_item_tile.dart';

class ShoppingListViewPage extends StatefulWidget {
  final ShoppingList list;

  const ShoppingListViewPage({super.key, required this.list});

  @override
  State<ShoppingListViewPage> createState() => _ShoppingListViewPageState();
}

class _ShoppingListViewPageState extends State<ShoppingListViewPage> {
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _totalPriceController = TextEditingController();
  static const _currencyOptions = ['€', '\$', '£', '¥', 'CHF'];
  List<FoodSuggestion> _suggestions = [];
  int? _draggingItemIndex;
  int? _itemDropIndex;

  @override
  void initState() {
    super.initState();
    _totalPriceController.text = widget.list.totalPrice ?? '';
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

  void _reorderItems(int oldIndex, int newIndex) {
    setState(() {
      final item = widget.list.items.removeAt(oldIndex);
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      widget.list.items.insert(newIndex, item);
      _draggingItemIndex = null;
      _itemDropIndex = null;
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

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String get _currencySymbol => widget.list.currencySymbol;

  Widget _buildItemDropZone(int index) {
    final isActive = _itemDropIndex == index;
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        if (details.data == index) {
          return false;
        }
        setState(() {
          _itemDropIndex = index;
        });
        return true;
      },
      onLeave: (_) {
        if (_itemDropIndex == index) {
          setState(() {
            _itemDropIndex = null;
          });
        }
      },
      onAcceptWithDetails: (details) {
        _reorderItems(details.data, index);
      },
      builder: (context, candidateData, rejectedData) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: isActive ? 20 : 8,
      ),
    );
  }

  Widget _buildListItemRow(BuildContext context, int index) {
    final theme = Theme.of(context);
    final item = widget.list.items[index];
    return Dismissible(
      key: ValueKey(item.id),
      background: Container(
        color: Colors.transparent,
      ),
      secondaryBackground: Container(
        color: theme.colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(
          Icons.delete,
          color: theme.colorScheme.onError,
        ),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteItem(index),
      child: GestureDetector(
        onLongPress: () => _editItem(index),
        child: ShoppingListItemTile(
          item: item,
          onToggle: () => _toggle(index),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = widget.list.items;
    final checked = items.where((i) => i.isChecked).length;

    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          onTap: _dismissSuggestions,
          behavior: HitTestBehavior.translucent,
          child: items.isEmpty
              ? ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                            onPressed: () => Navigator.pop(context),
                            color: theme.colorScheme.onSurface,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDate(widget.list.date),
                            style: theme.textTheme.bodySmall,
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
                          ),
                          if (_suggestions.isNotEmpty)
                            AutocompleteDropdown(
                              suggestions: _suggestions,
                              onSelect: _addFromSuggestion,
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
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
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _totalPriceController,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Total price',
                              ),
                              onChanged: _updateTotalPrice,
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: _currencySymbol,
                            onChanged: _updateCurrency,
                            items: _currencyOptions
                                .map(
                                  (currency) => DropdownMenuItem<String>(
                                    value: currency,
                                    child: Text(currency),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: () => _markCompleted(!widget.list.isCompleted),
                            child: Text(
                              widget.list.isCompleted ? 'Re-open' : 'Complete',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                            onPressed: () => Navigator.pop(context),
                            color: theme.colorScheme.onSurface,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDate(widget.list.date),
                            style: theme.textTheme.bodySmall,
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
                          ),
                          if (_suggestions.isNotEmpty)
                            AutocompleteDropdown(
                              suggestions: _suggestions,
                              onSelect: _addFromSuggestion,
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    for (var i = 0; i < items.length; i++) ...[
                      _buildItemDropZone(i),
                      LongPressDraggable<int>(
                        data: i,
                        onDragStarted: () {
                          setState(() {
                            _draggingItemIndex = i;
                          });
                        },
                        onDragEnd: (_) {
                          setState(() {
                            _draggingItemIndex = null;
                            _itemDropIndex = null;
                          });
                        },
                        feedback: Material(
                          color: Colors.transparent,
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width,
                            child: ShoppingListItemTile(
                              item: items[i],
                              onToggle: () {},
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.2,
                          child: _buildListItemRow(context, i),
                        ),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 120),
                          opacity: _draggingItemIndex == i ? 0.9 : 1,
                          child: _buildListItemRow(context, i),
                        ),
                      ),
                    ],
                    _buildItemDropZone(items.length),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _totalPriceController,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Total price',
                              ),
                              onChanged: _updateTotalPrice,
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: _currencySymbol,
                            onChanged: _updateCurrency,
                            items: _currencyOptions
                                .map(
                                  (currency) => DropdownMenuItem<String>(
                                    value: currency,
                                    child: Text(currency),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: () => _markCompleted(!widget.list.isCompleted),
                            child: Text(
                              widget.list.isCompleted ? 'Re-open' : 'Complete',
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
