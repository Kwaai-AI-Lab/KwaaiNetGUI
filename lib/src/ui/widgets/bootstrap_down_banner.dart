import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../daemon/bootstrap_health.dart';
import 'kwaai_status_bar.dart';

/// Pinned red bar shown when the daemon cannot reach any of its configured
/// bootstrap peers. The node looks "running" everywhere else in the app
/// while being cut off from the network, and nothing outside Settings →
/// Peers would otherwise say so.
///
/// Mounted once, above the Navigator (see `MaterialApp.builder` in
/// `main.dart`): the same bar spans the window's full width and persists
/// across the main and settings routes, rather than each page carrying its
/// own copy.
///
/// No dismiss and no actions: the bar tracks live state and clears itself
/// the moment a bootstrap becomes reachable; hiding it while the node stays
/// cut off would just recreate the silent failure this exists to end.
class BootstrapDownBanner extends ConsumerWidget {
  const BootstrapDownBanner({super.key, this.bottomRadius});

  final BorderRadius? bottomRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(bootstrapHealthProvider).valueOrNull;
    if (!showBootstrapDownBanner(health)) return const SizedBox.shrink();

    return KwaaiStatusBar(
      severity: KwaaiStatusSeverity.error,
      message: bootstrapDownMessage(health!),
      bottomRadius: bottomRadius,
    );
  }
}
