import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../services/update_service.dart';

const _appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  bool _isChecking = true;
  UpdateInfo? _updateInfo;
  bool _hasError = false;
  bool _isDownloading = false;
  double _downloadProgress = 0;

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    setState(() {
      _isChecking = true;
      _hasError = false;
      _updateInfo = null;
    });
    try {
      final info = await UpdateService.checkForUpdate();
      if (!mounted) return;
      setState(() {
        _updateInfo = info;
        _isChecking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isChecking = false;
      });
    }
  }

  Future<void> _install() async {
    final canInstall = await UpdateService.canInstallPackages();
    if (!mounted) return;

    if (!canInstall) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('⚠️ Permission required'),
          content: const Text(
            'Enable "Install unknown apps" for Lista in system settings, then try again.',
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(LucideIcons.x),
            ),
            IconButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await UpdateService.openInstallSettings();
              },
              icon: const Icon(LucideIcons.settings),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    try {
      await UpdateService.downloadAndInstall(
        _updateInfo!.downloadUrl,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download failed — check your connection'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton.filled(
          onPressed: () => Navigator.pop(context),
          style: IconButton.styleFrom(
            backgroundColor: fillColor,
            foregroundColor: theme.colorScheme.onSurface,
          ),
          tooltip: 'Back',
          icon: const Icon(LucideIcons.chevron_left, size: 22),
        ),
        title: const Text('About'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Version'),
                    trailing: Text(
                      _appVersion,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Update'),
                    trailing: _buildUpdateTrailing(theme),
                    onTap: _isChecking || _isDownloading
                        ? null
                        : _checkForUpdate,
                  ),
                  if (_isDownloading) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LinearProgressIndicator(
                            value: _downloadProgress == 0
                                ? null
                                : _downloadProgress,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _downloadProgress == 0
                                ? 'Starting…'
                                : '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateTrailing(ThemeData theme) {
    if (_isChecking) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (_hasError) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '🚫 No connection',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            LucideIcons.refresh_cw,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      );
    }
    if (_updateInfo == null) {
      return Text(
        '✅ Up to date',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '🚀 ${_updateInfo!.version}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(LucideIcons.download),
          iconSize: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: _isDownloading ? null : _install,
        ),
      ],
    );
  }
}
