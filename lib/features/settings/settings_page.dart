import 'package:flutter/material.dart';
import '../../services/update_service.dart';
import 'account_page.dart';
import 'appearance_settings_page.dart';
import 'how_to_page.dart';

const _appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _tileDensity = VisualDensity(vertical: -3.5);
  bool _isChecking = false;

  void _openSubpage(BuildContext context, Widget page) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _checkForUpdates() async {
    setState(() => _isChecking = true);
    UpdateInfo? info;
    try {
      info = await UpdateService.checkForUpdate();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isChecking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not reach update server — check your connection')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _isChecking = false);

    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You are up to date ($_appVersion)')),
      );
      return;
    }

    final canInstall = await UpdateService.canInstallPackages();
    if (!mounted) return;

    if (!canInstall) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Permission required'),
          content: const Text(
            'To install updates, enable "Install unknown apps" for Lista in system settings.',
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await UpdateService.openInstallSettings();
              },
              child: const Text('Open settings'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update available'),
        content: Text('Version ${info!.version} is available.\nDownload and install now?'),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Install'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _downloadAndInstall(info.downloadUrl);
  }

  Future<void> _downloadAndInstall(String url) async {
    double progress = 0;
    late StateSetter setDialogState;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          setDialogState = setState;
          return AlertDialog(
            title: const Text('Downloading update'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: progress == 0 ? null : progress),
                const SizedBox(height: 12),
                Text(
                  progress == 0
                      ? 'Starting…'
                      : '${(progress * 100).toStringAsFixed(0)}%',
                ),
              ],
            ),
          );
        },
      ),
    );

    try {
      await UpdateService.downloadAndInstall(
        url,
        onProgress: (p) {
          setDialogState(() => progress = p);
        },
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download failed — check your connection')),
      );
      return;
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
                  const Divider(height: 1),
                  ListTile(
                    visualDensity: _tileDensity,
                    title: const Text('Check for updates'),
                    trailing: _isChecking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.system_update_outlined),
                    onTap: _isChecking ? null : _checkForUpdates,
                  ),
                ],
              ),
            ),
            const Spacer(),
            Card(
              child: ListTile(
                visualDensity: _tileDensity,
                title: const Text('About'),
                trailing: Text(
                  _appVersion,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
