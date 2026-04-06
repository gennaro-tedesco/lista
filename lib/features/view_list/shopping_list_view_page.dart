import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:uuid/uuid.dart';
import '../../models/food_suggestion.dart';
import '../../models/shopping_list.dart';
import '../../models/shopping_list_item.dart';
import '../../models/shopping_list_template.dart';
import '../../services/suggestion_service.dart';
import '../../utils/category_utils.dart';
import '../../widgets/add_item_input.dart';
import '../../widgets/autocomplete_dropdown.dart';
import '../../widgets/date_selector_field.dart';
import '../../widgets/edit_item_dialog.dart';
import '../../widgets/shopping_list_item_tile.dart';

const _uuid = Uuid();

class _DraggedItem {
  final String id;

  const _DraggedItem(this.id);
}

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
  final ScrollController _scrollController = ScrollController();
  static const _currencyOptions = ['€', '\$', '£', '¥', 'CHF'];
  List<FoodSuggestion> _suggestions = [];
  late final Set<String> _templateSignatures;
  final Set<String> _collapsedCategories = {};
  bool _priceError = false;
  final Map<String, bool> _dropAfterByItemId = {};
  String? _previewAnchorItemId;
  bool? _previewPlaceAfter;

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
    _scrollController.dispose();
    super.dispose();
  }

  String _signatureFromItems(List<ShoppingListItem> items) => items
      .map((item) => '${item.name.trim()}|${(item.quantity ?? '').trim()}')
      .join('||');

  String _signatureFromTemplateItems(List<ShoppingListTemplateItem> items) =>
      items
          .map((item) => '${item.name.trim()}|${(item.quantity ?? '').trim()}')
          .join('||');

  bool get _canSaveTemplate =>
      widget.list.items.isNotEmpty &&
      !_templateSignatures.contains(_signatureFromItems(widget.list.items));

  bool get _hasCategories =>
      widget.list.items.any((item) => item.category != null);

  Map<String, List<ShoppingListItem>> get _groupedItems {
    final map = <String, List<ShoppingListItem>>{};
    for (final item in widget.list.items) {
      map.putIfAbsent(item.category ?? 'Other', () => []).add(item);
    }
    return Map.fromEntries(
      kCategoryOrder
          .where(map.containsKey)
          .map((cat) => MapEntry(cat, map[cat]!)),
    );
  }

  void _toggle(String id) {
    final item = widget.list.items.firstWhere((i) => i.id == id);
    setState(() => item.isChecked = !item.isChecked);
  }

  void _deleteItem(String id) {
    setState(() => widget.list.items.removeWhere((i) => i.id == id));
  }

  void _changeCategory(String id, String? newCategory) {
    setState(() {
      widget.list.items.firstWhere((i) => i.id == id).category = newCategory;
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

  void _dismissSuggestions() {
    setState(() => _suggestions = []);
  }

  void _onItemTextChanged(String value) {
    setState(() {
      _suggestions = [];
    });
  }

  void _addFromSuggestion(FoodSuggestion suggestion) {
    setState(() {
      widget.list.items.add(
        ShoppingListItem(
          id: _uuid.v4(),
          name: suggestion.name,
          quantity: _quantityController.text.trim().isEmpty
              ? null
              : _quantityController.text.trim(),
          category: suggestion.category,
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
          id: _uuid.v4(),
          name: text,
          quantity: _quantityController.text.trim().isEmpty
              ? null
              : _quantityController.text.trim(),
          category: SuggestionService.categoryFor(text),
        ),
      );
      _suggestions = [];
    });
    _itemController.clear();
    _quantityController.clear();
  }

  void _updateTotalPrice(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      widget.list.totalPrice = null;
      setState(() => _priceError = false);
      return;
    }
    final parsed = double.tryParse(trimmed.replaceAll(',', '.'));
    setState(() => _priceError = parsed == null);
    if (parsed != null) {
      widget.list.totalPrice = trimmed;
    }
  }

  void _updateCurrency(String? value) {
    if (value == null) return;
    setState(() => widget.list.currencySymbol = value);
  }

  void _markCompleted(bool value) {
    setState(() {
      widget.list.isCompleted = value;
      _updateTotalPrice(_totalPriceController.text);
    });
    if (mounted) Navigator.pop(context);
  }

  Future<void> _editItem(String id) async {
    final item = widget.list.items.firstWhere((i) => i.id == id);
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
        final idx = widget.list.items.indexWhere((i) => i.id == id);
        widget.list.items[idx] = ShoppingListItem(
          id: item.id,
          name: trimmedName,
          quantity: result.quantity.trim().isEmpty
              ? null
              : result.quantity.trim(),
          isChecked: item.isChecked,
          category: item.category,
        );
      });
    }
  }

  Future<void> _saveAsTemplate() async {
    if (widget.onSaveTemplate == null || !_canSaveTemplate) return;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save as template'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Template name'),
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
    if (!mounted || name == null || name.isEmpty) return;
    await widget.onSaveTemplate!(
      name,
      List<ShoppingListItem>.from(widget.list.items),
    );
    if (!mounted) return;
    setState(() {
      _templateSignatures.add(_signatureFromItems(widget.list.items));
    });
    _showTemplateSavedConfirmation(name);
  }

  Future<void> _showTemplateSavedConfirmation(String name) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Template saved',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (context, animation, secondaryAnimation) => const SizedBox(),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(
            opacity: animation,
            child: SafeArea(
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.14),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Text(
                      'Saved $name as template!',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ),
            ),
          ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (navigator.mounted && navigator.canPop()) {
      navigator.pop();
    }
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
              height: 30,
              child: Row(
                children: [
                  if ((item.category ?? 'Other') == cat)
                    Icon(
                      Icons.check,
                      size: 16,
                      color: theme.colorScheme.primary,
                    )
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

  void _moveItem(
    String itemId, {
    required String? targetCategory,
    required String anchorItemId,
    required bool placeAfter,
  }) {
    if (itemId == anchorItemId) return;
    setState(() {
      final items = widget.list.items;
      final sourceIndex = items.indexWhere((item) => item.id == itemId);
      final anchorIndexBeforeMove = items.indexWhere(
        (item) => item.id == anchorItemId,
      );
      if (sourceIndex == -1 || anchorIndexBeforeMove == -1) return;

      final movingItem = items.removeAt(sourceIndex);
      movingItem.category = targetCategory == 'Other' ? null : targetCategory;

      final anchorIndex = items.indexWhere((item) => item.id == anchorItemId);
      if (anchorIndex == -1) {
        items.add(movingItem);
        return;
      }

      final insertIndex = placeAfter ? anchorIndex + 1 : anchorIndex;
      items.insert(insertIndex, movingItem);
    });
  }

  void _updateDropPosition(BuildContext context, String anchorItemId, Offset offset) {
    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    final local = box.globalToLocal(offset);
    final placeAfter = local.dy > box.size.height / 2;
    if (_dropAfterByItemId[anchorItemId] == placeAfter &&
        _previewAnchorItemId == anchorItemId &&
        _previewPlaceAfter == placeAfter) {
      return;
    }
    setState(() {
      _dropAfterByItemId[anchorItemId] = placeAfter;
      _previewAnchorItemId = anchorItemId;
      _previewPlaceAfter = placeAfter;
    });
  }

  void _clearDropPosition(String anchorItemId) {
    if (!_dropAfterByItemId.containsKey(anchorItemId) &&
        _previewAnchorItemId != anchorItemId) {
      return;
    }
    setState(() {
      _dropAfterByItemId.remove(anchorItemId);
      if (_previewAnchorItemId == anchorItemId) {
        _previewAnchorItemId = null;
        _previewPlaceAfter = null;
      }
    });
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

  Widget _buildItemRow(
    BuildContext context,
    ShoppingListItem item, {
    required String category,
    bool withHandle = false,
  }) {
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
      child: DragTarget<_DraggedItem>(
        onWillAcceptWithDetails: (details) => details.data.id != item.id,
        onMove: (details) {
          _updateDropPosition(context, item.id, details.offset);
          _moveItem(
            details.data.id,
            targetCategory: category,
            anchorItemId: item.id,
            placeAfter: _dropAfterByItemId[item.id] ?? false,
          );
        },
        onLeave: (data) => _clearDropPosition(item.id),
        onAcceptWithDetails: (details) => _clearDropPosition(item.id),
        builder: (context, candidates, rejected) {
          final isActive = candidates.isNotEmpty;
          final placeAfter = _dropAfterByItemId[item.id] ?? false;
          final tile = AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: isActive
                  ? theme.colorScheme.primary.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border(
                top: placeAfter || !isActive
                    ? BorderSide.none
                    : BorderSide(
                        color: theme.colorScheme.primary.withValues(alpha: 0.7),
                        width: 2,
                      ),
                bottom: isActive && placeAfter
                    ? BorderSide(
                        color: theme.colorScheme.primary.withValues(alpha: 0.7),
                        width: 2,
                      )
                    : BorderSide.none,
              ),
            ),
            child: ShoppingListItemTile(
              item: item,
              onToggle: () => _toggle(item.id),
              onNameTap: () => _editItem(item.id),
              leading: withHandle ? _categoryPicker(context, item) : null,
            ),
          );

          return LongPressDraggable<_DraggedItem>(
            data: _DraggedItem(item.id),
            axis: Axis.vertical,
            onDragStarted: () => _dismissSuggestions(),
            onDragEnd: (_) {
              _clearDropPosition(item.id);
              _previewAnchorItemId = null;
              _previewPlaceAfter = null;
            },
            onDraggableCanceled: (velocity, offset) =>
                _clearDropPosition(item.id),
            feedback: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width - 40,
                ),
                child: Opacity(
                  opacity: 0.92,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.14),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ShoppingListItemTile(
                      item: item,
                      onToggle: () {},
                      onNameTap: () {},
                      leading: withHandle ? _categoryPicker(context, item) : null,
                    ),
                  ),
                ),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.35, child: tile),
            child: tile,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = widget.list.items;
    final checked = items.where((i) => i.isChecked).length;

    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;

    return Scaffold(
      body: GestureDetector(
        onTap: _dismissSuggestions,
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: ListView(
                    controller: _scrollController,
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
                            AddItemFields(
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
                      if (_hasCategories) ...[
                        for (final entry in _groupedItems.entries)
                          CategorySection(
                            category: entry.key,
                            items: entry.value,
                            isCollapsed: _collapsedCategories.contains(entry.key),
                            onToggleCollapse: () => _toggleCollapse(entry.key),
                            itemBuilder: (ctx, item) => _buildItemRow(
                              ctx,
                              item,
                              category: entry.key,
                              withHandle: true,
                            ),
                          ),
                        const SizedBox(height: 8),
                      ] else if (items.isEmpty)
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
                        for (final item in items)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                            child: _buildItemRow(
                              context,
                              item,
                              category: item.category ?? 'Other',
                            ),
                          ),
                      const SizedBox(height: 8),
                    ],
                  ),
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
                          errorText: _priceError ? '' : null,
                          errorStyle: const TextStyle(height: 0),
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
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: BorderSide(
                              color: theme.colorScheme.error,
                              width: 1.5,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: BorderSide(
                              color: theme.colorScheme.error,
                              width: 1.5,
                            ),
                          ),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        onChanged: _updateTotalPrice,
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownMenu<String>(
                      initialSelection: widget.list.currencySymbol,
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
                          .map((c) => DropdownMenuEntry<String>(value: c, label: c))
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
                            : LucideIcons.check,
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
