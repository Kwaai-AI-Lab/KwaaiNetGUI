import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../daemon/daemon_state.dart';
import '../settings.dart';
import '../tray/tray.dart';
import 'dock_icon.dart';

void _log(String msg) {
  stderr.writeln('[window-close] $msg');
}

/// Decides what happens when the user closes the window. Reads
/// [Settings.keepInTrayOnClose] live, so the choice can be toggled in
/// preferences without restarting the app.
///
/// Invariant: we must never end up with the daemon running while neither the
/// window nor the tray icon is visible. So we only hide-to-tray when the tray
/// icon is actually installed; otherwise closing the window is a true quit,
/// which stops the daemon first.
class WindowCloseHandler with WindowListener {
  WindowCloseHandler(this._settings, this._tray, this._container);

  final Settings _settings;
  final TrayController _tray;
  final ProviderContainer _container;

  Future<void> attach() async {
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
  }

  void dispose() {
    windowManager.removeListener(this);
  }

  @override
  void onWindowClose() async {
    // Hide to tray only if the tray icon is actually showing — otherwise the
    // app would vanish entirely while the daemon keeps running.
    if (_settings.keepInTrayOnClose && _tray.enabled) {
      _log('keepInTrayOnClose=true & tray enabled → hiding window + Dock icon');
      await windowManager.hide();
      // Also hide the Dock icon and Cmd-Tab entry. The tray icon alone
      // signals the app is running.
      await DockIcon.setVisible(false);
      return;
    }

    _log('true quit → stopping daemon, then destroying window');
    // Stop the daemon we started so kwaainet/p2pd don't outlive the app.
    // stop() is a no-op in external mode (user-managed).
    try {
      await _container.read(daemonControllerProvider).stop();
    } catch (e) {
      _log('daemon stop error (proceeding to quit): $e');
    }
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }
}
