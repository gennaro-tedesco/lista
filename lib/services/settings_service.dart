import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app/themes.dart';

enum AiProviderOption {
  google,
  mistral,
  groq;

  String get displayName => switch (this) {
    AiProviderOption.google => 'Gemini',
    AiProviderOption.mistral => 'Mistral AI',
    AiProviderOption.groq => 'Groq',
  };
}

final providerNotifier = ValueNotifier<AiProviderOption>(
  AiProviderOption.google,
);

abstract final class SettingsService {
  static const _keyTheme = 'theme';
  static const _keyFontScale = 'fontScale';
  static const _keyFont = 'font';
  static const _keyProvider = 'provider';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final themeName = prefs.getString(_keyTheme);
    if (themeName != null) {
      final match = AppThemeOption.values.where((e) => e.name == themeName);
      if (match.isNotEmpty) themeNotifier.value = match.first;
    }

    final fontScale = prefs.getDouble(_keyFontScale);
    if (fontScale != null) uiFontScaleNotifier.value = fontScale;

    final fontName = prefs.getString(_keyFont);
    if (fontName != null) {
      final match = AppFontOption.values.where((e) => e.name == fontName);
      if (match.isNotEmpty) appFontNotifier.value = match.first;
    }

    final providerName = prefs.getString(_keyProvider);
    if (providerName != null) {
      final match = AiProviderOption.values.where(
        (e) => e.name == providerName,
      );
      if (match.isNotEmpty) providerNotifier.value = match.first;
    }

    themeNotifier.addListener(
      () => prefs.setString(_keyTheme, themeNotifier.value.name),
    );
    uiFontScaleNotifier.addListener(
      () => prefs.setDouble(_keyFontScale, uiFontScaleNotifier.value),
    );
    appFontNotifier.addListener(
      () => prefs.setString(_keyFont, appFontNotifier.value.name),
    );
    providerNotifier.addListener(
      () => prefs.setString(_keyProvider, providerNotifier.value.name),
    );
  }
}
