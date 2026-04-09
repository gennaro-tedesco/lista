import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/shopping_list_item.dart';
import 'suggestion_service.dart';

const _uuid = Uuid();
const _minAudioBytes = 2048;

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

abstract final class VoiceService {
  static final _recorder = AudioRecorder();
  static String? _tempPath;

  static Future<bool> hasPermission() => _recorder.hasPermission();

  static Future<void> start() async {
    final dir = await getTemporaryDirectory();
    _tempPath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _tempPath!,
    );
  }

  static Future<List<ExtractedItem>> stopAndExtract() async {
    final path = await _recorder.stop();
    if (path == null) throw const VoiceException('no_audio');
    final bytes = await File(path).readAsBytes();
    await File(path).delete();
    _tempPath = null;
    if (bytes.length < _minAudioBytes) throw const VoiceException('no_audio');
    return _extractFromBytes(bytes);
  }

  static Future<void> cancel() async {
    await _recorder.cancel();
    if (_tempPath != null) {
      final file = File(_tempPath!);
      if (await file.exists()) await file.delete();
      _tempPath = null;
    }
  }

  static Future<List<ExtractedItem>> _extractFromBytes(Uint8List audio) async {
    final response = await Supabase.instance.client.functions.invoke(
      'extract-items',
      body: {'audio': base64Encode(audio)},
    );
    final data = response.data as Map<String, dynamic>;
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
