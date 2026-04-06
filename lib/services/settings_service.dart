import 'package:shared_preferences/shared_preferences.dart';
import '../app/themes.dart';

abstract final class SettingsService {
  static const _keyTheme = 'theme';
  static const _keyFontScale = 'fontScale';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final themeName = prefs.getString(_keyTheme);
    if (themeName != null) {
      final match = AppThemeOption.values.where((e) => e.name == themeName);
      if (match.isNotEmpty) themeNotifier.value = match.first;
    }

    final fontScale = prefs.getDouble(_keyFontScale);
    if (fontScale != null) uiFontScaleNotifier.value = fontScale;

    themeNotifier.addListener(
      () => prefs.setString(_keyTheme, themeNotifier.value.name),
    );
    uiFontScaleNotifier.addListener(
      () => prefs.setDouble(_keyFontScale, uiFontScaleNotifier.value),
    );
  }
}
