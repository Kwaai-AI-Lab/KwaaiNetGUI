import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../daemon/paths.dart';
import '../settings.dart';
import '../window/shutdown.dart';
import 'release_checker.dart';
import 'update_downloader.dart';
import 'update_installer.dart';

void _log(String msg) => stderr.writeln('[update] $msg');

/// Where the install sits in the download → verify → stage → restart cycle.
sealed class UpdateStage {
  const UpdateStage();
}

class UpdateIdle extends UpdateStage {
  const UpdateIdle();
}

class UpdateDownloading extends UpdateStage {
  const UpdateDownloading(this.progress);

  /// 0..1, or null while the total size is unknown.
  final double? progress;
}

class UpdateVerifying extends UpdateStage {
  const UpdateVerifying();
}

class UpdateReady extends UpdateStage {
  const UpdateReady({required this.stagedPath, required this.stagePath});
  final String stagedPath;
  final String stagePath;
}

class UpdateFailed extends UpdateStage {
  const UpdateFailed(this.message);
  final String message;
}

final updateDownloaderProvider = Provider<UpdateDownloader>((ref) {
  final d = UpdateDownloader();
  ref.onDispose(d.dispose);
  return d;
});

/// Drives the install half of the updater. Detection, "Later" and "Skip" stay
/// in [UpdateAvailabilityNotifier]; this only ever acts on what that offers.
class UpdateInstallNotifier extends Notifier<UpdateStage> {
  StreamSubscription<DownloadProgress>? _sub;
  String? _activeVersion;
  InstallRoot? _root;

  @override
  UpdateStage build() {
    _root = kUpdatesEnabled ? resolveInstallRoot() : null;
    ref.onDispose(() => _sub?.cancel());
    ref.listen<ReleaseInfo?>(updateBannerProvider, (_, next) {
      if (next != null) _maybeAutoStart(next);
    }, fireImmediately: true);
    return const UpdateIdle();
  }

  /// True when this build could install an update at all. False in debug, or
  /// when the app isn't running from a packaged layout — the banner then
  /// keeps today's open-the-release-page behaviour.
  bool get installSupported => kUpdatesEnabled && _root != null;

  void _maybeAutoStart(ReleaseInfo release) {
    if (!installSupported) return;
    if (!ref.read(autoDownloadUpdatesProvider)) return;
    if (state is! UpdateIdle) return;
    // Deferred: listen fires during build(), where setting state would throw.
    Future.microtask(() => start(release));
  }

  /// Downloads, verifies and stages [release]. Single-flight per version.
  Future<void> start([ReleaseInfo? release]) async {
    final target = release ?? ref.read(updateTrayProvider);
    if (target == null) return;
    if (_activeVersion == target.version && state is! UpdateFailed) return;
    if (!kUpdatesEnabled) return;

    final root = _root;
    if (root == null) {
      state = const UpdateFailed('This install cannot be updated in place.');
      return;
    }
    if (!await isWritable(root)) {
      state = const UpdateFailed(
        'The install folder is not writable by this user.',
      );
      return;
    }
    final asset = target.assetFor(ReleaseChecker.currentPlatformKey());
    if (asset == null) {
      state = const UpdateFailed('No download is published for this platform.');
      return;
    }

    _activeVersion = target.version;
    state = const UpdateDownloading(null);

    final dest = File(
      '${KwaainetPaths.updatesDir}${Platform.pathSeparator}'
      '${target.version}${Platform.pathSeparator}${asset.name}',
    );
    final completer = Completer<void>();
    await _sub?.cancel();
    _sub = ref
        .read(updateDownloaderProvider)
        .download(asset, dest: dest)
        .listen(
          (p) => state = UpdateDownloading(p.fraction),
          onError: (Object e) {
            if (!completer.isCompleted) completer.completeError(e);
          },
          onDone: () {
            if (!completer.isCompleted) completer.complete();
          },
          cancelOnError: true,
        );

    try {
      await completer.future;
      // Spans the unpack and, on macOS, the codesign --verify that must pass
      // before anything is swapped. The digest was checked inside download().
      state = const UpdateVerifying();
      final staged = await extract(dest, root, target.version);
      state = UpdateReady(
        stagedPath: staged.path,
        stagePath: stagePathFor(root, target.version),
      );
      _log('staged ${target.version} at ${staged.path}');
    } catch (e) {
      _log('install failed: $e');
      _activeVersion = null;
      await _cleanupStage(root, target.version);
      state = UpdateFailed(_message(e));
    } finally {
      _sub = null;
    }
  }

  /// Aborts an in-flight download and removes everything it wrote.
  Future<void> cancel() async {
    final version = _activeVersion;
    await _sub?.cancel();
    _sub = null;
    _activeVersion = null;
    if (version != null) {
      final root = _root;
      if (root != null) await _cleanupStage(root, version);
      try {
        final dir = Directory(
          '${KwaainetPaths.updatesDir}${Platform.pathSeparator}$version',
        );
        if (await dir.exists()) await dir.delete(recursive: true);
      } catch (_) {}
    }
    state = const UpdateIdle();
  }

  /// Clears a failure so the banner's Retry can start clean.
  void dismiss() {
    if (state is UpdateFailed) state = const UpdateIdle();
  }

  Future<void> retry() async {
    _activeVersion = null;
    state = const UpdateIdle();
    await start();
  }

  /// Launches the detached swap helper, then quits cleanly. The helper is
  /// already polling our pid when we start dying, so this ordering is safe —
  /// and [performQuit] stops the daemon first, which Windows requires before
  /// the install directory can be renamed.
  Future<void> installAndRestart() async {
    final ready = state;
    if (ready is! UpdateReady) return;
    final root = _root;
    final version = _activeVersion;
    if (root == null || version == null) return;

    final windows = root.kind == InstallKind.windowsDir;
    final script = File(
      '${KwaainetPaths.updatesDir}${Platform.pathSeparator}$version'
      '${Platform.pathSeparator}${windows ? 'swap.ps1' : 'swap.sh'}',
    );
    await script.parent.create(recursive: true);
    await script.writeAsString(
      swapScript(
        pid: pid,
        target: root.path,
        staged: ready.stagedPath,
        stage: ready.stagePath,
        relaunch: relaunchCommand(root),
        kind: root.kind,
      ),
    );
    if (!windows) await Process.run('chmod', ['0700', script.path]);

    _log('launching swap helper ${script.path}');
    await Process.start(
      windows ? 'powershell' : '/bin/sh',
      windows
          ? [
              '-NoProfile',
              '-WindowStyle',
              'Hidden',
              '-ExecutionPolicy',
              'Bypass',
              '-File',
              script.path,
            ]
          : [script.path],
      mode: ProcessStartMode.detached,
    );

    await performQuit(ref.read(appContainerProvider));
  }

  Future<void> _cleanupStage(InstallRoot root, String version) async {
    try {
      final dir = Directory(stagePathFor(root, version));
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  String _message(Object e) => switch (e) {
    UpdateDownloadException() => e.message,
    UpdateInstallException() => e.message,
    _ => 'Couldn\'t download the update.',
  };
}

final updateStageProvider =
    NotifierProvider<UpdateInstallNotifier, UpdateStage>(
      UpdateInstallNotifier.new,
    );

/// Deletes staged downloads for versions no newer than [current]. Housekeeping
/// only — a failure here must never block startup.
Future<void> sweepStaleUpdates(String current) async {
  try {
    final dir = Directory(KwaainetPaths.updatesDir);
    if (!await dir.exists()) return;
    await for (final entry in dir.list()) {
      if (entry is! Directory) continue;
      final name = entry.path.split(Platform.pathSeparator).last;
      if (!ReleaseChecker.isNewer(name, current)) {
        await entry.delete(recursive: true);
      }
    }
  } catch (_) {}
}
