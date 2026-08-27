import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'dock_icon.dart';

void _log(String msg) {
  stderr.writeln('[window-restore] $msg');
}

/// Ticks each time something outside the widget tree asks for the main
/// window — the tray's left click today. MainPage listens and returns to
/// Chat, dropping any route pushed over it.
class OpenAtChatNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state = state + 1;
}

final openAtChatProvider = NotifierProvider<OpenAtChatNotifier, int>(
  OpenAtChatNotifier.new,
);

/// Brings the window back from a hide-to-tray and puts Chat in front.
///
/// The request is made before the window is shown so the tab switch happens
/// off-screen rather than as a visible flick after it appears.
Future<void> openMainWindowAtChat(ProviderContainer container) async {
  try {
    container.read(openAtChatProvider.notifier).request();
    // The window may be hidden to tray and the Dock icon hidden with it
    // (activation policy = .accessory). Restore both.
    await DockIcon.setVisible(true);
    await windowManager.setSkipTaskbar(false);
    await windowManager.show();
    await windowManager.focus();
    _log('window restored at chat');
  } catch (e, st) {
    _log('show window failed: $e\n$st');
  }
}
