import 'package:flutter/material.dart';
import '../models/user_profile.dart';

class ShareDialog extends StatefulWidget {
  final Future<List<String>> Function() getShares;
  final Future<List<UserProfile>> Function() getUsers;
  final Future<void> Function(String userId) share;
  final Future<void> Function(String userId) unshare;

  const ShareDialog({
    super.key,
    required this.getShares,
    required this.getUsers,
    required this.share,
    required this.unshare,
  });

  @override
  State<ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<ShareDialog> {
  List<UserProfile>? _users;
  Set<String>? _initialShares;
  Set<String> _selected = {};
  Object? _loadError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loadError = null;
      _users = null;
      _initialShares = null;
    });
    try {
      final results = await Future.wait([
        widget.getUsers(),
        widget.getShares(),
      ]);
      if (!mounted) return;
      setState(() {
        _users = results[0] as List<UserProfile>;
        _initialShares = Set<String>.from(results[1] as List<String>);
        _selected = Set<String>.from(_initialShares!);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
      });
    }
  }

  Future<void> _confirm() async {
    if (_users == null || _initialShares == null) return;
    setState(() => _saving = true);
    try {
      final toAdd = _selected.difference(_initialShares!);
      final toRemove = _initialShares!.difference(_selected);
      await Future.wait([
        ...toAdd.map(widget.share),
        ...toRemove.map(widget.unshare),
      ]);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = _users;
    return AlertDialog(
      title: const Text('Share with'),
      content: _loadError != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Failed to load sharing data.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _saving ? null : _load,
                  child: const Text('Retry'),
                ),
              ],
            )
          : users == null
          ? const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            )
          : users.isEmpty
          ? const Text('No other users found.')
          : SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: users
                    .map(
                      (user) => CheckboxListTile(
                        value: _selected.contains(user.id),
                        title: Text(user.name),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selected.add(user.id);
                          } else {
                            _selected.remove(user.id);
                          }
                        }),
                      ),
                    )
                    .toList(),
              ),
            ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        IconButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
        IconButton(
          onPressed: (_saving || users == null || _loadError != null)
              ? null
              : _confirm,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
        ),
      ],
    );
  }
}
