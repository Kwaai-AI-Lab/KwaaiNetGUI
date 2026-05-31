import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/theme/kwaai_theme.dart';
import '../ui/widgets/app_shell.dart';
import '../ui/widgets/service_status_view.dart';
import 'shutdown.dart';

/// While [performQuit] is tearing the daemon down, this *replaces* the whole
/// app — every route, including settings — with the same centered spinner +
/// headline treatment used for the startup transition (via [ServiceStatusView]
/// and the shared [AppShell]/[ShellCard] chrome). It IS the screen, not a
/// scrim: nothing shows through, and there's nothing left to interact with.
class ShutdownGate extends ConsumerWidget {
  const ShutdownGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(shuttingDownProvider)) return child;

    return AppShell(
      child: ShellCard(
        borderRadius: shellRadius(
          topLeft: true,
          topRight: true,
          bottomLeft: true,
          bottomRight: true,
        ),
        child: ServiceStatusView(
          headline: 'Stopping service…',
          spinnerColor: context.kwaai.statusTransitioning,
        ),
      ),
    );
  }
}
