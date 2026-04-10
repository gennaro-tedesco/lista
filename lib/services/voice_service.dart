import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'extraction_service.dart';

export 'extraction_service.dart' show VoiceException, ExtractedItem;

const _minAudioBytes = 2048;

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
    return ExtractionService.invokeExtractItems({'audio': base64Encode(bytes)});
  }

  static Future<void> cancel() async {
    await _recorder.cancel();
    if (_tempPath != null) {
      final file = File(_tempPath!);
      if (await file.exists()) await file.delete();
      _tempPath = null;
    }
  }
}
