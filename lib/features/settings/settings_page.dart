import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'appearance_settings_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _version;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

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
                ListTile(
                  title: const Text('About'),
                  trailing: _version == null
                      ? null
                      : Text(
                          'v$_version',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                ),
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
