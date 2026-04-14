import 'package:flutter/material.dart';

class CenteredPopupShell extends StatelessWidget {
  final Widget child;

  const CenteredPopupShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        width: 320,
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}
