import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

class HowToPage extends StatefulWidget {
  const HowToPage({super.key});

  @override
  State<HowToPage> createState() => _HowToPageState();
}

class _HowToPageState extends State<HowToPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _menuKey = GlobalKey();
  final GlobalKey _scrollViewKey = GlobalKey();
  late final List<GlobalKey> _sectionKeys;
  int _sectionIndex = 0;

  static const _sections = [
    (
      title: 'Home',
      actions: [
        'Tap Home, History, Wallet to switch tabs.',
        'Tap + to create a new shopping list.',
        'Tap refresh to reload data.',
        'Tap settings to open the settings panel.',
        'Tap stats to open spending statistics.',
        'Tap a list card to open it.',
        'Long press a list card to edit labels.',
        'Swipe left to right to complete a list.',
        'Swipe right to left to delete a list if you are the owner.',
        'Tap the share icon to manage sharing when available.',
      ],
    ),
    (
      title: 'History',
      actions: [
        'Swipe left to right to restore a completed list.',
        'Swipe right to left to delete a completed list if you are the owner.',
        'Tap a completed list to open it.',
        'Long press a completed list to edit labels.',
      ],
    ),
    (
      title: 'Wallet',
      actions: [
        'Tap a code card to open the full-screen viewer.',
        'Tap the code menu to edit or delete a code.',
        'Tap + to add a new code.',
        'Tap camera scan or gallery import.',
        'Tap confirm after naming the code to save it.',
      ],
    ),
    (
      title: 'Create List',
      actions: [
        'Tap the date selector to change the list date.',
        'Tap + to open the add-item popup.',
        'Tap an item checkbox to toggle completion.',
        'Tap an item name to edit it.',
        'Swipe an item right to left to delete it.',
        'Tap the category chevron to change category.',
        'Long press and drag an item to reorder it or move it across categories.',
        'Tap a category header to collapse or expand it.',
        'Tap the category add action to add directly into that category.',
        'Tap the star action to save as template when enabled.',
        'Tap the share action to share the draft when enabled.',
        'Tap the back button to return; confirm save or discard if items exist.',
        'Tap the checkmark to save the list immediately.',
      ],
    ),
    (
      title: 'Saved List',
      actions: [
        'Tap the date selector to change the list date.',
        'Tap + to open the add-item popup.',
        'Tap an item checkbox to toggle completion.',
        'Tap an item name to edit it.',
        'Swipe an item right to left to delete it.',
        'Tap the category chevron to change category.',
        'Long press and drag an item to reorder it or move it across categories.',
        'Drag near the top or bottom edge to auto-scroll the list.',
        'Tap the star action to save as template when enabled.',
        'Tap the share action if you are the owner and sharing is available.',
        'Tap the price action to edit total price and currency.',
      ],
    ),
    (
      title: 'Sharing',
      actions: [
        'Tap a checkbox to share with that user.',
        'Tap a checked checkbox to remove sharing for that user.',
        'Tap close to cancel.',
        'Tap confirm to apply share changes.',
        'Tap Retry if the dialog fails to load.',
      ],
    ),
    (
      title: 'Settings',
      actions: [
        'Tap Appearance to change theme, font size, and font.',
        'Tap Account to sign in or sign out.',
        'Tap About to view the current app version string.',
      ],
    ),
    (
      title: 'Code Viewer',
      actions: [
        'Swipe horizontally to move between saved codes.',
        'Pinch and pan to inspect the current code image.',
        'Tap back to return.',
      ],
    ),
    (
      title: 'QR Scanner',
      actions: [
        'Point the camera at a code to scan it.',
        'Wait for a stable detection to return the captured image.',
        'Tap back to cancel.',
      ],
    ),
    (
      title: 'Spending Stats',
      actions: [
        'Tap the date filters to change the period range.',
        'Tap the period selector to change the statistics interval.',
        'Tap back to return.',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _sectionKeys = List.generate(_sections.length, (_) => GlobalKey());
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final viewportContext = _scrollViewKey.currentContext;
    if (viewportContext == null) {
      return;
    }
    final viewportBox = viewportContext.findRenderObject();
    if (viewportBox is! RenderBox) {
      return;
    }
    final viewportTop = viewportBox.localToGlobal(Offset.zero).dy + 8;
    var nextIndex = 0;
    for (var index = 0; index < _sectionKeys.length; index++) {
      final sectionContext = _sectionKeys[index].currentContext;
      if (sectionContext == null) {
        continue;
      }
      final sectionBox = sectionContext.findRenderObject();
      if (sectionBox is! RenderBox) {
        continue;
      }
      final sectionTop = sectionBox.localToGlobal(Offset.zero).dy;
      if (sectionTop <= viewportTop) {
        nextIndex = index;
      } else {
        break;
      }
    }
    if (nextIndex != _sectionIndex && mounted) {
      setState(() {
        _sectionIndex = nextIndex;
      });
    }
  }

  Future<void> _jumpToSection(int index) async {
    setState(() {
      _sectionIndex = index;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final targetContext = _sectionKeys[index].currentContext;
        if (targetContext == null) {
          return;
        }
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: 0.08,
        );
      });
    });
  }

  Future<void> _openSectionMenu() async {
    final renderBox = _menuKey.currentContext?.findRenderObject();
    if (renderBox is! RenderBox) {
      return;
    }
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final topLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final rect = RelativeRect.fromLTRB(
      topLeft.dx,
      topLeft.dy + renderBox.size.height,
      overlay.size.width - topLeft.dx - renderBox.size.width,
      overlay.size.height - topLeft.dy,
    );
    final selected = await showMenu<int>(
      context: context,
      position: rect,
      constraints: BoxConstraints.tightFor(width: renderBox.size.width),
      items: List.generate(
        _sections.length,
        (index) => PopupMenuItem<int>(
          value: index,
          child: Text(_sections[index].title),
        ),
      ),
    );
    if (selected != null) {
      await _jumpToSection(selected);
    }
  }

  IconData _actionIcon(String action) {
    final lower = action.toLowerCase();
    if (lower.startsWith('tap')) return Icons.touch_app_outlined;
    if (lower.startsWith('swipe')) return Icons.swipe_outlined;
    if (lower.startsWith('long press')) return Icons.pan_tool_outlined;
    if (lower.startsWith('drag')) return Icons.drag_indicator;
    if (lower.startsWith('pinch')) return Icons.zoom_out_map;
    if (lower.startsWith('point')) return LucideIcons.scan_line;
    if (lower.startsWith('wait')) return Icons.hourglass_empty;
    return Icons.radio_button_unchecked;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton.filled(
          onPressed: () => Navigator.pop(context),
          style: IconButton.styleFrom(
            backgroundColor: fillColor,
            foregroundColor: theme.colorScheme.onSurface,
          ),
          tooltip: 'Back',
          icon: const Icon(LucideIcons.chevron_left, size: 22),
        ),
        title: const Text('How to'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    key: _menuKey,
                    onTap: _openSectionMenu,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: const InputDecoration(),
                      child: Row(
                        children: [
                          Expanded(child: Text(_sections[_sectionIndex].title)),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_sectionIndex + 1}/${_sections.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                key: _scrollViewKey,
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: List.generate(_sections.length, (index) {
                    final section = _sections[index];
                    return Padding(
                      key: _sectionKeys[index],
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                section.title,
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 16),
                              ...section.actions.map(
                                (action) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Icon(
                                          _actionIcon(action),
                                          size: 18,
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(child: Text(action)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
