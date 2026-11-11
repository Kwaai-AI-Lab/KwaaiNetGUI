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
/// We only hide-to-tray when the tray icon is actually installed, so the app
/// never runs with neither window nor tray. Otherwise closing the window is a
/// true quit via [performQuit], which stops the node when [quitStopsDaemon].
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
