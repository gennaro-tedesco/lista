import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:uuid/uuid.dart';
import '../../models/shopping_list.dart';
import '../../models/shopping_list_item.dart';
import '../../models/shopping_list_template.dart';
import '../../repositories/list_repository.dart';
import '../../widgets/gradient_text.dart';
import '../create_list/create_list_page.dart';
import '../settings/settings_page.dart';
import '../stats/spending_stats_page.dart';
import '../view_list/shopping_list_view_page.dart';

const _uuid = Uuid();

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
  final List<ShoppingList> _lists = [];
  final List<ShoppingListTemplate> _templates = [];
  final List<String> _labelStore = [];
  bool _isCreateMenuOpen = false;
  bool _showHistory = false;
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

  Future<void> _loadData() async {
    final lists = await listRepository.getLists();
    final templates = await listRepository.getTemplates();
    final labels = await listRepository.getLabels();
    if (!mounted) return;
    setState(() {
      _lists.addAll(lists);
      _templates.addAll(templates);
      _labelStore.addAll(labels);
    });
  }

  List<ShoppingList> get _activeLists =>
      _lists.where((list) => !list.isCompleted).toList();

  List<ShoppingList> get _completedLists =>
      _lists.where((list) => list.isCompleted).toList();

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
        _showHistory = false;
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
        _showHistory = false;
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

  Color _labelColor(String label) {
    final index = _labelStore.indexOf(label);
    return _labelColors[(index == -1 ? 0 : index) % _labelColors.length];
  }

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
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        child: Container(
          height: 56,
          color: selected
              ? theme.scaffoldBackgroundColor
              : theme.colorScheme.surface,
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
                  icon == LucideIcons.house ? 'home' : 'history',
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
    for (final l in _lists) {
      for (final label in l.labels) {
        if (!_labelStore.contains(label)) {
          _labelStore.add(label);
        }
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
          if (!_labelStore.contains(label)) {
            _labelStore.add(label);
          }
        },
      ),
    );
    if (result != null && mounted) {
      setState(() {
        list.labels = result;
      });
      unawaited(listRepository.saveList(list));
      unawaited(listRepository.saveLabels(_labelStore));
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

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('images/logo.png', height: 38),
            const SizedBox(width: 8),
            GradientText(
              _showHistory ? 'History' : 'Lista',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          if (_showHistory)
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
        child: _lists.isEmpty
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
            : _showHistory
            ? ListView(
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
            : ListView(
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        width: 320,
        height: 220,
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            if (_templates.isNotEmpty)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                right: 0,
                bottom: _isCreateMenuOpen
                    ? _createButtonBottom +
                        (_createButtonHeight + _createMenuGap) * 2
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
                          backgroundColor: theme.colorScheme.surface,
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
            if (_templates.isNotEmpty)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                right: 0,
                bottom: _isCreateMenuOpen
                    ? _createButtonBottom + _createButtonHeight + _createMenuGap
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
                          backgroundColor: theme.colorScheme.surface,
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
                width: 320,
                height: 56,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildHomeTab(
                        context,
                        icon: LucideIcons.house,
                        selected: !_showHistory,
                        onTap: () {
                          setState(() {
                            _isCreateMenuOpen = false;
                            _showHistory = false;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: _buildHomeTab(
                        context,
                        icon: LucideIcons.history,
                        selected: _showHistory,
                        onTap: () {
                          setState(() {
                            _isCreateMenuOpen = false;
                            _showHistory = true;
                          });
                        },
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
                  onPressed: _handleCreateButton,
                  backgroundColor: theme.colorScheme.surface,
                  foregroundColor: theme.colorScheme.onSurface,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(_isCreateMenuOpen ? Icons.close : Icons.add, size: 18),
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

  const _EditLabelsDialog({
    required this.availableLabels,
    required this.selectedLabels,
    required this.colorForLabel,
    required this.onChanged,
    required this.onLabelCreated,
  });

  @override
  State<_EditLabelsDialog> createState() => _EditLabelsDialogState();
}

class _EditLabelsDialogState extends State<_EditLabelsDialog> {
  late final List<String> _selectedLabels;
  late final List<String> _allLabels;
  final TextEditingController _newLabelController = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Labels'),
      content: SizedBox(
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
                    return GestureDetector(
                      onTap: () => _toggleLabel(label, !selected),
                      child: Container(
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
                      decoration: const InputDecoration(hintText: 'New label'),
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _selectedLabels),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
