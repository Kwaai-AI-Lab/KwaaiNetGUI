import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../daemon/daemon_state.dart';

void _log(String msg) {
  stderr.writeln('[shutdown] $msg');
}

/// True while a user-initiated quit is tearing the daemon down. The UI watches
/// this to lock interaction and show the "Stopping service…" overlay (the same
/// visual as startup), so the user can't fire other actions mid-shutdown.
final shuttingDownProvider = NotifierProvider<ShuttingDownNotifier, bool>(
  ShuttingDownNotifier.new,
);

class ShuttingDownNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void engage() => state = true;
}

/// The single, shared "clean quit" routine used by both the window-close
/// handler and the tray Quit item.
///
/// 1. Engage the shutdown lock (UI blocks interaction + shows the overlay).
/// 2. Drive the daemon down via the normal transition path — which runs
///    `kwaainet stop`, so the CLI reaps the node and its detached children
///    (shard serve, storage API). We await it so the window doesn't vanish
///    before the daemon is actually gone.
/// 3. Destroy the window / exit.
///
/// When [osTerminating] is true, macOS is already terminating the app (this
/// was called from applicationShouldTerminate, which replied .terminateLater).
/// In that case we stop the daemon and return — the OS does the actual
/// teardown once this completes. Otherwise (window close / tray Quit) we
/// destroy the window ourselves to quit.
///
/// Idempotent: a second call while already shutting down is a no-op (returns
/// immediately) so reopening the tray menu and hitting Quit again can't start
/// a second teardown.
Future<void> performQuit(
  ProviderContainer container, {
  bool osTerminating = false,
}) async {
  if (container.read(shuttingDownProvider)) {
    _log('already shutting down — ignoring repeat quit');
    return;
  }
  container.read(shuttingDownProvider.notifier).engage();
  _log('clean quit → stopping daemon via kwaainet stop');

  // Goes through the transition notifier so the UI shows "Stopping service…"
  // (DaemonTransition.stopping). stop() is a no-op in external mode.
  try {
    await container.read(daemonTransitionProvider.notifier).stop();
  } catch (e) {
    _log('daemon stop error (proceeding to quit): $e');
  }

  if (osTerminating) {
    // macOS will terminate us as soon as this returns — don't fight it by
    // destroying the window ourselves.
    return;
  }

  try {
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  } catch (e) {
    _log('window destroy error (forcing exit): $e');
    exit(0);
  }
}
