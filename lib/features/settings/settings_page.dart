import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
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
      await _showUpdateDialog(error: true);
      return;
    }
    if (!mounted) return;
    setState(() => _isChecking = false);

    if (info == null) {
      await _showUpdateDialog(upToDate: true);
      return;
    }

    final canInstall = await UpdateService.canInstallPackages();
    if (!mounted) return;

    if (!canInstall) {
      await _showUpdateDialog(permissionRequired: true);
      return;
    }

    final confirmed = await _showUpdateDialog(info: info);
    if (confirmed != true || !mounted) return;

    await _downloadAndInstall(info.downloadUrl);
  }

  Future<bool?> _showUpdateDialog({
    UpdateInfo? info,
    bool upToDate = false,
    bool permissionRequired = false,
    bool error = false,
  }) {
    final String title;
    final String content;
    final bool showConfirm;

    if (error) {
      title = '🚫 No connection';
      content = 'Could not reach update server';
      showConfirm = false;
    } else if (upToDate) {
      title = '✅ Up to date';
      content = 'You are up-to-date! ($_appVersion).';
      showConfirm = false;
    } else if (permissionRequired) {
      title = '⚠️ Permission required';
      content =
          'Enable "Install unknown apps" for Lista in system settings, then try again.';
      showConfirm = true;
    } else {
      title = '🚀 Update available';
      content = 'Version ${info!.version} is available! Install now?';
      showConfirm = true;
    }

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(ctx, false),
            icon: const Icon(LucideIcons.x),
          ),
          if (showConfirm)
            IconButton(
              onPressed: () async {
                Navigator.pop(ctx, true);
                if (permissionRequired) {
                  await UpdateService.openInstallSettings();
                }
              },
              icon: Icon(
                permissionRequired ? LucideIcons.settings : LucideIcons.check,
              ),
            ),
        ],
      ),
    );
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
        const SnackBar(
          content: Text('Download failed — check your connection'),
        ),
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
