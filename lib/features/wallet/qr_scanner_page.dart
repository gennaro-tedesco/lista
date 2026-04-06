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
  bool _detected = false;

  void _onDetect(BarcodeCapture capture) {
    if (_detected || capture.image == null) return;
    _detected = true;
    _controller.stop();
    Navigator.pop(context, capture.image!);
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
