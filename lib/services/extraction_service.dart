import 'dart:async';
import 'dart:io';

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
    final response = await _invoke(body);
    return parseItems(response.data);
  }

  static Future<FunctionResponse> _invoke(Map<String, dynamic> body) async {
    try {
      return await Supabase.instance.client.functions.invoke(
        'extract-items',
        body: body,
      );
    } on FunctionException catch (e) {
      final details = e.details;
      if (e.status == 401) {
        throw const VoiceException('unauthorized');
      }
      if (details is Map<String, dynamic>) {
        throw VoiceException(
          details['error']?.toString() ?? _fallbackCodeForStatus(e.status),
        );
      }
      throw VoiceException(
        details?.toString() ?? _fallbackCodeForStatus(e.status),
      );
    } on SocketException {
      throw const VoiceException('server_unreachable');
    } on HttpException {
      throw const VoiceException('server_unreachable');
    } on TimeoutException {
      throw const VoiceException('server_unreachable');
    } catch (e) {
      if (_isTransportException(e)) {
        throw const VoiceException('server_unreachable');
      }
      rethrow;
    }
  }

  static String _fallbackCodeForStatus(int status) {
    if (status == 401) return 'unauthorized';
    if (status == 503) return 'model_unavailable';
    if (status == 504) return 'upstream_timeout';
    return 'transcription_failed';
  }

  static bool _isTransportException(Object error) {
    final type = error.runtimeType.toString();
    return type == 'ClientException' || type == 'FetchException';
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
