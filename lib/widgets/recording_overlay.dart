import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

class RecordingOverlay extends StatefulWidget {
  final VoidCallback? onTap;

  const RecordingOverlay({super.key, this.onTap});

  @override
  State<RecordingOverlay> createState() => _RecordingOverlayState();
}

class _RecordingOverlayState extends State<RecordingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: ColoredBox(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.6),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return SizedBox(
                width: 180,
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    for (int i = 0; i < 3; i++) _buildRing(theme, i),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.error,
                      ),
                      child: Icon(
                        LucideIcons.mic,
                        color: theme.colorScheme.onError,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRing(ThemeData theme, int index) {
    final progress = (_controller.value + index / 3) % 1.0;
    final size = 56.0 + progress * 124;
    final opacity = (1.0 - progress) * 0.35;
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.colorScheme.error.withValues(alpha: opacity),
            width: 2,
          ),
        ),
      ),
    );
  }
}
