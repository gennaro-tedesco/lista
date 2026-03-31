import 'package:flutter/material.dart';
import 'app/themes.dart';
import 'features/home/shopping_lists_home_page.dart';

void main() {
  runApp(const ListaApp());
}

class ListaApp extends StatelessWidget {
  const ListaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeOption>(
      valueListenable: themeNotifier,
      builder: (context, option, child) => MaterialApp(
        title: 'Lista',
        theme: option.themeData,
        home: const ShoppingListsHomePage(),
      ),
    );
  }
}
