import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'about_page.dart';
import 'account_page.dart';
import 'ai_provider_page.dart';
import 'appearance_settings_page.dart';
import 'how_to_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  static const _tileDensity = VisualDensity(vertical: -3.5);

  void _openSubpage(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) > 300) {
              Navigator.of(context).pop();
            }
          },
          child: page,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSignedIn = Supabase.instance.client.auth.currentUser != null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Settings',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Card(
              child: Column(
                children: [
                  ListTile(
                    visualDensity: _tileDensity,
                    title: const Text('Appearance'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        _openSubpage(context, const AppearanceSettingsPage()),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    visualDensity: _tileDensity,
                    title: const Text('How to'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openSubpage(context, const HowToPage()),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    visualDensity: _tileDensity,
                    title: const Text('Account'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openSubpage(context, const AccountPage()),
                  ),
                  if (isSignedIn) ...[
                    const Divider(height: 1),
                    ListTile(
                      visualDensity: _tileDensity,
                      title: const Text('AI provider'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          _openSubpage(context, const AiProviderPage()),
                    ),
                  ],
                ],
              ),
            ),
            const Spacer(),
            Card(
              child: ListTile(
                visualDensity: _tileDensity,
                title: const Text('About'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openSubpage(context, const AboutPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
