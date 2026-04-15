import 'dart:convert';
import 'dart:typed_data';
import 'extraction_service.dart';
import 'settings_service.dart';

export 'extraction_service.dart' show VoiceException, ExtractedItem;

abstract final class ImageService {
  static Future<List<ExtractedItem>> extractFromImage(
    Uint8List image,
    String mimeType,
  ) => ExtractionService.invokeExtractItems({
    'image': base64Encode(image),
    'mimeType': mimeType,
    'provider': providerNotifier.value.name,
  });
}
