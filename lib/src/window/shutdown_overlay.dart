import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/theme/kwaai_theme.dart';
import 'shutdown.dart';

/// App-wide overlay shown while [performQuit] is tearing the daemon down.
///
/// Wraps the whole app (via MaterialApp.builder) so it covers every route —
/// main page and settings alike. While active it:
///   - blocks all pointer input (AbsorbPointer), so the user can't fire other
///     actions mid-shutdown, and
///   - shows the same spinner + "Stopping service…" treatment used for the
///     startup transition, scrimmed over the current screen.
class ShutdownOverlay extends ConsumerWidget {
  const ShutdownOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shuttingDown = ref.watch(shuttingDownProvider);
    final ext = context.kwaai;

    return Stack(
      children: [
        child,
        if (shuttingDown)
          AbsorbPointer(
            child: ColoredBox(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.86),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(
                          ext.statusTransitioning,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Stopping service…',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
