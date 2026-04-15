import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
import '../../widgets/action_tab_button.dart';
import '../../widgets/add_item_input.dart';
import '../../widgets/autocomplete_dropdown.dart';
import '../../widgets/centered_popup_shell.dart';
import '../../widgets/edit_item_dialog.dart';
import '../../widgets/share_dialog.dart';
import '../../widgets/shopping_list_item_tile.dart';
import '../../widgets/note_sheet.dart';
import '../../widgets/recording_overlay.dart';
import '../../widgets/template_saved_toast.dart';
import '../../widgets/voice_confirmation_sheet.dart';
import '../../services/image_service.dart';
import '../../services/note_service.dart';
import '../../services/voice_service.dart';

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
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _itemFocusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;
  static const _currencyOptions = ['€', '\$', '£', '¥', 'CHF'];
  static const _edgeScrollThreshold = 80.0;
  static const _edgeScrollSpeed = 400.0;
  static const _edgeScrollInterval = Duration(milliseconds: 16);
  static const _edgeScrollFrameSeconds = 16 / 1000;
  List<FoodSuggestion> _suggestions = [];
  late final Set<String> _templateSignatures;
  final Set<String> _collapsedCategories = {};
  String? _pendingCategory;
  final Map<String, bool> _dropAfterByItemId = {};
  String? _previewAnchorItemId;
  bool? _previewPlaceAfter;
  bool _isSharedByMe = false;
  RealtimeChannel? _realtimeChannel;
  bool _saveInFlight = false;
  bool _saveQueued = false;
  bool _hasPendingLocalSave = false;
  bool _refreshAfterSave = false;
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isExtractingImage = false;
  double _noteIconTurns = 0.0;
  bool _isSearchVisible = false;
  Set<String> _highlightedItemIds = {};

  @override
  void initState() {
    super.initState();
    _totalPriceController.text = widget.list.totalPrice ?? '';
    _templateSignatures = widget.existingTemplates
        .map((template) => signatureFromTemplateItems(template.items))
        .toSet();
    _loadShareState();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    if (_isRecording) unawaited(VoiceService.cancel());
    _unsubscribeRealtime();
    _itemController.dispose();
    _quantityController.dispose();
    _totalPriceController.dispose();
    _searchController.dispose();
    _itemFocusNode.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
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

  bool get _canSaveTemplate =>
      widget.list.items.isNotEmpty &&
      !_templateSignatures.contains(signatureFromItems(widget.list.items));

  Future<void> _openNotePanel() async {
    final initial = await NoteService.getNote(widget.list.id) ?? '';
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
      await NoteService.saveNote(widget.list.id, saved);
    }
  }

  void _showNoResultsPopup() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
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
    });
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
    final items = widget.list.items;
    final matched = items
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
      for (final item in items.where((i) => matched.contains(i.id))) {
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
    for (final entry in groupedItems(items).entries) {
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

  Future<void> _loadShareState() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (widget.list.ownerId == null ||
        currentUserId == null ||
        widget.list.ownerId != currentUserId) {
      return;
    }
    final isShared = await listRepository.listHasShares(widget.list.id);
    if (!mounted) return;
    setState(() {
      _isSharedByMe = isShared;
    });
  }

  void _subscribeRealtime() {
    if (!authStateNotifier.value) {
      return;
    }
    _realtimeChannel = Supabase.instance.client
        .channel('list-view-${widget.list.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shopping_lists',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.list.id,
          ),
          callback: (_) => _handleRemoteChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shopping_list_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'list_id',
            value: widget.list.id,
          ),
          callback: (_) => _handleRemoteChange(),
        )
        .subscribe();
  }

  void _unsubscribeRealtime() {
    if (_realtimeChannel != null) {
      unawaited(Supabase.instance.client.removeChannel(_realtimeChannel!));
      _realtimeChannel = null;
    }
  }

  ShoppingList _snapshotList() => ShoppingList(
    id: widget.list.id,
    ownerId: widget.list.ownerId,
    date: widget.list.date,
    labels: List<String>.from(widget.list.labels),
    isCompleted: widget.list.isCompleted,
    totalPrice: widget.list.totalPrice,
    currencySymbol: widget.list.currencySymbol,
    items: widget.list.items
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

  Future<void> _queueSave() async {
    _hasPendingLocalSave = true;
    if (_saveInFlight) {
      _saveQueued = true;
      return;
    }
    do {
      _saveInFlight = true;
      _saveQueued = false;
      try {
        await listRepository.saveList(_snapshotList());
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$e')));
        }
      } finally {
        _saveInFlight = false;
      }
    } while (_saveQueued);
    _hasPendingLocalSave = false;
    if (_refreshAfterSave) {
      _refreshAfterSave = false;
      await _refreshFromRemote();
    }
  }

  Future<void> _handleRemoteChange() async {
    if (_hasPendingLocalSave || _saveInFlight) {
      _refreshAfterSave = true;
      return;
    }
    await _refreshFromRemote();
  }

  Future<void> _refreshFromRemote() async {
    final updated = await listRepository.getListById(widget.list.id);
    if (!mounted) {
      return;
    }
    if (updated == null) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      widget.list.ownerId = updated.ownerId;
      widget.list.date = updated.date;
      widget.list.labels = List<String>.from(updated.labels);
      widget.list.isCompleted = updated.isCompleted;
      widget.list.totalPrice = updated.totalPrice;
      widget.list.currencySymbol = updated.currencySymbol;
      widget.list.items = updated.items
          .map(
            (item) => ShoppingListItem(
              id: item.id,
              name: item.name,
              quantity: item.quantity,
              isChecked: item.isChecked,
              category: item.category,
            ),
          )
          .toList();
      _totalPriceController.text = widget.list.totalPrice ?? '';
    });
  }

  void _toggle(String id) {
    final item = widget.list.items.firstWhere((i) => i.id == id);
    setState(() {
      item.isChecked = !item.isChecked;
      final category = item.category ?? 'Other';
      final categoryItems = widget.list.items.where(
        (i) => (i.category ?? 'Other') == category,
      );
      if (categoryItems.every((i) => i.isChecked)) {
        _collapsedCategories.add(category);
      }
    });
    unawaited(_queueSave());
  }

  void _deleteItem(String id) {
    setState(() => widget.list.items.removeWhere((i) => i.id == id));
    unawaited(_queueSave());
  }

  void _changeCategory(String id, String? newCategory) {
    setState(() {
      widget.list.items.firstWhere((i) => i.id == id).category = newCategory;
    });
    unawaited(_queueSave());
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

  bool _isDuplicate(String name, String? quantity) => widget.list.items.any(
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
      widget.list.items.add(
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
    unawaited(_queueSave());
  }

  void _addFromText() {
    final text = _itemController.text.trim();
    if (text.isEmpty) return;
    final quantity = _quantityController.text.trim().isEmpty
        ? null
        : _quantityController.text.trim();
    if (_isDuplicate(text, quantity)) return;
    setState(() {
      widget.list.items.add(
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
    unawaited(_queueSave());
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(switch (e.code) {
              'no_audio' => 'No audio recorded — try speaking for longer',
              'too_quiet' => 'No sound detected — speak louder',
              'unauthorized' => 'You need to sign in again to use voice input',
              'model_unavailable' => 'Model unavailable — try again shortly',
              'server_unreachable' =>
                'Could not reach the server — check your connection',
              'upstream_timeout' =>
                'The model did not return in time — try again',
              'transcription_failed' =>
                'The model could not transcribe your voice input — try again',
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
          widget.list.items.add(item.toItem());
        }
      });
      unawaited(_queueSave());
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (e.code) {
            'unauthorized' =>
              'You need to sign in again to extract items from images',
            'model_unavailable' => 'Model unavailable — try again shortly',
            'server_unreachable' =>
              'Could not reach the server — check your connection',
            'upstream_timeout' =>
              'The model did not return in time — try again',
            'extraction_failed' =>
              'The model could not extract items from the image — try again',
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
        widget.list.items.add(item.toItem());
      }
    });
    unawaited(_queueSave());
  }

  String _mimeTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    return 'image/jpeg';
  }

  Future<void> _pickDate() async {
    final theme = Theme.of(context);
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;
    final picked = await showGeneralDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black38,
      pageBuilder: (ctx, _, _) => Center(
        child: Transform.scale(
          scale: 0.9,
          child: Material(
            color: fillColor,
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 300,
                child: CalendarDatePicker(
                  initialDate: widget.list.date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  onDateChanged: (date) => Navigator.pop(ctx, date),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => widget.list.date = picked);
    unawaited(_queueSave());
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

  Future<void> _openPriceDialog() async {
    String? draftPrice = widget.list.totalPrice;
    String draftCurrency = widget.list.currencySymbol;
    bool priceError = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final theme = Theme.of(dialogContext);
          final fillColor =
              theme.inputDecorationTheme.fillColor ??
              theme.colorScheme.surfaceContainerHighest;
          return AlertDialog(
            title: const Text('Total price'),
            content: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _totalPriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    autofocus: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: InputDecoration(
                      hintText: 'Total price',
                      filled: true,
                      fillColor: fillColor,
                      errorText: priceError ? '' : null,
                      errorStyle: const TextStyle(height: 0),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.error,
                          width: 1.5,
                        ),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.error,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onChanged: (v) => setDialogState(() {
                      final trimmed = v.trim();
                      if (trimmed.isEmpty) {
                        draftPrice = null;
                        priceError = false;
                      } else {
                        final parsed = double.tryParse(
                          trimmed.replaceAll(',', '.'),
                        );
                        priceError = parsed == null;
                        if (parsed != null) draftPrice = trimmed;
                      }
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownMenu<String>(
                  initialSelection: draftCurrency,
                  onSelected: (v) =>
                      setDialogState(() => draftCurrency = v ?? draftCurrency),
                  width: 96,
                  inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor: fillColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  dropdownMenuEntries: _currencyOptions
                      .map((c) => DropdownMenuEntry<String>(value: c, label: c))
                      .toList(),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              IconButton(
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close),
              ),
              IconButton(
                onPressed: priceError
                    ? null
                    : () {
                        widget.list.totalPrice = draftPrice;
                        widget.list.currencySymbol = draftCurrency;
                        Navigator.pop(dialogContext);
                      },
                icon: const Icon(Icons.check),
              ),
            ],
          );
        },
      ),
    );
    setState(() {});
    unawaited(_queueSave());
  }

  Future<void> _shareList() async {
    await showDialog<void>(
      context: context,
      builder: (_) => ShareDialog(
        getShares: () => listRepository.getListShares(widget.list.id),
        getUsers: listRepository.getUsers,
        share: (userId) => listRepository.shareList(widget.list.id, userId),
        unshare: (userId) => listRepository.unshareList(widget.list.id, userId),
      ),
    );
    await _loadShareState();
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
        final nameChanged =
            trimmedName.toLowerCase() != item.name.toLowerCase();
        widget.list.items[idx] = ShoppingListItem(
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
      unawaited(_queueSave());
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
    if (!mounted || name == null || name.isEmpty) return;
    await widget.onSaveTemplate!(
      name,
      List<ShoppingListItem>.from(widget.list.items),
    );
    if (!mounted) return;
    setState(() {
      _templateSignatures.add(signatureFromItems(widget.list.items));
    });
    showTemplateSavedToast(context, name);
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
    unawaited(_queueSave());
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
              onToggle: () => _toggle(item.id),
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
    final items = widget.list.items;
    final checked = items.where((i) => i.isChecked).length;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwner =
        widget.list.ownerId != null &&
        currentUserId != null &&
        widget.list.ownerId == currentUserId;

    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;

    return Scaffold(
      body: GestureDetector(
        onTap: _dismissSuggestions,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            SafeArea(
              child: Column(
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
                                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
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
                                              alignment: Alignment.centerRight,
                                              child: SizedBox(
                                                width: 180,
                                                height:
                                                    AppFieldSize.inlineSearch,
                                                child: TextField(
                                                  controller: _searchController,
                                                  focusNode: _searchFocusNode,
                                                  autofocus: true,
                                                  textAlignVertical:
                                                      TextAlignVertical.center,
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
                                          onPressed: _toggleSearch,
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
                              if (items.isNotEmpty) ...[
                                for (final entry in groupedItems(
                                  widget.list.items,
                                ).entries)
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
                              ] else
                                Padding(
                                  padding: const EdgeInsets.all(40),
                                  child: Center(
                                    child: Text(
                                      'No items in this list',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 8),
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
                            builder: (context, c, r) => const SizedBox.expand(),
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
                            builder: (context, c, r) => const SizedBox.expand(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Row(
                      children: [
                        Text(
                          '$checked of ${items.length} item${items.length == 1 ? '' : 's'} checked',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: checked == items.length && items.isNotEmpty
                                ? theme.colorScheme.primary
                                : null,
                          ),
                        ),
                        const Spacer(),
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
                                      color: theme.colorScheme.onSurfaceVariant,
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
                                      color: theme.colorScheme.onSurfaceVariant,
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
                          onPressed: () => Navigator.pop(context),
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
                          child: Row(
                            children: [
                              Expanded(
                                child: ActionTabButton(
                                  icon: LucideIcons.calendar,
                                  onTap: _pickDate,
                                ),
                              ),
                              Expanded(
                                child: ActionTabButton(
                                  icon: LucideIcons.star,
                                  onTap: _canSaveTemplate
                                      ? _saveAsTemplate
                                      : null,
                                ),
                              ),
                              if (authStateNotifier.value && isOwner)
                                Expanded(
                                  child: ActionTabButton(
                                    icon: _isSharedByMe
                                        ? Icons.link_outlined
                                        : Icons.person_add_outlined,
                                    onTap: _isSharedByMe ? null : _shareList,
                                  ),
                                ),
                              Expanded(
                                child: ActionTabButton(
                                  icon: Icons.euro_outlined,
                                  onTap: _openPriceDialog,
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
            if (_isRecording)
              Positioned.fill(child: RecordingOverlay(onTap: _toggleRecording)),
          ],
        ),
      ),
    );
  }
}
