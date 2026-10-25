import 'package:flutter_test/flutter_test.dart';
import 'package:lista/app/ai_models.dart';
import 'package:lista/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'migrated Xiaomi settings preserve a later model choice on reload',
    () async {
      SharedPreferences.setMockInitialValues({'provider': 'xiaomi'});

      await SettingsService.load();
      expect(providerNotifier.value, AiProviderOption.openrouter);
      expect(selectedModelFor(), xiaomiModel);

      final prefs = await SharedPreferences.getInstance();
      modelNotifier.value = qwenModel;
      await Future<void>.delayed(Duration.zero);
      await prefs.reload();
      await SettingsService.load();

      expect(providerNotifier.value, AiProviderOption.openrouter);
      expect(selectedModelFor(), qwenModel);
      expect(prefs.getString('provider'), 'openrouter');
      expect(prefs.getString('model'), qwenModel);
    },
  );
}
