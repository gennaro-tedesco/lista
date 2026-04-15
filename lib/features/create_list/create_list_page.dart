import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../app/ui_sizes.dart';
import '../../models/food_suggestion.dart';
import '../../models/shopping_list.dart';
import '../../models/shopping_list_item.dart';
import '../../models/shopping_list_template.dart';
import '../../repositories/list_repository.dart';
import '../../services/suggestion_service.dart';
import '../../utils/category_utils.dart';
import '../../utils/template_utils.dart';
import '../../services/image_service.dart';
import '../../services/settings_service.dart';
import '../../services/voice_service.dart';
import '../../widgets/action_tab_button.dart';
import '../../widgets/add_item_input.dart';
import '../../widgets/autocomplete_dropdown.dart';
import '../../widgets/centered_popup_shell.dart';
import '../../widgets/edit_item_dialog.dart';
import '../../widgets/share_dialog.dart';
import '../../widgets/shopping_list_item_tile.dart';
import '../../widgets/template_saved_toast.dart';
import '../../widgets/note_sheet.dart';
import '../../widgets/recording_overlay.dart';
import '../../widgets/voice_confirmation_sheet.dart';
import '../../services/note_service.dart';

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

class _CreateListPageState extends State<CreateListPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  static final _random = Random();
  final DateTime _selectedDate = DateTime.now();
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isExtractingImage = false;
  static const _edgeScrollThreshold = 80.0;
  static const _edgeScrollSpeed = 400.0;
  static const _edgeScrollInterval = Duration(milliseconds: 16);
  static const _edgeScrollFrameSeconds = 16 / 1000;
  final List<ShoppingListItem> _items = [];
  List<FoodSuggestion> _suggestions = [];
  late final Set<String> _templateSignatures;
  final Set<String> _collapsedCategories = {};
  final Map<String, bool> _dropAfterByItemId = {};
  String? _previewAnchorItemId;
  bool? _previewPlaceAfter;
  String? _pendingCategory;
  ShoppingList? _sharedDraftList;
  late final AnimationController _fishController;
  late Offset _fishPosition;
  late Offset _penguinPosition;
  late bool _fishStartsFirst;
  late final String _draftListId;
  double _noteIconTurns = 0.0;
  Set<String> _highlightedItemIds = {};
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _draftListId = _uuid.v4();
    _randomizeEmptyState();
    _fishController = AnimationController(
      duration: const Duration(milliseconds: 5600),
      vsync: this,
    );
    _fishController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _randomizeEmptyState();
          });
        }
        _fishController.forward(from: 0);
      }
    });
    _fishController.forward();
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
    _scrollTimer?.cancel();
    if (_isRecording) unawaited(VoiceService.cancel());
    _fishController.dispose();
    _itemController.dispose();
    _quantityController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _randomizeEmptyState() {
    _fishStartsFirst = _random.nextBool();
    _fishPosition = _randomUpperPosition();
    _penguinPosition = _randomLowerPosition();
  }

  Offset _randomUpperPosition() {
    final x = 0.08 + (_random.nextDouble() * 0.84);
    final y = 0.08 + (_random.nextDouble() * 0.22);
    return Offset(x, y);
  }

  Offset _randomLowerPosition() {
    final x = 0.08 + (_random.nextDouble() * 0.84);
    final y = 0.62 + (_random.nextDouble() * 0.22);
    return Offset(x, y);
  }

  double _windowOpacity(
    double progress, {
    required double start,
    required double end,
  }) {
    if (progress <= start || progress >= end) {
      return 0;
    }
    final normalized = (progress - start) / (end - start);
    if (normalized < 0.2) {
      return normalized / 0.2;
    }
    if (normalized > 0.8) {
      return (1 - normalized) / 0.2;
    }
    return 1;
  }

  bool get _canSaveTemplate =>
      _items.isNotEmpty &&
      !_templateSignatures.contains(signatureFromItems(_items));

  void _toggleItem(String id) {
    final item = _items.firstWhere((i) => i.id == id);
    setState(() {
      item.isChecked = !item.isChecked;
      final category = item.category ?? 'Other';
      final categoryItems = _items.where(
        (i) => (i.category ?? 'Other') == category,
      );
      if (categoryItems.every((i) => i.isChecked)) {
        _collapsedCategories.add(category);
      }
    });
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
        final nameChanged =
            trimmedName.toLowerCase() != item.name.toLowerCase();
        _items[idx] = ShoppingListItem(
          id: item.id,
          name: trimmedName,
          quantity: result.quantity.trim().isEmpty
              ? null
              : result.quantity.trim(),
          isChecked: item.isChecked,
          category: nameChanged
              ? SuggestionService.categoryFor(trimmedName) ?? item.category
              : item.category,
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

  bool _isDuplicate(String name, String? quantity) => _items.any(
    (i) =>
        i.name.trim().toLowerCase() == name.trim().toLowerCase() &&
        i.quantity == quantity,
  );

  void _addFromSuggestion(FoodSuggestion suggestion) {
    final quantity = _quantityController.text.trim().isEmpty
        ? null
        : _quantityController.text.trim();
    if (_isDuplicate(suggestion.name, quantity)) return;
    setState(() {
      _items.add(
        ShoppingListItem(
          id: _uuid.v4(),
          name: suggestion.name,
          quantity: quantity,
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
    final quantity = _quantityController.text.trim().isEmpty
        ? null
        : _quantityController.text.trim();
    if (_isDuplicate(text, quantity)) return;
    setState(() {
      _items.add(
        ShoppingListItem(
          id: _uuid.v4(),
          name: text,
          quantity: quantity,
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
                        autofocus: true,
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

  void _startScroll(double direction) {
    if (_scrollTimer != null) return;
    _scrollTimer = Timer.periodic(_edgeScrollInterval, (_) {
      if (!_scrollController.hasClients) {
        _stopEdgeScroll();
        return;
      }
      final newOffset =
          (_scrollController.offset +
                  direction * _edgeScrollSpeed * _edgeScrollFrameSeconds)
              .clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.jumpTo(newOffset);
    });
  }

  void _stopEdgeScroll() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
  }

  void _dismissSuggestions() {
    setState(() => _suggestions = []);
  }

  ShoppingList _buildListResult() => ShoppingList(
    id: _sharedDraftList?.id ?? _draftListId,
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

  Future<void> _openNotePanel() async {
    final initial = await NoteService.getNote(_draftListId) ?? '';
    if (!mounted) return;
    setState(() => _noteIconTurns += 1.0);
    final saved = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => NoteSheet(initialText: initial),
    );
    if (!mounted) return;
    setState(() => _noteIconTurns += 1.0);
    if (saved != null) {
      await NoteService.saveNote(_draftListId, saved);
    }
  }

  void _showNoResultsPopup() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        Future.delayed(const Duration(seconds: 1), () {
          if (ctx.mounted) Navigator.of(ctx).pop();
        });
        return const AlertDialog(title: Text('No results'));
      },
    );
  }

  void _toggleSearch() {
    if (_isSearchVisible) {
      _submitSearch();
      return;
    }
    setState(() {
      _isSearchVisible = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _closeSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _isSearchVisible = false;
      _highlightedItemIds = {};
    });
  }

  Future<void> _submitSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      return;
    }
    final matched = _items
        .where((item) => item.name.toLowerCase().contains(query.toLowerCase()))
        .map((i) => i.id)
        .toSet();
    if (matched.isEmpty) {
      if (!mounted) return;
      _showNoResultsPopup();
      return;
    }
    setState(() {
      _highlightedItemIds = matched;
      for (final item in _items.where((i) => matched.contains(i.id))) {
        _collapsedCategories.remove(item.category ?? 'Other');
      }
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    const iconRowHeight = 56.0;
    const categoryHeaderHeight = 40.0;
    const itemHeight = 46.0;
    double offset = iconRowHeight;
    outer:
    for (final entry in groupedItems(_items).entries) {
      offset += categoryHeaderHeight;
      if (!_collapsedCategories.contains(entry.key)) {
        for (final item in entry.value) {
          if (matched.contains(item.id)) break outer;
          offset += itemHeight;
        }
      }
    }
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _showBackConfirmation() async {
    if (_items.isEmpty) {
      Navigator.pop(context, null);
      return;
    }
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save list?'),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context, false),
            icon: const Icon(Icons.close),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check),
          ),
        ],
      ),
    );
    if (!mounted || save == null) return;
    Navigator.pop(context, save ? _buildListResult() : null);
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      setState(() {
        _isRecording = false;
        _isProcessing = true;
      });
      List<ExtractedItem> extracted;
      try {
        extracted = await VoiceService.stopAndExtract();
      } on VoiceException catch (e) {
        if (!mounted) return;
        setState(() => _isProcessing = false);
        final provider = providerNotifier.value.displayName;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(switch (e.code) {
              'no_audio' => 'No audio recorded — try speaking for longer',
              'too_quiet' => 'No sound detected — speak louder',
              'unauthorized' => 'You need to sign in again to use voice input',
              'model_unavailable' =>
                '$provider unavailable — try again shortly',
              'server_unreachable' =>
                'Could not reach the server — check your connection',
              'upstream_timeout' =>
                '$provider did not return in time — try again',
              'provider_unavailable' =>
                '$provider is temporarily unavailable due to high demand — try again later',
              'model_not_found' =>
                'The configured $provider model is not available',
              'quota_exceeded' =>
                '$provider quota has been exceeded — try again later',
              'empty_model_output' =>
                '$provider returned no usable result for this voice input',
              'invalid_model_output' =>
                '$provider returned a result in an unexpected format',
              'transcription_failed' =>
                '$provider could not transcribe your voice input — try again',
              _ => 'Could not process voice input — try again',
            }),
          ),
        );
        return;
      } catch (_) {
        if (!mounted) return;
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not reach the server — check your connection'),
          ),
        );
        return;
      }
      if (!mounted) return;
      setState(() => _isProcessing = false);
      if (extracted.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No shopping items recognised — try speaking more clearly',
            ),
          ),
        );
        return;
      }
      final confirmed = await VoiceConfirmationSheet.show(
        context,
        extracted,
        source: ExtractionSource.voice,
      );
      if (!mounted || confirmed == null) return;
      setState(() {
        for (final item in confirmed) {
          _items.add(item.toItem());
        }
      });
    } else {
      if (!await VoiceService.hasPermission()) return;
      await VoiceService.start();
      if (!mounted) return;
      setState(() => _isRecording = true);
    }
  }

  Future<void> _extractItemsFromImage() async {
    final useCamera = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.camera),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, true),
            ),
            ListTile(
              leading: const Icon(LucideIcons.image),
              title: const Text('Upload from gallery'),
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
    if (useCamera == null || !mounted) return;
    final picked = await ImagePicker().pickImage(
      source: useCamera ? ImageSource.camera : ImageSource.gallery,
    );
    if (!mounted || picked == null) return;
    setState(() => _isExtractingImage = true);
    List<ExtractedItem> extracted;
    try {
      extracted = await ImageService.extractFromImage(
        await picked.readAsBytes(),
        picked.mimeType ?? _mimeTypeForPath(picked.path),
      );
    } on VoiceException catch (e) {
      if (!mounted) return;
      setState(() => _isExtractingImage = false);
      final provider = providerNotifier.value.displayName;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (e.code) {
            'empty_input' => 'No image data was provided',
            'payload_too_large' => 'The image is too large to process',
            'unsupported_provider' =>
              'Image extraction is not supported by $provider',
            'unknown_error' =>
              'An unexpected error occurred while processing the image',
            'unauthorized' =>
              'You need to sign in again to extract items from images',
            'model_unavailable' =>
              '$provider unavailable — try again shortly',
            'server_unreachable' =>
              'Could not reach the server — check your connection',
            'upstream_timeout' =>
              '$provider did not return in time — try again',
            'provider_unavailable' =>
              '$provider is temporarily unavailable due to high demand — try again later',
            'model_not_found' =>
              'The configured $provider model is not available',
            'quota_exceeded' =>
              '$provider quota has been exceeded — try again later',
            'invalid_json' =>
              '$provider returned no usable result for this image',
            'schema_mismatch' =>
              '$provider returned a result in an unexpected format',
            'extraction_failed' =>
              '$provider could not extract items from the image — try again',
            _ => 'Could not process the image — try again',
          }),
        ),
      );
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _isExtractingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not extract items from the image — check your connection',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _isExtractingImage = false);
    if (extracted.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No shopping items recognised — try a clearer image'),
        ),
      );
      return;
    }
    final confirmed = await VoiceConfirmationSheet.show(
      context,
      extracted,
      source: ExtractionSource.image,
    );
    if (!mounted || confirmed == null) return;
    setState(() {
      for (final item in confirmed) {
        _items.add(item.toItem());
      }
    });
  }

  String _mimeTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    return 'image/jpeg';
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
                  : _highlightedItemIds.contains(item.id)
                  ? theme.colorScheme.tertiary.withValues(alpha: 0.25)
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
            onDragStarted: _dismissSuggestions,
            onDragEnd: (_) {
              _clearDropPosition(item.id);
              _previewAnchorItemId = null;
              _previewPlaceAfter = null;
              _stopEdgeScroll();
            },
            onDraggableCanceled: (velocity, offset) {
              _clearDropPosition(item.id);
              _stopEdgeScroll();
            },
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
        _showBackConfirmation();
      },
      child: Scaffold(
        body: GestureDetector(
          onTap: _dismissSuggestions,
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Scrollbar(
                            controller: _scrollController,
                            thumbVisibility: true,
                            child: ListView(
                              controller: _scrollController,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    8,
                                    8,
                                    8,
                                    0,
                                  ),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        onPressed: _openNotePanel,
                                        tooltip: 'Note',
                                        color: theme.colorScheme.onSurface,
                                        icon: AnimatedRotation(
                                          turns: _noteIconTurns,
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          child: const Icon(
                                            LucideIcons.notepad_text,
                                            size: AppIconSize.toolbar,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 220,
                                            ),
                                            curve: Curves.easeOutCubic,
                                            width: _isSearchVisible ? 180 : 0,
                                            height: AppFieldSize.inlineSearch,
                                            child: ClipRect(
                                              child: Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: SizedBox(
                                                  width: 180,
                                                  height:
                                                      AppFieldSize.inlineSearch,
                                                  child: TextField(
                                                    controller:
                                                        _searchController,
                                                    focusNode: _searchFocusNode,
                                                    autofocus: true,
                                                    textAlignVertical:
                                                        TextAlignVertical
                                                            .center,
                                                    textCapitalization:
                                                        TextCapitalization
                                                            .sentences,
                                                    textInputAction:
                                                        TextInputAction.search,
                                                    maxLines: 1,
                                                    onSubmitted: (_) =>
                                                        _submitSearch(),
                                                    decoration: InputDecoration(
                                                      hintText: 'Search items',
                                                      filled: true,
                                                      fillColor: fillColor,
                                                      isDense: true,
                                                      contentPadding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 8,
                                                          ),
                                                      suffixIconConstraints:
                                                          AppConstraints
                                                              .compactIcon,
                                                      border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              999,
                                                            ),
                                                        borderSide:
                                                            BorderSide.none,
                                                      ),
                                                      enabledBorder:
                                                          OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  999,
                                                                ),
                                                            borderSide:
                                                                BorderSide.none,
                                                          ),
                                                      focusedBorder:
                                                          OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  999,
                                                                ),
                                                            borderSide:
                                                                BorderSide.none,
                                                          ),
                                                      suffixIcon: IconButton(
                                                        onPressed: _closeSearch,
                                                        icon: const Icon(
                                                          LucideIcons.x,
                                                          size: AppIconSize
                                                              .inlineAction,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: _items.isEmpty
                                                ? null
                                                : _highlightedItemIds.isNotEmpty
                                                ? () => setState(
                                                    () => _highlightedItemIds =
                                                        {},
                                                  )
                                                : _toggleSearch,
                                            tooltip: 'Search',
                                            color: theme.colorScheme.onSurface,
                                            icon: const Icon(
                                              LucideIcons.search,
                                              size: AppIconSize.toolbar,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (_items.isNotEmpty) ...[
                                  for (final entry in groupedItems(
                                    _items,
                                  ).entries)
                                    CategorySection(
                                      category: entry.key,
                                      items: entry.value,
                                      isCollapsed: _collapsedCategories
                                          .contains(entry.key),
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
                                ] else ...[
                                  const SizedBox(height: 32),
                                  SizedBox(
                                    height:
                                        MediaQuery.sizeOf(context).height * 0.5,
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final width = constraints.maxWidth - 48;
                                        final height =
                                            constraints.maxHeight - 48;
                                        return AnimatedBuilder(
                                          animation: _fishController,
                                          builder: (context, child) {
                                            final progress =
                                                _fishController.value;
                                            final emojiSize =
                                                theme
                                                    .textTheme
                                                    .displayMedium
                                                    ?.fontSize ??
                                                40.0;
                                            final leadOpacity = _windowOpacity(
                                              progress,
                                              start: 0.0,
                                              end: 0.62,
                                            );
                                            final followOpacity =
                                                _windowOpacity(
                                                  progress,
                                                  start: 0.18,
                                                  end: 0.8,
                                                );
                                            return Stack(
                                              children: [
                                                Positioned(
                                                  left:
                                                      24 +
                                                      (_fishPosition.dx *
                                                          width),
                                                  top:
                                                      24 +
                                                      (_fishPosition.dy *
                                                          height),
                                                  child: Transform.translate(
                                                    offset: Offset(
                                                      -(emojiSize / 2),
                                                      -(emojiSize / 2),
                                                    ),
                                                    child: Opacity(
                                                      opacity: _fishStartsFirst
                                                          ? leadOpacity
                                                          : followOpacity,
                                                      child: Text(
                                                        '🐟',
                                                        style: theme
                                                            .textTheme
                                                            .displayMedium,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Positioned(
                                                  left:
                                                      24 +
                                                      (_penguinPosition.dx *
                                                          width),
                                                  top:
                                                      24 +
                                                      (_penguinPosition.dy *
                                                          height),
                                                  child: Transform.translate(
                                                    offset: Offset(
                                                      -(emojiSize / 2),
                                                      -(emojiSize / 2),
                                                    ),
                                                    child: Opacity(
                                                      opacity: _fishStartsFirst
                                                          ? followOpacity
                                                          : leadOpacity,
                                                      child: Text(
                                                        '🐧',
                                                        style: theme
                                                            .textTheme
                                                            .displayMedium,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: _edgeScrollThreshold,
                            child: DragTarget<_DraggedItem>(
                              onWillAcceptWithDetails: (_) => true,
                              onMove: (_) => _startScroll(-1),
                              onLeave: (_) => _stopEdgeScroll(),
                              builder: (context, c, r) =>
                                  const SizedBox.expand(),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: _edgeScrollThreshold,
                            child: DragTarget<_DraggedItem>(
                              onWillAcceptWithDetails: (_) => true,
                              onMove: (_) => _startScroll(1),
                              onLeave: (_) => _stopEdgeScroll(),
                              builder: (context, c, r) =>
                                  const SizedBox.expand(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (authStateNotifier.value) ...[
                            IconButton.filled(
                              onPressed: _isProcessing || _isExtractingImage
                                  ? null
                                  : _toggleRecording,
                              style: IconButton.styleFrom(
                                backgroundColor: fillColor,
                                foregroundColor: _isRecording
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.onSurface,
                              ),
                              tooltip: 'Voice input',
                              icon: _isProcessing
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    )
                                  : const Icon(
                                      LucideIcons.mic,
                                      size: AppIconSize.toolbar,
                                    ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: _isProcessing || _isExtractingImage
                                  ? null
                                  : _extractItemsFromImage,
                              style: IconButton.styleFrom(
                                backgroundColor: fillColor,
                                foregroundColor: theme.colorScheme.onSurface,
                              ),
                              tooltip: 'Image input',
                              icon: _isExtractingImage
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    )
                                  : const Icon(
                                      LucideIcons.image,
                                      size: AppIconSize.toolbar,
                                    ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          IconButton.filled(
                            onPressed: () => _showAddItemPopup(),
                            style: IconButton.styleFrom(
                              backgroundColor: fillColor,
                              foregroundColor: theme.colorScheme.onSurface,
                            ),
                            tooltip: 'Add item',
                            icon: const Icon(
                              Icons.add,
                              size: AppIconSize.toolbar,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          IconButton.filled(
                            onPressed: _showBackConfirmation,
                            style: IconButton.styleFrom(
                              backgroundColor: fillColor,
                              foregroundColor: theme.colorScheme.onSurface,
                            ),
                            tooltip: 'Back',
                            icon: const Icon(
                              LucideIcons.chevron_left,
                              size: AppIconSize.toolbar,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: authStateNotifier.value
                                ? Row(
                                    children: [
                                      Expanded(
                                        child: ActionTabButton(
                                          icon: LucideIcons.star,
                                          onTap: _canSaveTemplate
                                              ? _saveAsTemplate
                                              : null,
                                        ),
                                      ),
                                      Expanded(
                                        child: ActionTabButton(
                                          icon: Icons.person_add_outlined,
                                          onTap: _items.isNotEmpty
                                              ? _shareCurrentList
                                              : null,
                                        ),
                                      ),
                                    ],
                                  )
                                : Center(
                                    child: FractionallySizedBox(
                                      widthFactor: 0.5,
                                      child: ActionTabButton(
                                        icon: LucideIcons.star,
                                        onTap: _canSaveTemplate
                                            ? _saveAsTemplate
                                            : null,
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _items.isNotEmpty
                                ? _popWithCurrentList
                                : null,
                            style: IconButton.styleFrom(
                              backgroundColor: fillColor,
                              foregroundColor: _items.isNotEmpty
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.38,
                                    ),
                            ),
                            tooltip: 'Save',
                            icon: const Icon(
                              LucideIcons.check,
                              size: AppIconSize.toolbar,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_isRecording)
                Positioned.fill(
                  child: RecordingOverlay(onTap: _toggleRecording),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
