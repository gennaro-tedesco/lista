import 'package:flutter/material.dart';

class CenteredPopupShell extends StatelessWidget {
  final Widget child;

  const CenteredPopupShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: child,
    );
  }
}
