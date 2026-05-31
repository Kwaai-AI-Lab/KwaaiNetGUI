import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var lifecycleChannel: FlutterMethodChannel?

  /// True once Dart has finished its clean shutdown and macOS is clear to
  /// terminate. Guards re-entrancy if applicationShouldTerminate fires twice.
  private var readyToTerminate = false

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // Let the Flutter-side WindowCloseHandler decide whether to quit or
    // hide to the menu-bar tray. Returning true here pre-empts that.
    return false
  }

  /// Cmd-Q, the Apple-menu Quit, and OS logout/shutdown all land here. Run the
  /// same clean shutdown the window/tray paths use (stop the daemon via
  /// `kwaainet stop`), then let macOS terminate. We reply `.terminateLater`
  /// and call `reply(toApplicationShouldTerminate:)` once Dart signals it's
  /// done, so the daemon and its children are reaped before we exit.
  override func applicationShouldTerminate(
    _ sender: NSApplication
  ) -> NSApplication.TerminateReply {
    if readyToTerminate {
      return .terminateNow
    }
    guard let channel = lifecycleChannel else {
      // No Dart channel yet (very early launch) — nothing to clean up.
      return .terminateNow
    }
    channel.invokeMethod("performQuit", arguments: nil) { _ in
      // Dart finished (or errored) — let macOS proceed with termination.
      self.readyToTerminate = true
      NSApp.reply(toApplicationShouldTerminate: true)
    }
    return .terminateLater
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// Dock-icon click / Finder re-launch while the app is hidden. Do the
  /// window-front work natively so the user gets an immediate response
  /// even if the Dart isolate is busy (post-sleep wake, GC, etc.) —
  /// previously this round-tripped through Dart, which let AppKit decide
  /// the app was unresponsive and swap the Dock menu's Quit for Force
  /// Quit. Dart is still notified afterward so any in-Dart "window
  /// visible" state stays in sync.
  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    NSApp.setActivationPolicy(.regular)
    NSApp.unhide(nil)
    NSApp.activate(ignoringOtherApps: true)
    for window in sender.windows {
      if window.isMiniaturized {
        window.deminiaturize(nil)
      }
      window.setIsVisible(true)
      window.makeKeyAndOrderFront(nil)
    }
    lifecycleChannel?.invokeMethod("reopenWindow", arguments: nil)
    return true
  }

  /// Wires the `kwaai/lifecycle` method channel. Called from
  /// MainFlutterWindow.awakeFromNib so the channel is registered before
  /// Dart's first call.
  func installLifecycleChannel(messenger: FlutterBinaryMessenger) {
    guard lifecycleChannel == nil else { return }
    let channel = FlutterMethodChannel(
      name: "kwaai/lifecycle",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "setDockIconVisible":
        let visible = (call.arguments as? Bool) ?? true
        NSApp.setActivationPolicy(visible ? .regular : .accessory)
        if visible {
          NSApp.activate(ignoringOtherApps: true)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    lifecycleChannel = channel
  }
}
