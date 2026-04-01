import 'package:flutter/material.dart';
import 'appearance_settings_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Appearance'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AppearanceSettingsPage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                const ListTile(title: Text('About'), enabled: false),
                const Divider(height: 1),
                const ListTile(title: Text('Account'), enabled: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
