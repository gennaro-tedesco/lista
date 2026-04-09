import 'package:flutter/material.dart';
import 'account_page.dart';
import 'appearance_settings_page.dart';
import 'how_to_page.dart';

const _appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void _openSubpage(BuildContext context, Widget page) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final content = ListView(
      padding: const EdgeInsets.all(16),
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
                title: const Text('Appearance'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    _openSubpage(context, const AppearanceSettingsPage()),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('How to'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openSubpage(context, const HowToPage()),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('About'),
                trailing: Text(
                  _appVersion,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Account'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openSubpage(context, const AccountPage()),
              ),
            ],
          ),
        ),
      ],
    );

    return SafeArea(child: content);
  }
}
