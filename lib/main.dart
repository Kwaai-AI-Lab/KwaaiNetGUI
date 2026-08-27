import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_window_utils/macos_window_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:window_manager/window_manager.dart';

import 'src/chat/kwaai_rpc_client.dart';
import 'src/daemon/daemon_controller.dart';
import 'src/daemon/daemon_state.dart';
import 'src/daemon/status_watcher.dart';
import 'src/settings.dart';
import 'src/tray/tray.dart';
import 'src/update/release_checker.dart';
import 'src/update/update_controller.dart';
import 'src/ui/pages/main_page.dart';
import 'src/ui/theme/theme_controller.dart';
import 'src/ui/theme/theme_variants.dart';
import 'src/window/close_handler.dart';
import 'src/window/dock_icon.dart';
import 'src/window/shutdown.dart';
import 'src/window/shutdown_gate.dart';
import 'src/window/tooltip_resize_guard.dart';
import 'src/window/window_focus.dart';

/// Mirror framework and isolate-level errors to stderr.
///
/// A build/layout assertion is normally reported only through the debugger.
/// If the paused isolate belongs to a VS Code window other than the one in
/// front of you — easy to hit with several windows open, or with a stale
/// `flutter run` still holding the DDS connection — the app just freezes with
/// an empty Call Stack and a clean Debug Console, and nothing names the
/// widget that failed. Writing to stderr as well means the assertion text and
/// its stack land in the run log no matter which session owns the pause.
///
/// [FlutterError.presentError] is still called first so the usual red error
/// box and DevTools reporting are unchanged.
void _installErrorHandlers() {
  final priorOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    (priorOnError ?? FlutterError.presentError)(details);
    stderr.writeln('[flutter-error] ${details.exceptionAsString()}');
    if (details.stack != null) {
      stderr.writeln(
        FlutterError.defaultStackFilter(
          details.stack.toString().trimRight().split('\n'),
        ).join('\n'),
      );
    }
  };

  // Errors that escape the framework entirely (async gaps, platform
  // channel callbacks) never reach FlutterError.onError.
  PlatformDispatcher.instance.onError = (error, stack) {
    stderr.writeln('[uncaught] $error\n$stack');
    return true; // handled — do not tear the isolate down
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Before any window or plugin setup, so failures in that setup are
  // reported too.
  _installErrorHandlers();
  await windowManager.ensureInitialized();
  await windowManager.setTitle('KwaaiNet');
  await windowManager.setMinimumSize(const Size(560, 400));

  if (!kIsWeb && Platform.isMacOS) {
    await WindowManipulator.initialize();
    await WindowManipulator.makeTitlebarTransparent();
    await WindowManipulator.enableFullSizeContentView();
    await WindowManipulator.addToolbar();
    await WindowManipulator.setToolbarStyle(
      toolbarStyle: NSWindowToolbarStyle.unified,
    );
    await WindowManipulator.hideTitle();
  }

  final settings = await Settings.load();
  final theme = await ThemeController.load();
  final daemon = DaemonController(settings);
  final watcher = StatusWatcher(daemon: daemon)..start();

  // Riverpod container — created here so the tray (non-widget) can read /
  // invoke provider actions, and shared with the widget tree via
  // UncontrolledProviderScope.
  // late: appContainerProvider's override closure needs the container that is
  // being constructed here, so it can only resolve lazily on first read.
  late final ProviderContainer container;
  container = ProviderContainer(
    overrides: [
      daemonControllerProvider.overrideWithValue(daemon),
      statusWatcherProvider.overrideWithValue(watcher),
      // Expose the app-wide Settings so providers (e.g. the update notifier
      // persisting a skipped version) can reach it.
      settingsProvider.overrideWithValue(settings),
      // Seed the localChatEnabled provider from the durable setting so
      // the main page's tab bar reflects the user's last choice on
      // first paint.
      localChatEnabledProvider.overrideWith((_) => settings.localChatEnabled),
      // Seed the skipped-version mirror so the update banner suppresses a
      // previously-skipped release on first paint.
      skippedVersionProvider.overrideWith((_) => settings.skippedVersion),
      // Seed the auto-download mirror so the update controller sees the
      // user's choice on the first pending release.
      autoDownloadUpdatesProvider.overrideWith(
        (_) => settings.autoDownloadUpdates,
      ),
      // Lets the update controller reach performQuit for the swap-and-restart.
      appContainerProvider.overrideWith((ref) => container),
    ],
  );

  // Gate the gRPC client's connection probe on the daemon status.
  // No point sending Ping every 3 s when we already know the daemon
  // isn't running — that just floods the logs with connect-refused.
  // Flip back on as soon as the daemon comes up.
  //
  // IMPORTANT: only act on a confirmed running/not-running reading,
  // never on AsyncValue.loading (which flickers between status polls).
  // Edge-trigger via lastKnown so flapping doesn't tear down and
  // rebuild the channel on every poll.
  // Only when this app owns the daemon. An explicit KWAAINET_GRPC_PORT names
  // one running elsewhere — typically a container, whose pid does not exist on
  // this host — so the local reading is always "stopped" and would switch
  // probing off permanently, guaranteeing the connection it is meant to
  // report on can never come up. Probe continuously in that case and let
  // reachability speak for itself.
  if (!grpcPortOverridden) {
    bool? lastKnownRunning;
    container.listen<AsyncValue<NodeStatus>>(daemonStatusProvider, (_, next) {
      final v = next.valueOrNull;
      if (v == null) return; // not a confirmed reading yet — leave probe as-is
      final running = v.running;
      if (running == lastKnownRunning) return;
      lastKnownRunning = running;
      container.read(kwaaiRpcClientProvider).setProbingEnabled(running);
    }, fireImmediately: true);
  }

  final tray = TrayController(container: container);
  // Only install the menu-bar icon when the user opts in. The toggle in
  // Settings → Status flips it at runtime via tray.setEnabled().
  if (settings.keepInTrayOnClose) {
    await tray.init();
  }
  final windowFocus = WindowFocusNotifier()..attach();
  await WindowCloseHandler(settings, tray, container).attach();
  // Handle macOS lifecycle callbacks: Dock-icon re-clicks / Finder reopens
  // (restore the window) and OS terminate / Cmd-Q (clean daemon shutdown).
  installLifecycleHandlers(container);

  // Auto-start the service at boot if the user has it enabled and the
  // daemon isn't already running. Goes through the same transition
  // provider as the buttons/tray, so the main UI immediately shows
  // "Starting…" and the overlay engages until the watcher confirms.
  if (settings.startServiceOnStartup &&
      settings.mode != DaemonMode.external &&
      !(await daemon.isAlive())) {
    // Fire-and-forget — start() awaits the controller call but we don't
    // want to block the app from coming up while the daemon spins up.
    unawaited(container.read(daemonTransitionProvider.notifier).start());
  }

  // Kick off the GUI self-update check now so it runs even if the window
  // starts hidden to the tray (the banner would otherwise be the only
  // reader that triggers the fetch). No-op in debug builds — the notifier
  // gates the network call on kReleaseMode.
  container.read(updateAvailabilityProvider);
  // Read the install half too, so an auto-download starts even when the
  // window opens hidden to the tray and no banner is ever built.
  container.read(updateStageProvider);
  unawaited(
    PackageInfo.fromPlatform().then(
      (i) => sweepStaleUpdates(ReleaseChecker.normalizeVersion(i.version)),
    ),
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: KwaainetGuiApp(
        daemon: daemon,
        settings: settings,
        watcher: watcher,
        theme: theme,
        windowFocus: windowFocus,
        tray: tray,
      ),
    ),
  );
}

class KwaainetGuiApp extends StatelessWidget {
  const KwaainetGuiApp({
    super.key,
    required this.daemon,
    required this.settings,
    required this.watcher,
    required this.theme,
    required this.windowFocus,
    required this.tray,
  });

  final DaemonController daemon;
  final Settings settings;
  final StatusWatcher watcher;
  final ThemeController theme;
  final WindowFocusNotifier windowFocus;
  final TrayController tray;

  @override
  Widget build(BuildContext context) {
    return TooltipResizeGuard(
      child: WindowFocusScope(
        notifier: windowFocus,
        child: ThemeScope(
          controller: theme,
          child: AnimatedBuilder(
            animation: theme,
            builder: (context, _) {
              final state = theme.state;
              final lightTheme = buildKwaaiTheme(
                state.lightVariant,
                Brightness.light,
              );
              final darkTheme = buildKwaaiTheme(
                state.darkVariant,
                Brightness.dark,
              );
              final themeMode = switch (state.mode) {
                AppThemeMode.auto => ThemeMode.system,
                AppThemeMode.light => ThemeMode.light,
                AppThemeMode.dark => ThemeMode.dark,
              };
              return MaterialApp(
                title: 'KwaaiNet',
                theme: lightTheme,
                darkTheme: darkTheme,
                themeMode: themeMode,
                // Wrap every route so a quit replaces the whole window (main
                // page or settings) with the "Stopping service…" screen.
                builder: (context, child) =>
                    ShutdownGate(child: child ?? const SizedBox.shrink()),
                home: MainPage(daemon: daemon, settings: settings, tray: tray),
              );
            },
          ),
        ),
      ),
    );
  }
}
