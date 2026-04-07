import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/shopping_list.dart';
import '../../models/shopping_list_item.dart';
import '../../models/shopping_list_template.dart';
import '../../models/stored_code.dart';
import '../../repositories/list_repository.dart';
import '../../widgets/gradient_text.dart';
import '../create_list/create_list_page.dart';
import '../settings/settings_page.dart';
import '../stats/spending_stats_page.dart';
import '../view_list/shopping_list_view_page.dart';
import '../wallet/code_viewer_page.dart';
import '../wallet/qr_scanner_page.dart';
import '../wallet/qr_wallet_body.dart';

const _uuid = Uuid();

enum _Tab { home, history, wallet }

class ShoppingListsHomePage extends StatefulWidget {
  const ShoppingListsHomePage({super.key});

  @override
  State<ShoppingListsHomePage> createState() => _ShoppingListsHomePageState();
}

class _ShoppingListsHomePageState extends State<ShoppingListsHomePage> {
  static const _createButtonWidth = 84.0;
  static const _createButtonHeight = 56.0;
  static const _createButtonBottom = 72.0;
  static const _createMenuGap = 12.0;
  static const _createMenuLevels = 2;
  static const _tabStripHeight = 56.0;
  static const _fabOverlayHeight =
      _createButtonBottom +
      _createButtonHeight +
      (_createButtonHeight + _createMenuGap) * _createMenuLevels;
  static const _newListMenuBottom =
      _createButtonBottom + _createButtonHeight + _createMenuGap;
  static const _templateMenuBottom =
      _createButtonBottom +
      (_createButtonHeight + _createMenuGap) * _createMenuLevels;
  final List<ShoppingList> _lists = [];
  final List<ShoppingListTemplate> _templates = [];
  final List<String> _labelStore = [];
  final Map<String, Color> _labelColorMap = {};
  int _labelCounter = 0;
  final List<StoredCode> _codes = [];
  final ScrollController _homeScrollController = ScrollController();
  final ScrollController _historyScrollController = ScrollController();
  bool _isCreateMenuOpen = false;
  _Tab _tab = _Tab.home;
  static const _labelColors = [
    Color(0xFFE57373),
    Color(0xFF64B5F6),
    Color(0xFF81C784),
    Color(0xFFFFB74D),
    Color(0xFFBA68C8),
    Color(0xFF4DB6AC),
    Color(0xFFA1887F),
    Color(0xFF90A4AE),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _homeScrollController.dispose();
    _historyScrollController.dispose();
    super.dispose();
  }

  void _selectTab(_Tab tab) {
    setState(() {
      _isCreateMenuOpen = false;
      _tab = tab;
    });
  }

  Future<void> _loadData() async {
    final lists = await listRepository.getLists();
    final templates = await listRepository.getTemplates();
    final labels = await listRepository.getLabels();
    final codes = await listRepository.getCodes();
    if (!mounted) return;
    setState(() {
      _lists.addAll(lists);
      _templates.addAll(templates);
      for (final label in labels) {
        _addLabel(label);
      }
      _codes.addAll(codes);
    });
  }

  List<ShoppingList> get _activeLists =>
      (_lists.where((list) => !list.isCompleted).toList()
        ..sort((a, b) => b.date.compareTo(a.date)));

  List<ShoppingList> get _completedLists =>
      (_lists.where((list) => list.isCompleted).toList()
        ..sort((a, b) => b.date.compareTo(a.date)));

  Future<void> _openCreateList() async {
    setState(() => _isCreateMenuOpen = false);
    final result = await Navigator.push<ShoppingList>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateListPage(
          onSaveTemplate: _saveTemplate,
          existingTemplates: _templates,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _tab = _Tab.home;
        _lists.add(result);
      });
      unawaited(listRepository.saveList(result));
    }
  }

  Future<void> _openCreateListFromTemplate(
    ShoppingListTemplate template,
  ) async {
    setState(() => _isCreateMenuOpen = false);
    final result = await Navigator.push<ShoppingList>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateListPage(
          onSaveTemplate: _saveTemplate,
          existingTemplates: _templates,
          initialItems: template.items
              .map(
                (item) => ShoppingListItem(
                  id: _uuid.v4(),
                  name: item.name,
                  quantity: item.quantity,
                  category: item.category,
                ),
              )
              .toList(),
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _tab = _Tab.home;
        _lists.add(result);
      });
      unawaited(listRepository.saveList(result));
    }
  }

  Future<void> _saveTemplate(String name, List<ShoppingListItem> items) async {
    final template = ShoppingListTemplate(
      id: _uuid.v4(),
      name: name,
      items: items
          .map(
            (item) => ShoppingListTemplateItem(
              name: item.name,
              quantity: item.quantity,
              category: item.category,
            ),
          )
          .toList(),
    );
    setState(() => _templates.add(template));
    unawaited(listRepository.saveTemplate(template));
  }

  void _addLabel(String label) {
    if (!_labelStore.contains(label)) {
      _labelColorMap[label] = _labelColors[_labelCounter % _labelColors.length];
      _labelStore.add(label);
      _labelCounter++;
    }
  }

  Color _labelColor(String label) => _labelColorMap[label] ?? _labelColors[0];

  Widget _buildListCard(BuildContext context, ShoppingList list) {
    final theme = Theme.of(context);
    final checked = list.items.where((it) => it.isChecked).length;
    final total = list.items.length;
    final showPrice = list.totalPrice != null;
    final currencySymbol = list.currencySymbol;
    const prefixSymbols = ['\$', '£'];
    final formattedPrice = list.totalPrice == null
        ? ''
        : prefixSymbols.contains(currencySymbol)
        ? '$currencySymbol${list.totalPrice}'
        : '${list.totalPrice}$currencySymbol';
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _viewList(list),
        onLongPress: () => _editLabels(list),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(list.date),
                    style: theme.textTheme.bodySmall,
                  ),
                  if (total > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '$checked / $total items',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: checked == total
                            ? theme.colorScheme.primary
                            : null,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  children: list.labels
                      .map(
                        (label) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _labelColor(label),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              if (showPrice) ...[
                const SizedBox(width: 8),
                Text(
                  formattedPrice,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTab(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        child: Container(
          height: 56,
          color: selected ? theme.scaffoldBackgroundColor : fillColor,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selected
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _viewList(ShoppingList list) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShoppingListViewPage(
          list: list,
          onSaveTemplate: _saveTemplate,
          existingTemplates: _templates,
        ),
      ),
    );
    unawaited(listRepository.saveList(list));
    setState(() {});
  }

  Future<void> _openTemplates() async {
    setState(() => _isCreateMenuOpen = false);
    if (_templates.isEmpty) {
      return;
    }
    final template = await showDialog<ShoppingListTemplate>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Templates'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: _templates
                  .map(
                    (template) => Dismissible(
                      key: ValueKey(template.id),
                      direction: DismissDirection.endToStart,
                      background: Container(color: Colors.transparent),
                      secondaryBackground: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Icon(
                          Icons.delete,
                          color: Theme.of(context).colorScheme.onError,
                        ),
                      ),
                      onDismissed: (_) {
                        setDialogState(() {
                          _templates.remove(template);
                        });
                        unawaited(listRepository.deleteTemplate(template.id));
                        if (_templates.isEmpty && mounted) {
                          Navigator.pop(context);
                        }
                      },
                      child: ListTile(
                        title: Text(template.name),
                        subtitle: Text(
                          '${template.items.length} item${template.items.length == 1 ? '' : 's'}',
                        ),
                        onLongPress: () async {
                          final controller = TextEditingController(
                            text: template.name,
                          );
                          final renamed = await showDialog<String>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Rename template'),
                              content: TextField(
                                controller: controller,
                                autofocus: true,
                                textCapitalization:
                                    TextCapitalization.sentences,
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
                                  onPressed: () => Navigator.pop(
                                    context,
                                    controller.text.trim(),
                                  ),
                                  child: const Text('Save'),
                                ),
                              ],
                            ),
                          );
                          if (renamed != null && renamed.isNotEmpty) {
                            final updated = ShoppingListTemplate(
                              id: template.id,
                              name: renamed,
                              items: template.items,
                            );
                            setDialogState(() {
                              final index = _templates.indexWhere(
                                (item) => item.id == template.id,
                              );
                              if (index != -1) _templates[index] = updated;
                            });
                            unawaited(listRepository.saveTemplate(updated));
                          }
                        },
                        onTap: () => Navigator.pop(context, template),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
    if (!mounted || template == null) {
      if (mounted) {
        setState(() {});
      }
      return;
    }
    setState(() {});
    await _openCreateListFromTemplate(template);
  }

  void _handleCreateButton() {
    if (_templates.isEmpty) {
      _openCreateList();
      return;
    }
    setState(() {
      _isCreateMenuOpen = !_isCreateMenuOpen;
    });
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
    setState(() {});
  }

  Future<void> _openStats() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SpendingStatsPage(lists: _lists)),
    );
    setState(() {});
  }

  void _deleteList(ShoppingList list) {
    setState(() {
      _lists.remove(list);
    });
    unawaited(listRepository.deleteList(list.id));
  }

  void _toggleCompleted(ShoppingList list) {
    setState(() {
      list.isCompleted = !list.isCompleted;
    });
    unawaited(listRepository.saveList(list));
  }

  Future<void> _editLabels(ShoppingList list) async {
    bool labelDeleted = false;
    for (final l in _lists) {
      for (final label in l.labels) {
        _addLabel(label);
      }
    }
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => _EditLabelsDialog(
        availableLabels: _labelStore,
        selectedLabels: list.labels,
        colorForLabel: _labelColor,
        onChanged: (labels) {
          setState(() {
            list.labels = labels;
          });
        },
        onLabelCreated: (label) {
          _addLabel(label);
          unawaited(listRepository.saveLabels(_labelStore));
        },
        onLabelDeleted: (label) {
          setState(() {
            _labelStore.remove(label);
            _labelColorMap.remove(label);
            for (final list in _lists) {
              list.labels.remove(label);
            }
          });
          labelDeleted = true;
          unawaited(listRepository.saveLabels(_labelStore));
        },
      ),
    );
    if (result != null && mounted) {
      setState(() {
        list.labels = result;
      });
      unawaited(listRepository.saveList(list));
      unawaited(listRepository.saveLabels(_labelStore));
      if (labelDeleted) {
        for (final item in _lists) {
          unawaited(listRepository.saveList(item));
        }
      }
    }
  }

  Future<bool> _handleListSwipe(
    DismissDirection direction,
    ShoppingList list,
  ) async {
    if (direction == DismissDirection.startToEnd) {
      _toggleCompleted(list);
    } else {
      _deleteList(list);
    }
    return false;
  }

  Future<void> _addCode() async {
    final choice = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.scan_line),
              title: const Text('Scan with camera'),
              onTap: () => Navigator.pop(context, true),
            ),
            ListTile(
              leading: const Icon(LucideIcons.image),
              title: const Text('Import from gallery'),
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    Uint8List? imageBytes;
    if (choice) {
      imageBytes = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(builder: (_) => const QrScannerPage()),
      );
    } else {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file != null) imageBytes = await file.readAsBytes();
    }

    if (imageBytes == null || !mounted) return;

    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name this code'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'e.g. Loyalty card'),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
    });

    if (name == null || name.isEmpty || !mounted) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final id = const Uuid().v4();
      final codesDir = Directory('${dir.path}/qr_codes');
      if (!await codesDir.exists()) await codesDir.create(recursive: true);
      final imagePath = '${codesDir.path}/$id.png';
      await File(imagePath).writeAsBytes(imageBytes);
      final code = StoredCode(
        id: id,
        name: name,
        imagePath: imagePath,
        createdAt: DateTime.now(),
      );
      if (!mounted) return;
      setState(() => _codes.add(code));
      unawaited(listRepository.saveCode(code));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to save code')));
    }
  }

  Future<void> _viewCode(StoredCode code) async {
    final index = _codes.indexWhere((item) => item.id == code.id);
    if (index == -1) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CodeViewerPage(codes: _codes, initialIndex: index),
      ),
    );
  }

  Future<void> _editCode(StoredCode code) async {
    final controller = TextEditingController(text: code.name);
    final renamed = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Code name'),
          onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(Icons.close),
          ),
          IconButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            icon: const Icon(Icons.check),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
    if (renamed == null || renamed.isEmpty || !mounted) return;
    setState(() => code.name = renamed);
    unawaited(listRepository.saveCode(code));
  }

  Future<void> _confirmDeleteCode(StoredCode code) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${code.name}?'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(ctx, false),
            icon: const Icon(Icons.close),
          ),
          IconButton(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _codes.remove(code));
    unawaited(listRepository.deleteCode(code.id));
    try {
      final file = File(code.imagePath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;
    final overlayWidth = MediaQuery.sizeOf(context).width - 32;

    final appBarTitle = switch (_tab) {
      _Tab.home => 'Lista',
      _Tab.history => 'History',
      _Tab.wallet => 'Wallet',
    };

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('images/logo.png', height: 38),
            const SizedBox(width: 8),
            GradientText(
              appBarTitle,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          if (_tab == _Tab.history)
            IconButton(
              icon: const Icon(Icons.bar_chart_rounded),
              tooltip: 'Statistics',
              onPressed: _openStats,
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          if (_isCreateMenuOpen) {
            setState(() => _isCreateMenuOpen = false);
          }
        },
        behavior: HitTestBehavior.translucent,
        child: _tab == _Tab.wallet
            ? QrWalletBody(
                codes: _codes,
                onView: _viewCode,
                onEdit: _editCode,
                onDelete: _confirmDeleteCode,
              )
            : _lists.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shopping_basket_outlined,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No lists yet',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap + to create one',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              )
            : _tab == _Tab.history
            ? Scrollbar(
                controller: _historyScrollController,
                thumbVisibility: true,
                child: ListView(
                  controller: _historyScrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  children: [
                    if (_completedLists.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 80),
                        child: Center(
                          child: Text(
                            'No completed lists',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    else
                      for (final list in _completedLists)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Dismissible(
                            key: ValueKey('completed-${list.id}'),
                            background: Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondary,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Icon(
                                Icons.undo,
                                color: theme.colorScheme.onSecondary,
                              ),
                            ),
                            secondaryBackground: Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.error,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Icon(
                                Icons.delete,
                                color: theme.colorScheme.onError,
                              ),
                            ),
                            confirmDismiss: (direction) =>
                                _handleListSwipe(direction, list),
                            child: _buildListCard(context, list),
                          ),
                        ),
                  ],
                ),
              )
            : _activeLists.isEmpty
            ? Center(
                child: Text(
                  'No active lists',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : Scrollbar(
                controller: _homeScrollController,
                thumbVisibility: true,
                child: ListView(
                  controller: _homeScrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  children: [
                    for (final list in _activeLists)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Dismissible(
                          key: ValueKey(list.id),
                          background: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Icon(
                              Icons.check,
                              color: theme.colorScheme.onSecondary,
                            ),
                          ),
                          secondaryBackground: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Icon(
                              Icons.delete,
                              color: theme.colorScheme.onError,
                            ),
                          ),
                          confirmDismiss: (direction) =>
                              _handleListSwipe(direction, list),
                          child: _buildListCard(context, list),
                        ),
                      ),
                  ],
                ),
              ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        width: overlayWidth,
        height: _fabOverlayHeight,
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            if (_tab != _Tab.wallet && _templates.isNotEmpty)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                right: 0,
                bottom: _isCreateMenuOpen
                    ? _templateMenuBottom
                    : _createButtonBottom,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 180),
                  scale: _isCreateMenuOpen ? 1 : 0.7,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 140),
                    opacity: _isCreateMenuOpen ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !_isCreateMenuOpen,
                      child: SizedBox(
                        width: _createButtonWidth,
                        height: _createButtonHeight,
                        child: FloatingActionButton(
                          heroTag: 'from_template',
                          onPressed: _openTemplates,
                          backgroundColor: fillColor,
                          foregroundColor: theme.colorScheme.onSurface,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.star, size: 18),
                              const SizedBox(height: 2),
                              Text(
                                'templates',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_tab != _Tab.wallet && _templates.isNotEmpty)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                right: 0,
                bottom: _isCreateMenuOpen
                    ? _newListMenuBottom
                    : _createButtonBottom,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 180),
                  scale: _isCreateMenuOpen ? 1 : 0.7,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 140),
                    opacity: _isCreateMenuOpen ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !_isCreateMenuOpen,
                      child: SizedBox(
                        width: _createButtonWidth,
                        height: _createButtonHeight,
                        child: FloatingActionButton(
                          heroTag: 'new_list_option',
                          onPressed: _openCreateList,
                          backgroundColor: fillColor,
                          foregroundColor: theme.colorScheme.onSurface,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Image.asset(
                                  'images/logo.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'new',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: overlayWidth,
                height: _tabStripHeight,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildHomeTab(
                        context,
                        icon: LucideIcons.house,
                        label: 'home',
                        selected: _tab == _Tab.home,
                        onTap: () => _selectTab(_Tab.home),
                      ),
                    ),
                    Expanded(
                      child: _buildHomeTab(
                        context,
                        icon: LucideIcons.history,
                        label: 'history',
                        selected: _tab == _Tab.history,
                        onTap: () => _selectTab(_Tab.history),
                      ),
                    ),
                    Expanded(
                      child: _buildHomeTab(
                        context,
                        icon: LucideIcons.wallet,
                        label: 'wallet',
                        selected: _tab == _Tab.wallet,
                        onTap: () => _selectTab(_Tab.wallet),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: _createButtonBottom,
              child: SizedBox(
                width: _createButtonWidth,
                height: _createButtonHeight,
                child: FloatingActionButton(
                  heroTag: 'new_list',
                  onPressed: _tab == _Tab.wallet
                      ? _addCode
                      : _handleCreateButton,
                  backgroundColor: fillColor,
                  foregroundColor: theme.colorScheme.onSurface,
                  child: _tab == _Tab.wallet
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(Icons.add, size: 18),
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 35,
                              height: 35,
                              child: OverflowBox(
                                maxWidth: 88,
                                maxHeight: 88,
                                child: Icon(LucideIcons.qr_code, size: 30),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              _isCreateMenuOpen ? Icons.close : Icons.add,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 35,
                              height: 35,
                              child: OverflowBox(
                                maxWidth: 88,
                                maxHeight: 88,
                                child: SizedBox(
                                  width: 45,
                                  height: 45,
                                  child: Image.asset(
                                    'images/logo.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditLabelsDialog extends StatefulWidget {
  final List<String> availableLabels;
  final List<String> selectedLabels;
  final Color Function(String label) colorForLabel;
  final ValueChanged<List<String>> onChanged;
  final ValueChanged<String> onLabelCreated;
  final ValueChanged<String> onLabelDeleted;

  const _EditLabelsDialog({
    required this.availableLabels,
    required this.selectedLabels,
    required this.colorForLabel,
    required this.onChanged,
    required this.onLabelCreated,
    required this.onLabelDeleted,
  });

  @override
  State<_EditLabelsDialog> createState() => _EditLabelsDialogState();
}

class _EditLabelsDialogState extends State<_EditLabelsDialog> {
  late final List<String> _selectedLabels;
  late final List<String> _allLabels;
  final TextEditingController _newLabelController = TextEditingController();
  BuildContext? _contentContext;

  @override
  void initState() {
    super.initState();
    _selectedLabels = List<String>.from(widget.selectedLabels);
    _allLabels = ({...widget.availableLabels, ..._selectedLabels}).toList();
  }

  @override
  void dispose() {
    _newLabelController.dispose();
    super.dispose();
  }

  void _toggleLabel(String label, bool selected) {
    setState(() {
      if (selected) {
        if (!_selectedLabels.contains(label)) {
          _selectedLabels.add(label);
        }
      } else {
        _selectedLabels.remove(label);
      }
    });
    widget.onChanged(List<String>.from(_selectedLabels));
  }

  void _addNewLabel() {
    final label = _newLabelController.text.trim();
    if (label.isEmpty) return;
    widget.onLabelCreated(label);
    setState(() {
      if (!_allLabels.contains(label)) {
        _allLabels.add(label);
      }
      if (!_selectedLabels.contains(label)) {
        _selectedLabels.add(label);
      }
    });
    widget.onChanged(List<String>.from(_selectedLabels));
    _newLabelController.clear();
  }

  void _deleteLabel(String label) {
    setState(() {
      _allLabels.remove(label);
      _selectedLabels.remove(label);
    });
    widget.onChanged(List<String>.from(_selectedLabels));
    widget.onLabelDeleted(label);
  }

  bool _isOutsidePopup(Offset offset) {
    final renderObject = _contentContext?.findRenderObject();
    if (renderObject is! RenderBox) return false;
    final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    return !rect.contains(offset);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Labels'),
      content: Builder(
        builder: (contentContext) {
          _contentContext = contentContext;
          return SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_allLabels.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _allLabels.map((label) {
                        final selected = _selectedLabels.contains(label);
                        final color = widget.colorForLabel(label);
                        final chip = Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? color
                                : color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: color, width: 1.5),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: selected ? Colors.white : color,
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        );
                        return Draggable<String>(
                          data: label,
                          feedback: Material(
                            color: Colors.transparent,
                            child: chip,
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.25,
                            child: chip,
                          ),
                          onDragEnd: (details) {
                            if (_isOutsidePopup(details.offset)) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  _deleteLabel(label);
                                }
                              });
                            }
                          },
                          child: GestureDetector(
                            onTap: () => _toggleLabel(label, !selected),
                            child: chip,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newLabelController,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'New label',
                          ),
                          onSubmitted: (_) => _addNewLabel(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check),
                        onPressed: _addNewLabel,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
