import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'extraction_service.dart';

export 'extraction_service.dart' show VoiceException, ExtractedItem;

const _minAudioBytes = 2048;
const _silenceThresholdDb = -9.0;

abstract final class VoiceService {
  static final _recorder = AudioRecorder();
  static String? _tempPath;
  static double _maxAmplitude = double.negativeInfinity;
  static StreamSubscription<Amplitude>? _amplitudeSub;

  static Future<bool> hasPermission() => _recorder.hasPermission();

  static Future<void> start() async {
    final dir = await getTemporaryDirectory();
    _tempPath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _maxAmplitude = double.negativeInfinity;
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _tempPath!,
    );
    _amplitudeSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen((amp) {
          if (amp.current > _maxAmplitude) _maxAmplitude = amp.current;
        });
  }

  static Future<List<ExtractedItem>> stopAndExtract() async {
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    final maxAmp = _maxAmplitude;

    final path = await _recorder.stop();
    if (path == null) throw const VoiceException('no_audio');
    final bytes = await File(path).readAsBytes();
    await File(path).delete();
    _tempPath = null;
    _maxAmplitude = double.negativeInfinity;

    if (bytes.length < _minAudioBytes) {
      throw const VoiceException('no_audio');
    }
    if (maxAmp < _silenceThresholdDb) {
      throw const VoiceException('too_quiet');
    }
    return ExtractionService.invokeExtractItems({'audio': base64Encode(bytes)});
  }

  static Future<void> cancel() async {
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _maxAmplitude = double.negativeInfinity;
    await _recorder.cancel();
    if (_tempPath != null) {
      final file = File(_tempPath!);
      if (await file.exists()) await file.delete();
      _tempPath = null;
    }
  }
}
