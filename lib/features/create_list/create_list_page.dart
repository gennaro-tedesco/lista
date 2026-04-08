import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:uuid/uuid.dart';
import '../../models/food_suggestion.dart';
import '../../models/shopping_list.dart';
import '../../models/shopping_list_item.dart';
import '../../models/shopping_list_template.dart';
import '../../repositories/list_repository.dart';
import '../../services/suggestion_service.dart';
import '../../utils/category_utils.dart';
import '../../utils/template_utils.dart';
import '../../widgets/action_tab_button.dart';
import '../../widgets/add_item_input.dart';
import '../../widgets/autocomplete_dropdown.dart';
import '../../widgets/centered_popup_shell.dart';
import '../../widgets/date_selector_field.dart';
import '../../widgets/edit_item_dialog.dart';
import '../../widgets/share_dialog.dart';
import '../../widgets/shopping_list_item_tile.dart';
import '../../widgets/template_saved_toast.dart';

const _uuid = Uuid();

class _DraggedItem {
  final String id;

  const _DraggedItem(this.id);
}

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
  final FocusNode _itemFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final List<ShoppingListItem> _items = [];
  List<FoodSuggestion> _suggestions = [];
  late final Set<String> _templateSignatures;
  final Set<String> _collapsedCategories = {};
  final Map<String, bool> _dropAfterByItemId = {};
  String? _previewAnchorItemId;
  bool? _previewPlaceAfter;
  String? _pendingCategory;
  ShoppingList? _sharedDraftList;

  @override
  void initState() {
    super.initState();
    _templateSignatures = widget.existingTemplates
        .map((template) => signatureFromTemplateItems(template.items))
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
    }
  }

  @override
  void dispose() {
    _itemController.dispose();
    _quantityController.dispose();
    _itemFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _canSaveTemplate =>
      _items.isNotEmpty &&
      !_templateSignatures.contains(signatureFromItems(_items));

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
          quantity: result.quantity.trim().isEmpty
              ? null
              : result.quantity.trim(),
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

  void _onItemTextChanged(String value) {
    setState(() {
      _suggestions = [];
    });
  }

  void _addFromSuggestion(FoodSuggestion suggestion) {
    setState(() {
      _items.add(
        ShoppingListItem(
          id: _uuid.v4(),
          name: suggestion.name,
          quantity: _quantityController.text.trim().isEmpty
              ? null
              : _quantityController.text.trim(),
          category: _pendingCategory == 'Other'
              ? null
              : _pendingCategory ?? suggestion.category,
        ),
      );
      _suggestions = [];
      _pendingCategory = null;
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
          id: _uuid.v4(),
          name: text,
          quantity: _quantityController.text.trim().isEmpty
              ? null
              : _quantityController.text.trim(),
          category: _pendingCategory == 'Other'
              ? null
              : _pendingCategory ?? SuggestionService.categoryFor(text),
        ),
      );
      _suggestions = [];
      _pendingCategory = null;
    });
    _itemController.clear();
    _quantityController.clear();
  }

  Future<void> _showAddItemPopup([String? category]) async {
    _pendingCategory = category;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black38,
      pageBuilder: (dialogContext, _, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _itemFocusNode.requestFocus();
          }
        });
        return MediaQuery.removeViewInsets(
          context: dialogContext,
          removeLeft: true,
          removeTop: true,
          removeRight: true,
          removeBottom: true,
          child: GestureDetector(
            onTap: () => Navigator.pop(dialogContext),
            behavior: HitTestBehavior.opaque,
            child: Material(
              color: Colors.transparent,
              child: Center(
                child: GestureDetector(
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: CenteredPopupShell(
                      child: AddItemFields(
                        itemController: _itemController,
                        quantityController: _quantityController,
                        itemFocusNode: _itemFocusNode,
                        onChanged: _onItemTextChanged,
                        onSubmit: () {
                          if (_itemController.text.trim().isEmpty) return;
                          _addFromText();
                          Navigator.pop(dialogContext);
                        },
                        suggestions: _suggestions.isNotEmpty
                            ? AutocompleteDropdown(
                                suggestions: _suggestions,
                                onSelect: (suggestion) {
                                  _addFromSuggestion(suggestion);
                                  Navigator.pop(dialogContext);
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    _pendingCategory = null;
    _suggestions = [];
  }

  void _dismissSuggestions() {
    setState(() => _suggestions = []);
  }

  ShoppingList _buildListResult() => ShoppingList(
    id: _sharedDraftList?.id ?? _uuid.v4(),
    date: _selectedDate,
    labels: _sharedDraftList?.labels,
    isCompleted: _sharedDraftList?.isCompleted ?? false,
    totalPrice: _sharedDraftList?.totalPrice,
    currencySymbol: _sharedDraftList?.currencySymbol ?? '€',
    items: List.from(_items),
  );

  void _popWithCurrentList() {
    Navigator.pop(context, _items.isEmpty ? null : _buildListResult());
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
          decoration: const InputDecoration(hintText: 'Template name'),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            icon: const Icon(Icons.check),
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
      _templateSignatures.add(signatureFromItems(_items));
    });
    showTemplateSavedToast(context, name);
  }

  Future<void> _shareCurrentList() async {
    if (_items.isEmpty) {
      return;
    }
    final list = _buildListResult();
    try {
      await listRepository.saveList(list);
      if (!mounted) {
        return;
      }
      setState(() {
        _sharedDraftList = list;
      });
      await showDialog<void>(
        context: context,
        builder: (_) => ShareDialog(
          getShares: () => listRepository.getListShares(list.id),
          getUsers: listRepository.getUsers,
          share: (userId) => listRepository.shareList(list.id, userId),
          unshare: (userId) => listRepository.unshareList(list.id, userId),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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
      final sourceIndex = _items.indexWhere((item) => item.id == itemId);
      if (sourceIndex == -1) return;

      final movingItem = _items.removeAt(sourceIndex);
      movingItem.category = targetCategory == 'Other' ? null : targetCategory;

      final anchorIndex = _items.indexWhere((item) => item.id == anchorItemId);
      if (anchorIndex == -1) {
        _items.add(movingItem);
        return;
      }

      final insertIndex = placeAfter ? anchorIndex + 1 : anchorIndex;
      _items.insert(insertIndex, movingItem);
    });
  }

  void _updateDropPosition(
    BuildContext context,
    String anchorItemId,
    Offset offset,
  ) {
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
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;

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
              onToggle: () => _toggleItem(item.id),
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
                      color: fillColor,
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
                      leading: withHandle
                          ? _categoryPicker(context, item)
                          : null,
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
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _popWithCurrentList();
      },
      child: Scaffold(
        body: GestureDetector(
          onTap: _dismissSuggestions,
          behavior: HitTestBehavior.translucent,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: ListView(
                      controller: _scrollController,
                      children: [
                        const SizedBox(height: 56),
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
                            ],
                          ),
                        ),
                        if (_items.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          for (final entry in groupedItems(_items).entries)
                            CategorySection(
                              category: entry.key,
                              items: entry.value,
                              isCollapsed: _collapsedCategories.contains(
                                entry.key,
                              ),
                              onToggleCollapse: () =>
                                  _toggleCollapse(entry.key),
                              onAdd: () => _showAddItemPopup(entry.key),
                              itemBuilder: (ctx, item) => _buildItemRow(
                                ctx,
                                item,
                                category: entry.key,
                                withHandle: true,
                              ),
                            ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton.filled(
                        onPressed: () => _showAddItemPopup(),
                        style: IconButton.styleFrom(
                          backgroundColor: fillColor,
                          foregroundColor: theme.colorScheme.onSurface,
                        ),
                        tooltip: 'Add item',
                        icon: const Icon(Icons.add, size: 22),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                        child: IconButton.filled(
                          onPressed: _popWithCurrentList,
                          style: IconButton.styleFrom(
                            backgroundColor: fillColor,
                            foregroundColor: _items.isEmpty
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.primary,
                          ),
                          tooltip: _items.isEmpty ? 'Back' : 'Save',
                          icon: Icon(
                            _items.isEmpty
                                ? LucideIcons.chevron_left
                                : LucideIcons.check,
                            size: 22,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: ActionTabButton(
                                icon: LucideIcons.star,
                                onTap: _canSaveTemplate
                                    ? _saveAsTemplate
                                    : null,
                              ),
                            ),
                            if (authStateNotifier.value)
                              Expanded(
                                child: ActionTabButton(
                                  icon: Icons.person_add_outlined,
                                  onTap: _items.isNotEmpty
                                      ? _shareCurrentList
                                      : null,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
