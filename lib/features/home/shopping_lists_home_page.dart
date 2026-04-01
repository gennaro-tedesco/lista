import 'package:flutter/material.dart';
import '../../models/shopping_list.dart';
import '../../models/shopping_list_item.dart';
import '../../models/shopping_list_template.dart';
import '../create_list/create_list_page.dart';
import '../settings/settings_page.dart';
import '../view_list/shopping_list_view_page.dart';

class ShoppingListsHomePage extends StatefulWidget {
  const ShoppingListsHomePage({super.key});

  @override
  State<ShoppingListsHomePage> createState() => _ShoppingListsHomePageState();
}

class _ShoppingListsHomePageState extends State<ShoppingListsHomePage> {
  final List<ShoppingList> _lists = [];
  final List<ShoppingListTemplate> _templates = [];
  final List<String> _labelStore = [];
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

  List<ShoppingList> get _activeLists =>
      _lists.where((list) => !list.isCompleted).toList();

  List<ShoppingList> get _completedLists =>
      _lists.where((list) => list.isCompleted).toList();

  Future<void> _openCreateList() async {
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
      setState(() => _lists.add(result));
    }
  }

  Future<void> _openCreateListFromTemplate(ShoppingListTemplate template) async {
    final result = await Navigator.push<ShoppingList>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateListPage(
          onSaveTemplate: _saveTemplate,
          existingTemplates: _templates,
          initialItems: template.items
              .asMap()
              .entries
              .map(
                (entry) => ShoppingListItem(
                  id: '${DateTime.now().microsecondsSinceEpoch}-${entry.key}',
                  name: entry.value.name,
                  quantity: entry.value.quantity,
                  category: entry.value.category,
                ),
              )
              .toList(),
        ),
      ),
    );
    if (result != null) {
      setState(() => _lists.add(result));
    }
  }

  Future<void> _saveTemplate(String name, List<ShoppingListItem> items) async {
    setState(() {
      _templates.add(
        ShoppingListTemplate(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
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
        ),
      );
    });
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
    setState(() {});
  }

  Future<void> _openTemplates() async {
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
                          final controller =
                              TextEditingController(text: template.name);
                          final renamed = await showDialog<String>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Rename template'),
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
                            setDialogState(() {
                              final index = _templates.indexWhere(
                                (item) => item.id == template.id,
                              );
                              if (index != -1) {
                                _templates[index] = ShoppingListTemplate(
                                  id: template.id,
                                  name: renamed,
                                  items: template.items,
                                );
                              }
                            });
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

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
    setState(() {});
  }

  void _deleteList(ShoppingList list) {
    setState(() {
      _lists.remove(list);
    });
  }

  void _toggleCompleted(ShoppingList list) {
    setState(() {
      list.isCompleted = !list.isCompleted;
    });
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
    }
  }

  Future<bool> _handleListSwipe(
      DismissDirection direction, ShoppingList list) async {
    if (direction == DismissDirection.startToEnd) {
      _toggleCompleted(list);
    } else {
      _deleteList(list);
    }
    return false;
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completedSection = _completedLists.isEmpty
        ? const SizedBox.shrink()
        : SafeArea(
            top: false,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Completed',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      reverse: true,
                      children: _completedLists
                          .map(
                            (list) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Dismissible(
                                key: ValueKey('completed-${list.id}'),
                                background: Container(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondary,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  alignment: Alignment.centerLeft,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 20),
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
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 20),
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
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          );

    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'images/home_title.png',
          height: 100,
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _lists.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shopping_basket_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.35),
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
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      _completedLists.isEmpty ? 96 : 16,
                    ),
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
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
                completedSection,
              ],
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Opacity(
              opacity: _templates.isNotEmpty ? 1.0 : 0.35,
              child: SizedBox(
                width: 56,
                height: 56,
                child: FloatingActionButton(
                  heroTag: 'templates',
                  onPressed: _templates.isNotEmpty ? _openTemplates : null,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  child: Image.asset('images/templates.png', width: 32, height: 32),
                ),
              ),
            ),
            SizedBox(
              width: 84,
              height: 56,
              child: FloatingActionButton(
                heroTag: 'new_list',
                onPressed: _openCreateList,
                backgroundColor: Theme.of(context).colorScheme.surface,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                child: Row(
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
  final TextEditingController _newLabelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedLabels = List<String>.from(widget.selectedLabels);
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
      if (!_selectedLabels.contains(label)) {
        _selectedLabels.add(label);
      }
    });
    widget.onChanged(List<String>.from(_selectedLabels));
    _newLabelController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final allLabels = ({...widget.availableLabels, ..._selectedLabels}).toList();
    return AlertDialog(
      title: const Text('Labels'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (allLabels.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allLabels.map((label) {
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
                          color: selected ? color : color.withValues(alpha: 0.12),
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
