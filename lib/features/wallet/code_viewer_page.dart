import 'dart:io';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../models/stored_code.dart';

class CodeViewerPage extends StatefulWidget {
  final StoredCode code;

  const CodeViewerPage({super.key, required this.code});

  @override
  State<CodeViewerPage> createState() => _CodeViewerPageState();
}

class _CodeViewerPageState extends State<CodeViewerPage> {
  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.code.name),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(File(widget.code.imagePath), fit: BoxFit.contain),
        ),
      ),
    );
  }
}
