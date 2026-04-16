import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/themes.dart';
import 'features/home/shopping_lists_home_page.dart';
import 'repositories/list_repository.dart';
import 'repositories/local_list_repository.dart';
import 'repositories/supabase_list_repository.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.load();
  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
  if (Supabase.instance.client.auth.currentUser != null) {
    listRepository = await SupabaseListRepository.create();
    authStateNotifier.value = true;
  } else {
    listRepository = await createLocalListRepository();
  }
  runApp(const ListaApp());
}

class ListaApp extends StatelessWidget {
  const ListaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        themeNotifier,
        uiFontScaleNotifier,
        appFontNotifier,
      ]),
      builder: (context, child) {
        final theme = themeNotifier.value.themeData;
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            systemNavigationBarColor: theme.scaffoldBackgroundColor,
            systemNavigationBarIconBrightness:
                theme.brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
          ),
        );
        return MaterialApp(
          title: 'Lista',
          scaffoldMessengerKey: NotificationService.messengerKey,
          theme: theme,
          darkTheme: appFontNotifier.value.apply(
            AppThemes.systemDark(fontScale: uiFontScaleNotifier.value),
          ),
          themeMode: themeNotifier.value == AppThemeOption.none
              ? ThemeMode.system
              : ThemeMode.light,
          home: const ShoppingListsHomePage(),
        );
      },
    );
  }
}
