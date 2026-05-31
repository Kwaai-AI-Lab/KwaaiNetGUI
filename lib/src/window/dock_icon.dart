import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'shutdown.dart';

void _log(String msg) {
  stderr.writeln('[dock-icon] $msg');
}

/// Bridge to the macOS-side `kwaai/lifecycle` method channel (see
/// AppDelegate.swift). All methods are no-ops on non-macOS platforms.
class DockIcon {
  static const _channel = MethodChannel('kwaai/lifecycle');

  /// Show or hide the Dock icon by setting NSApp.activationPolicy.
  /// When [visible] is false the app disappears from the Dock and Cmd-Tab,
  /// living only in the menu-bar tray. When true the Dock icon returns
  /// and the app is brought to the foreground.
  static Future<void> setVisible(bool visible) async {
    if (kIsWeb || !Platform.isMacOS) return;
    try {
      await _channel.invokeMethod('setDockIconVisible', visible);
      _log('setVisible($visible)');
    } catch (e) {
      _log('setVisible($visible) failed: $e');
    }
  }
}

/// Installs the macOS `kwaai/lifecycle` handlers from AppDelegate.swift:
///
///  - `reopenWindow` — Dock-icon click / Finder relaunch while hidden:
///    bring the window back to the foreground.
///  - `performQuit` — Cmd-Q / Apple-menu Quit / OS logout: run the shared
///    clean-shutdown routine. The native side replied `.terminateLater`, so
///    awaiting [performQuit] here is what gates termination on the daemon
///    actually stopping (the method-call result fires the Swift completion).
void installLifecycleHandlers(ProviderContainer container) {
  if (kIsWeb || !Platform.isMacOS) return;
  const channel = MethodChannel('kwaai/lifecycle');
  channel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'reopenWindow':
        _log('reopen requested — showing window');
        await DockIcon.setVisible(true);
        await windowManager.show();
        await windowManager.focus();
      case 'performQuit':
        _log('OS terminate requested — clean shutdown');
        await performQuit(container, osTerminating: true);
    }
  });
}
