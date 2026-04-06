import 'dart:io';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../models/stored_code.dart';

class CodeViewerPage extends StatefulWidget {
  final List<StoredCode> codes;
  final int initialIndex;

  const CodeViewerPage({
    super.key,
    required this.codes,
    required this.initialIndex,
  });

  @override
  State<CodeViewerPage> createState() => _CodeViewerPageState();
}

class _CodeViewerPageState extends State<CodeViewerPage> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    _pageController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.codes[_currentIndex];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(code.name),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.codes.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final pageCode = widget.codes[index];
          return Center(
            child: InteractiveViewer(
              child: Image.file(File(pageCode.imagePath), fit: BoxFit.contain),
            ),
          );
        },
      ),
    );
  }
}
