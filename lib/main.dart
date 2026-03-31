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
    return AnimatedBuilder(
      animation: Listenable.merge([themeNotifier, uiFontScaleNotifier]),
      builder: (context, child) => MaterialApp(
        title: 'Lista',
        theme: themeNotifier.value.themeData,
        darkTheme: AppThemes.systemDark(fontScale: uiFontScaleNotifier.value),
        themeMode: themeNotifier.value == AppThemeOption.none
            ? ThemeMode.system
            : ThemeMode.light,
        home: const ShoppingListsHomePage(),
      ),
    );
  }
}
