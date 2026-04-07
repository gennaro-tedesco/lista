import 'package:flutter/material.dart';

Future<void> showTemplateSavedToast(BuildContext context, String name) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Template saved',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (context, animation, secondaryAnimation) => const SizedBox(),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(
          opacity: animation,
          child: SafeArea(
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).inputDecorationTheme.fillColor ??
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(
                    'Saved $name as template!',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
          ),
        ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 1400));
  if (navigator.mounted && navigator.canPop()) {
    navigator.pop();
  }
}
