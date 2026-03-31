import 'package:flutter/material.dart';
import '../../app/themes.dart';
import '../../models/shopping_list.dart';
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
  int? _draggingListIndex;
  int? _listDropIndex;

  List<ShoppingList> get _activeLists =>
      _lists.where((list) => !list.isCompleted).toList();

  List<ShoppingList> get _completedLists =>
      _lists.where((list) => list.isCompleted).toList();

  Future<void> _openCreateList() async {
    final result = await Navigator.push<ShoppingList>(
      context,
      MaterialPageRoute(builder: (_) => const CreateListPage()),
    );
    if (result != null) {
      setState(() => _lists.add(result));
    }
  }

  void _reorderLists(int oldIndex, int newIndex) {
    setState(() {
      final activeLists = _activeLists;
      final list = activeLists[oldIndex];
      final oldListIndex = _lists.indexOf(list);
      _lists.removeAt(oldListIndex);
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      if (newIndex >= activeLists.length) {
        final firstCompletedIndex =
            _lists.indexWhere((item) => item.isCompleted);
        if (firstCompletedIndex == -1) {
          _lists.add(list);
        } else {
          _lists.insert(firstCompletedIndex, list);
        }
      } else {
        final targetList = activeLists[newIndex];
        final targetListIndex = _lists.indexOf(targetList);
        _lists.insert(targetListIndex, list);
      }
      _draggingListIndex = null;
      _listDropIndex = null;
    });
  }

  Widget _buildListDropZone(int index) {
    final isActive = _listDropIndex == index;
    return DragTarget<int>(
      onWillAccept: (data) {
        if (data == null || data == index) {
          return false;
        }
        setState(() {
          _listDropIndex = index;
        });
        return true;
      },
      onLeave: (_) {
        if (_listDropIndex == index) {
          setState(() {
            _listDropIndex = null;
          });
        }
      },
      onAcceptWithDetails: (details) {
        _reorderLists(details.data, index);
      },
      builder: (context, candidateData, rejectedData) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: isActive ? 20 : 8,
      ),
    );
  }

  Widget _buildListCard(BuildContext context, ShoppingList list) {
    final theme = Theme.of(context);
    final checked = list.items.where((it) => it.isChecked).length;
    final total = list.items.length;
    final showPrice = list.isCompleted && list.totalPrice != null;
    final currencySymbol = list.currencySymbol;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _viewList(list),
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
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: list.isCompleted
                            ? theme.colorScheme.onSurfaceVariant
                            : null,
                      ),
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
                    if (list.totalPrice != null && !showPrice) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$currencySymbol${list.totalPrice!}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              if (showPrice)
                Text(
                  '$currencySymbol${list.totalPrice!}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _viewList(ShoppingList list) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ShoppingListViewPage(list: list)),
    );
    setState(() {});
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

  Future<bool> _handleActiveListSwipe(
      DismissDirection direction, ShoppingList list) async {
    if (direction == DismissDirection.startToEnd) {
      _toggleCompleted(list);
    } else {
      _deleteList(list);
    }
    return false;
  }

  Future<bool> _handleCompletedListSwipe(
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
                                    color: theme.colorScheme.onPrimary,
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
                                    _handleCompletedListSwipe(direction, list),
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
        title: const Text('Lista'),
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
                      for (var i = 0; i < _activeLists.length; i++) ...[
                        _buildListDropZone(i),
                        LongPressDraggable<int>(
                          data: i,
                          onDragStarted: () {
                            setState(() {
                              _draggingListIndex = i;
                            });
                          },
                          onDragEnd: (_) {
                            setState(() {
                              _draggingListIndex = null;
                              _listDropIndex = null;
                            });
                          },
                          feedback: Material(
                            color: Colors.transparent,
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width - 32,
                              child: _buildListCard(context, _activeLists[i]),
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.2,
                            child: _buildListCard(context, _activeLists[i]),
                          ),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 120),
                            opacity: _draggingListIndex == i ? 0.9 : 1,
                            child: Dismissible(
                              key: ValueKey(_activeLists[i].id),
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
                                  color: theme.colorScheme.onPrimary,
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
                                  _handleActiveListSwipe(
                                      direction, _activeLists[i]),
                              child: _buildListCard(context, _activeLists[i]),
                            ),
                          ),
                        ),
                      ],
                      _buildListDropZone(_activeLists.length),
                    ],
                  ),
                ),
                completedSection,
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateList,
        icon: const Icon(Icons.playlist_add),
        label: const Text('New List'),
      ),
    );
  }
}
