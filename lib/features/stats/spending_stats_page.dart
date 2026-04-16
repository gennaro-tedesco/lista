import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../widgets/gradient_text.dart';
import 'dart:math' as math;
import '../../models/shopping_list.dart';
import '../../services/spending_stats_service.dart';
import '../../utils/label_colors.dart';
import '../../widgets/date_selector_field.dart';

class SpendingStatsPage extends StatefulWidget {
  final List<ShoppingList> lists;

  const SpendingStatsPage({super.key, required this.lists});

  @override
  State<SpendingStatsPage> createState() => _SpendingStatsPageState();
}

class _SpendingStatsPageState extends State<SpendingStatsPage> {
  late DateTime _startDate;
  late String? _selectedCurrency;
  late Set<String> _selectedLabels;
  GroupBy _groupBy = GroupBy.none;
  final _labelKey = GlobalKey();
  final _currencyKey = GlobalKey();
  OverlayEntry? _labelOverlay;

  List<String> get _currencies {
    final values =
        widget.lists
            .where((list) => list.isCompleted && list.totalPrice != null)
            .map((list) => list.currencySymbol)
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  List<String> get _availableLabels {
    final values =
        widget.lists
            .expand((list) => list.labels)
            .where((label) => label.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  @override
  void initState() {
    super.initState();
    final completedDates =
        widget.lists
            .where((list) => list.isCompleted)
            .map((list) => list.date)
            .toList()
          ..sort();
    _startDate = completedDates.isEmpty
        ? DateTime.now()
        : DateTime(
            completedDates.first.year,
            completedDates.first.month,
            completedDates.first.day,
          );
    _selectedCurrency = _currencies.isEmpty ? null : _currencies.first;
    _selectedLabels = _availableLabels.toSet();
  }

  @override
  void didUpdateWidget(covariant SpendingStatsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldLabels = oldWidget.lists
        .expand((list) => list.labels)
        .where((label) => label.trim().isNotEmpty)
        .toSet();
    final newLabels = _availableLabels.toSet();
    final hadAllSelected = _selectedLabels.length == oldLabels.length;
    _selectedLabels = _selectedLabels.intersection(newLabels);
    if (hadAllSelected) {
      _selectedLabels = newLabels;
    } else {
      _selectedLabels.addAll(newLabels.difference(oldLabels));
    }
    if (_selectedCurrency != null && !_currencies.contains(_selectedCurrency)) {
      _selectedCurrency = _currencies.isEmpty ? null : _currencies.first;
    }
  }

  @override
  void dispose() {
    _removeLabelOverlay();
    super.dispose();
  }

  String _formatAmount(double value, String currencySymbol) {
    final rounded = value.toStringAsFixed(
      value.truncateToDouble() == value ? 0 : 2,
    );
    const prefixSymbols = ['\$', '£'];
    return prefixSymbols.contains(currencySymbol)
        ? '$currencySymbol$rounded'
        : '$rounded$currencySymbol';
  }

  static const _months = [
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

  String _formatChartLabel(DateTime key) {
    final yy = (key.year % 100).toString().padLeft(2, '0');
    return switch (_groupBy) {
      GroupBy.month => '${_months[key.month - 1]} $yy',
      GroupBy.week || GroupBy.none => '${key.day} ${_months[key.month - 1]}',
    };
  }

  String _formatTableLabel(DateTime key) {
    final yy = (key.year % 100).toString().padLeft(2, '0');
    return switch (_groupBy) {
      GroupBy.month => '${_months[key.month - 1]} $yy',
      GroupBy.week ||
      GroupBy.none => '${key.day} ${_months[key.month - 1]} $yy',
    };
  }

  double _niceStep(double maxValue) {
    if (maxValue <= 0) return 1;
    final roughStep = maxValue / 4;
    final magnitude = math
        .pow(10, (math.log(roughStep) / math.ln10).floor())
        .toDouble();
    final normalized = roughStep / magnitude;
    if (normalized <= 1) return magnitude;
    if (normalized <= 2) return 2 * magnitude;
    if (normalized <= 5) return 5 * magnitude;
    return 10 * magnitude;
  }

  Widget _buildChart(
    BuildContext context,
    SpendingStats stats,
    String currency,
  ) {
    final theme = Theme.of(context);
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;
    final rawMaxValue = stats.buckets.isEmpty
        ? 1.0
        : stats.buckets.map((b) => b.total).reduce((a, b) => a > b ? a : b);
    final step = _niceStep(rawMaxValue);
    final maxValue = rawMaxValue <= 0
        ? 1.0
        : (rawMaxValue / step).ceil() * step;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox(
        height: 240,
        child: BarChart(
          BarChartData(
            maxY: maxValue <= 0 ? 1 : maxValue,
            alignment: BarChartAlignment.spaceAround,
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: step,
              getDrawingHorizontalLine: (value) => FlLine(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(enabled: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 52,
                  interval: step,
                  getTitlesWidget: (value, meta) => Text(
                    _formatAmount(value, currency),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= stats.buckets.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _formatChartLabel(stats.buckets[index].key),
                        style: theme.textTheme.bodySmall,
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < stats.buckets.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: stats.buckets[i].total,
                      width: 22,
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTable(
    BuildContext context,
    SpendingStats stats,
    String currency,
  ) {
    final theme = Theme.of(context);
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;

    const colWidths = <int, TableColumnWidth>{
      0: FlexColumnWidth(1.4),
      1: FlexColumnWidth(1),
      2: FlexColumnWidth(1),
      3: FlexColumnWidth(1),
    };

    const cellPad = EdgeInsets.symmetric(horizontal: 8, vertical: 10);

    Widget cell(
      String text, {
      TextAlign align = TextAlign.right,
      TextStyle? style,
    }) => Padding(
      padding: cellPad,
      child: Text(
        text,
        textAlign: align,
        style: style,
        overflow: TextOverflow.ellipsis,
      ),
    );

    BorderSide sep(double alpha, {double width = 1}) => BorderSide(
      color: theme.colorScheme.outline.withValues(alpha: alpha),
      width: width,
    );

    final headerStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final bodyStyle = theme.textTheme.bodySmall;
    final boldStyle = bodyStyle?.copyWith(fontWeight: FontWeight.w600);

    final headerRow = TableRow(
      decoration: BoxDecoration(border: Border(bottom: sep(0.25))),
      children: [
        cell('Period', align: TextAlign.left, style: headerStyle),
        cell('Total', style: headerStyle),
        cell('Avg', style: headerStyle),
        cell('Std', style: headerStyle),
      ],
    );

    TableRow bucketRow(SpendingBucket bucket, {required bool isLast}) =>
        TableRow(
          decoration: BoxDecoration(
            border: Border(bottom: sep(isLast ? 0 : 0.12)),
          ),
          children: [
            cell(
              _formatTableLabel(bucket.key),
              align: TextAlign.left,
              style: boldStyle,
            ),
            cell(_formatAmount(bucket.total, currency), style: bodyStyle),
            cell(_formatAmount(bucket.average, currency), style: bodyStyle),
            cell(
              _formatAmount(bucket.standardDeviation, currency),
              style: bodyStyle,
            ),
          ],
        );

    return Container(
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Table(
        columnWidths: colWidths,
        children: [
          headerRow,
          for (var i = 0; i < stats.buckets.length; i++)
            bucketRow(stats.buckets[i], isLast: i == stats.buckets.length - 1),
        ],
      ),
    );
  }

  Color _labelColor(String label) => labelColor(label);

  Widget _buildFilterButton({
    required Key key,
    required VoidCallback onTap,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: child,
        ),
      ),
    );
  }

  void _removeLabelOverlay() {
    _labelOverlay?.remove();
    _labelOverlay = null;
  }

  String _selectedLabelSummary(List<String> availableLabels) {
    if (availableLabels.isEmpty ||
        _selectedLabels.length == availableLabels.length) {
      return 'All tags';
    }
    if (_selectedLabels.isEmpty) {
      return 'No tags';
    }
    if (_selectedLabels.length == 1) {
      return _selectedLabels.first;
    }
    return '${_selectedLabels.length} tags';
  }

  void _toggleLabelSelection(String label) {
    setState(() {
      if (_selectedLabels.contains(label)) {
        _selectedLabels.remove(label);
      } else {
        _selectedLabels.add(label);
      }
    });
    _labelOverlay?.markNeedsBuild();
  }

  void _openLabelMenu() {
    if (_labelOverlay != null) {
      _removeLabelOverlay();
      return;
    }

    final box = _labelKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero, ancestor: overlay);
    final fieldSize = box.size;
    final theme = Theme.of(context);
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;
    final availableLabels = _availableLabels;
    final menuWidth = fieldSize.width;
    final menuHeight = math.min(280.0, availableLabels.length * 36.0 + 16.0);
    const gap = 6.0;

    double top = offset.dy + fieldSize.height + gap;
    if (top + menuHeight > overlay.size.height - 8) {
      top = offset.dy - menuHeight - gap;
    }

    double left = offset.dx;
    if (left + menuWidth > overlay.size.width - 8) {
      left = overlay.size.width - menuWidth - 8;
    }
    left = left.clamp(8.0, overlay.size.width - menuWidth - 8);

    _labelOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _removeLabelOverlay,
            ),
          ),
          Positioned(
            top: top,
            left: left,
            width: menuWidth,
            child: Material(
              color: fillColor,
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: menuHeight),
                child: ListView(
                  padding: const EdgeInsets.all(10),
                  shrinkWrap: true,
                  children: [
                    for (final label in availableLabels)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () => _toggleLabelSelection(label),
                            child: Builder(
                              builder: (context) {
                                final selected = _selectedLabels.contains(
                                  label,
                                );
                                final color = _labelColor(label);
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? color
                                        : color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: color,
                                      width: 1.25,
                                    ),
                                  ),
                                  child: Text(
                                    label,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: selected ? Colors.white : color,
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                                  ),
                                );
                              },
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
    );

    Overlay.of(context).insert(_labelOverlay!);
  }

  Future<void> _openCurrencyMenu() async {
    final renderBox =
        _currencyKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final topLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        topLeft.dx,
        topLeft.dy + renderBox.size.height + 4,
        overlay.size.width - topLeft.dx - renderBox.size.width,
        overlay.size.height - topLeft.dy,
      ),
      constraints: BoxConstraints(minWidth: renderBox.size.width),
      items: _currencies
          .map((c) => PopupMenuItem<String>(value: c, child: Text(c)))
          .toList(),
    );
    if (selected != null && mounted) {
      setState(() => _selectedCurrency = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;
    final currencies = _currencies;
    final availableLabels = _availableLabels;
    final selectedCurrency =
        _selectedCurrency ?? (currencies.isEmpty ? null : currencies.first);
    final stats = selectedCurrency == null
        ? null
        : SpendingStatsService.build(
            widget.lists,
            startDate: _startDate,
            currencySymbol: selectedCurrency,
            selectedLabels: _selectedLabels.length == availableLabels.length
                ? null
                : _selectedLabels,
            groupBy: _groupBy,
          );
    final currentCurrency = selectedCurrency ?? '';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('images/logo.png', height: 38),
            const SizedBox(width: 8),
            const GradientText(
              'Statistics',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: DateSelectorField(
                        selectedDate: _startDate,
                        onDateSelected: (value) =>
                            setState(() => _startDate = value),
                      ),
                    ),
                    if (availableLabels.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: _buildFilterButton(
                          key: _labelKey,
                          onTap: _openLabelMenu,
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.tags,
                                size: 11,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  _selectedLabelSummary(availableLabels),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Icon(
                                LucideIcons.chevron_down,
                                size: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (currencies.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: _buildFilterButton(
                          key: _currencyKey,
                          onTap: _openCurrencyMenu,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  currentCurrency,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                LucideIcons.chevron_down,
                                size: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<GroupBy>(
                    segments: const [
                      ButtonSegment(value: GroupBy.none, label: Text('None')),
                      ButtonSegment(value: GroupBy.week, label: Text('Week')),
                      ButtonSegment(value: GroupBy.month, label: Text('Month')),
                    ],
                    selected: {_groupBy},
                    onSelectionChanged: (selection) =>
                        setState(() => _groupBy = selection.first),
                    showSelectedIcon: false,
                  ),
                ),
                const SizedBox(height: 16),
                if (stats == null || stats.listCount == 0) ...[
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: fillColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'No completed lists with a saved total match the current filter.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ] else ...[
                  _buildChart(context, stats, currentCurrency),
                  const SizedBox(height: 16),
                  _buildTable(context, stats, currentCurrency),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: IconButton.filled(
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: fillColor,
                  foregroundColor: theme.colorScheme.onSurface,
                ),
                tooltip: 'Back',
                icon: const Icon(LucideIcons.chevron_left, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
