import 'dart:math';
import '../models/shopping_list.dart';

enum GroupBy { none, week, month }

class SpendingBucket {
  final DateTime key;
  final double total;
  final double average;
  final double standardDeviation;

  const SpendingBucket({
    required this.key,
    required this.total,
    required this.average,
    required this.standardDeviation,
  });
}

class SpendingStats {
  final double totalSpent;
  final double averageSpent;
  final double standardDeviation;
  final int listCount;
  final List<SpendingBucket> buckets;

  const SpendingStats({
    required this.totalSpent,
    required this.averageSpent,
    required this.standardDeviation,
    required this.listCount,
    required this.buckets,
  });
}

class SpendingStatsService {
  static SpendingStats build(
    List<ShoppingList> lists, {
    required DateTime startDate,
    required String currencySymbol,
    Set<String>? selectedLabels,
    GroupBy groupBy = GroupBy.month,
  }) {
    final filtered = lists.where((list) {
      if (!list.isCompleted) return false;
      if (list.currencySymbol != currencySymbol) return false;
      if (selectedLabels != null) {
        if (selectedLabels.isEmpty) return false;
        if (!list.labels.any(selectedLabels.contains)) return false;
      }
      if (list.date.isBefore(
        DateTime(startDate.year, startDate.month, startDate.day),
      )) {
        return false;
      }
      return _parsePrice(list.totalPrice) != null;
    }).toList()..sort((a, b) => a.date.compareTo(b.date));

    final entries = filtered
        .map((list) => (list.date, _parsePrice(list.totalPrice)!))
        .toList();

    final buckets = _buildBuckets(entries, groupBy);
    final bucketTotals = buckets.map((b) => b.total).toList();

    final totalSpent = bucketTotals.fold<double>(0.0, (sum, v) => sum + v);
    final averageSpent = bucketTotals.isEmpty
        ? 0.0
        : totalSpent / bucketTotals.length;
    final variance = bucketTotals.length <= 1
        ? 0.0
        : bucketTotals
                  .map((t) => pow(t - averageSpent, 2))
                  .fold<double>(0.0, (sum, v) => sum + v) /
              (bucketTotals.length - 1);

    return SpendingStats(
      totalSpent: totalSpent,
      averageSpent: averageSpent,
      standardDeviation: sqrt(variance),
      listCount: filtered.length,
      buckets: buckets,
    );
  }

  static List<SpendingBucket> _buildBuckets(
    List<(DateTime, double)> entries,
    GroupBy groupBy,
  ) {
    if (groupBy == GroupBy.none) {
      return entries
          .map(
            (e) => SpendingBucket(
              key: e.$1,
              total: e.$2,
              average: e.$2,
              standardDeviation: 0,
            ),
          )
          .toList();
    }

    final map = <DateTime, List<double>>{};
    for (final (date, amount) in entries) {
      final key = groupBy == GroupBy.week
          ? _weekStart(date)
          : DateTime(date.year, date.month);
      map.putIfAbsent(key, () => []).add(amount);
    }

    return map.entries.map((e) {
      final values = e.value;
      final total = values.fold<double>(0.0, (sum, v) => sum + v);
      final avg = total / values.length;
      final variance = values.length <= 1
          ? 0.0
          : values
                    .map((v) => pow(v - avg, 2))
                    .fold<double>(0.0, (sum, v) => sum + v) /
                (values.length - 1);
      return SpendingBucket(
        key: e.key,
        total: total,
        average: avg,
        standardDeviation: sqrt(variance),
      );
    }).toList()..sort((a, b) => a.key.compareTo(b.key));
  }

  static DateTime _weekStart(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  static double? _parsePrice(String? value) {
    if (value == null) return null;
    final normalized = value.trim().replaceAll(',', '.');
    return double.tryParse(normalized);
  }
}
