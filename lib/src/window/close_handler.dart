import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../settings.dart';
import '../tray/tray.dart';
import 'dock_icon.dart';
import 'shutdown.dart';

void _log(String msg) {
  stderr.writeln('[window-close] $msg');
}

/// Decides what happens when the user closes the window. Reads
/// [Settings.keepInTrayOnClose] live, so the choice can be toggled in
/// preferences without restarting the app.
///
/// Invariant: we must never end up with a daemon this app started running
/// while neither the window nor the tray icon is visible. So we only
/// hide-to-tray when the tray icon is actually installed; otherwise closing
/// the window is a true quit, which runs the shared [performQuit] routine
/// (stops a daemon this app started first; one it attached to is the user's
/// and keeps running).
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
    // performQuit closes the window itself on Windows; that close must go
    // through, not hide to tray or start a second quit.
    if (_container.read(shuttingDownProvider)) {
      _log('close during quit → letting it through');
      return;
    }
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

    _log('true quit → performQuit');
    await performQuit(_container);
  }
}
