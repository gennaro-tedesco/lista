import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    returnImage: true,
  );
  DateTime? _detectedAt;
  bool _done = false;

  static const _settleMs = 800;

  void _onDetect(BarcodeCapture capture) {
    if (_done || capture.image == null) return;

    final now = DateTime.now();

    if (_detectedAt == null) {
      _detectedAt = now;
      return;
    }

    if (now.difference(_detectedAt!).inMilliseconds >= _settleMs) {
      _done = true;
      _controller.stop();
      Navigator.pop(context, capture.image!);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Code')),
      body: MobileScanner(controller: _controller, onDetect: _onDetect),
    );
  }
}
