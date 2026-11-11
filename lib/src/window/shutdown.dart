import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../daemon/daemon_state.dart';
import '../settings.dart';

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

/// The app-wide [ProviderContainer], so non-widget code (the update
/// controller) can call [performQuit], which needs the container itself.
/// Overridden in main.dart; same shape as `settingsProvider`.
final appContainerProvider = Provider<ProviderContainer>((ref) {
  throw UnimplementedError(
    'appContainerProvider must be overridden with the app-wide '
    'ProviderContainer via ProviderScope.overrides.',
  );
});

/// Whether quitting stops the node: only when this GUI starts one at launch,
/// so a node it merely found running is treated as its own then. Read live.
bool quitStopsDaemon(Settings s) =>
    s.mode != DaemonMode.external && s.startServiceOnStartup;

/// The single, shared "clean quit" routine used by both the window-close
/// handler and the tray Quit item.
///
/// 1. Engage the shutdown lock (UI blocks interaction + shows the overlay).
/// 2. If [quitStopsDaemon], drive the daemon down via the normal transition
///    path — which runs `kwaainet stop`, so the CLI reaps the node and its
///    detached children (shard serve, storage API). We await it so the window
///    doesn't vanish before the daemon is actually gone.
/// 3. Run [beforeClose] (the tray removes its icon here), then close the
///    window to exit.
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
///
/// [forceStop] stops a managed node regardless of [quitStopsDaemon]; the
/// updater needs it gone to replace the bundle.
///
/// [isWindows] defaults to the host platform; tests pass it explicitly.
Future<void> performQuit(
  ProviderContainer container, {
  bool osTerminating = false,
  bool forceStop = false,
  Future<void> Function()? beforeClose,
  bool? isWindows,
}) async {
  if (container.read(shuttingDownProvider)) {
    _log('already shutting down — ignoring repeat quit');
    return;
  }
  container.read(shuttingDownProvider.notifier).engage();
  _log('clean quit');

  // Goes through the transition notifier so the UI shows "Stopping service…"
  // (DaemonTransition.stopping). stop() is a no-op in external mode.
  if (forceStop || quitStopsDaemon(container.read(settingsProvider))) {
    try {
      await container.read(daemonTransitionProvider.notifier).stop();
    } catch (e) {
      _log('daemon stop error (proceeding to quit): $e');
    }
  } else {
    _log('start-on-startup off or external mode — leaving the node running');
  }

  if (osTerminating) {
    // macOS will terminate us as soon as this returns — don't fight it by
    // destroying the window ourselves.
    return;
  }

  if (beforeClose != null) {
    try {
      await beforeClose();
    } catch (e) {
      _log('beforeClose error (proceeding to quit): $e');
    }
  }

  try {
    await windowManager.setPreventClose(false);
    if (isWindows ?? Platform.isWindows) {
      // Not destroy(): on Windows that is a bare PostQuitMessage(0), which
      // ends the message loop with the window and engine still alive, and
      // the process then crashes in flutter_windows.dll on the way out.
      // close() takes the runner's own path: WM_CLOSE → DestroyWindow →
      // WM_DESTROY → FlutterWindow::OnDestroy → PostQuitMessage. It also
      // raises onWindowClose, which WindowCloseHandler ignores mid-quit.
      await windowManager.close();
    } else {
      await windowManager.destroy();
    }
  } catch (e) {
    _log('window destroy error (forcing exit): $e');
    exit(0);
  }
}
