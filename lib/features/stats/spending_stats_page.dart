import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../widgets/gradient_text.dart';
import 'dart:math' as math;
import '../../models/shopping_list.dart';
import '../../services/spending_stats_service.dart';
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
  GroupBy _groupBy = GroupBy.month;

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
        color: theme.colorScheme.surface,
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
        color: theme.colorScheme.surface,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencies = _currencies;
    final selectedCurrency =
        _selectedCurrency ?? (currencies.isEmpty ? null : currencies.first);
    final stats = selectedCurrency == null
        ? null
        : SpendingStatsService.build(
            widget.lists,
            startDate: _startDate,
            currencySymbol: selectedCurrency,
            groupBy: _groupBy,
          );
    final currentCurrency = selectedCurrency ?? '';

    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    const labelWidth = 48.0;

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
            children: [
              SizedBox(
                width: labelWidth,
                child: Text('From', style: labelStyle),
              ),
              Expanded(
                child: DateSelectorField(
                  selectedDate: _startDate,
                  onDateSelected: (value) => setState(() => _startDate = value),
                ),
              ),
              if (currencies.isNotEmpty) ...[
                const SizedBox(width: 8),
                DropdownMenu<String>(
                  initialSelection: selectedCurrency,
                  onSelected: (value) {
                    if (value != null)
                      setState(() => _selectedCurrency = value);
                  },
                  width: 96,
                  inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor:
                        theme.inputDecorationTheme.fillColor ??
                        theme.colorScheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  dropdownMenuEntries: currencies
                      .map((c) => DropdownMenuEntry<String>(value: c, label: c))
                      .toList(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: labelWidth,
                child: Text('Group', style: labelStyle),
              ),
              Expanded(
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
            ],
          ),
          const SizedBox(height: 16),
          if (stats == null || stats.listCount == 0) ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
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
                  backgroundColor: theme.colorScheme.surface,
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
