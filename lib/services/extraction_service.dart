import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/shopping_list_item.dart';
import 'suggestion_service.dart';

const _uuid = Uuid();

class VoiceException implements Exception {
  final String code;
  const VoiceException(this.code);
}

class ExtractedItem {
  final String name;
  final num? quantity;
  final String? unit;

  const ExtractedItem({required this.name, this.quantity, this.unit});

  String? get quantityString {
    if (quantity == null) return null;
    final q = quantity! % 1 == 0
        ? quantity!.toInt().toString()
        : quantity!.toString();
    return unit != null ? '$q $unit' : q;
  }

  ShoppingListItem toItem() => ShoppingListItem(
    id: _uuid.v4(),
    name: name,
    quantity: quantityString,
    category: SuggestionService.categoryFor(name),
  );
}

abstract final class ExtractionService {
  static Future<List<ExtractedItem>> invokeExtractItems(
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'extract-items',
        body: body,
      );
      return parseItems(response.data);
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map<String, dynamic>) {
        throw VoiceException(details['error']?.toString() ?? e.toString());
      }
      throw VoiceException(details?.toString() ?? e.toString());
    }
  }

  static List<ExtractedItem> parseItems(Object? responseData) {
    final data = responseData as Map<String, dynamic>;
    final rawItems = data['items'] as List<dynamic>? ?? [];
    return rawItems.map((e) {
      final m = e as Map<String, dynamic>;
      final qty = m['quantity'];
      return ExtractedItem(
        name: m['name'] as String,
        quantity: qty is num ? qty : null,
        unit: m['unit'] as String?,
      );
    }).toList();
  }
}
