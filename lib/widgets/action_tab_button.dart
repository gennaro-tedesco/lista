import 'package:flutter/material.dart';

class ActionTabButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final VoidCallback? onTap;
  final bool isLoading;

  const ActionTabButton({
    super.key,
    required this.icon,
    this.iconColor,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;
    final color =
        iconColor ??
        (onTap != null
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4));
    return Material(
      color: fillColor,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        child: SizedBox(
          height: 56,
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}
