import 'package:flutter/material.dart';
import '../../app/themes.dart';
import '../../models/shopping_list.dart';
import '../create_list/create_list_page.dart';
import '../view_list/shopping_list_view_page.dart';

class ShoppingListsHomePage extends StatefulWidget {
  const ShoppingListsHomePage({super.key});

  @override
  State<ShoppingListsHomePage> createState() => _ShoppingListsHomePageState();
}

class _ShoppingListsHomePageState extends State<ShoppingListsHomePage> {
  final List<ShoppingList> _lists = [];

  List<ShoppingList> get _sortedLists =>
      [..._lists]..sort((a, b) => b.date.compareTo(a.date));

  Future<void> _openCreateList() async {
    final result = await Navigator.push<ShoppingList>(
      context,
      MaterialPageRoute(builder: (_) => const CreateListPage()),
    );
    if (result != null) {
      setState(() => _lists.add(result));
    }
  }

  Future<void> _viewList(ShoppingList list) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ShoppingListViewPage(list: list)),
    );
    setState(() {});
  }

  Future<void> _editListName(ShoppingList list) async {
    final controller = TextEditingController(text: list.title ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('List name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'List title (optional)'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) {
      setState(() {
        list.title = result.trim().isEmpty ? null : result.trim();
      });
    }
  }

  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ValueListenableBuilder<AppThemeOption>(
        valueListenable: themeNotifier,
        builder: (context, current, child) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Theme',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
            ),
            ...AppThemeOption.values.map(
              (option) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: option.swatch,
                  radius: 10,
                ),
                title: Text(option.label),
                trailing: current == option
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(ctx).colorScheme.primary,
                        size: 20,
                      )
                    : null,
                onTap: () {
                  themeNotifier.value = option;
                  Navigator.pop(ctx);
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
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
    final sorted = _sortedLists;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista'),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            onPressed: _showThemePicker,
            tooltip: 'Theme',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: sorted.isEmpty
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
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: sorted.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final list = sorted[i];
                final checked =
                    list.items.where((it) => it.isChecked).length;
                final total = list.items.length;
                return Card(
                  child: InkWell(
                    onTap: () => _viewList(list),
                    onLongPress: () => _editListName(list),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  list.title ?? 'Shopping List',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
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
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateList,
        icon: const Icon(Icons.playlist_add),
        label: const Text('New List'),
      ),
    );
  }
}
