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

/// Where the install sits in the download → verify → ready → restart cycle.
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
  const UpdateReady({
    required this.version,
    required this.stagedPath,
    required this.stagePath,
  });

  /// The version actually staged — not necessarily the newest one detected
  /// since, so the banner offers what a restart would really install.
  final String version;
  final String stagedPath;
  final String stagePath;
}

class UpdateFailed extends UpdateStage {
  const UpdateFailed(this.message);
  final String message;
}

/// Raised internally when a run is superseded or cancelled. Never surfaces.
class _Cancelled implements Exception {
  const _Cancelled();
}

/// The filesystem/process half of installing, behind one object so the state
/// machine can be driven in tests without a real install to swap.
class UpdateInstallOps {
  const UpdateInstallOps();

  InstallRoot? resolveRoot() => resolveInstallRoot();

  Future<bool> writable(InstallRoot root) => isWritable(root);

  Future<Directory> unpack(File archive, InstallRoot root, String version) =>
      extract(archive, root, version);

  Future<bool> exists(String path) => Directory(path).exists();

  /// Writes the helper to [path] and starts it detached. Writing and starting
  /// live together so a test can stub both without touching the real home dir.
  Future<void> launchHelper({
    required String path,
    required String script,
    required bool windows,
  }) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(script);
    if (!windows) await Process.run('chmod', ['0700', path]);
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
              path,
            ]
          : [path],
      mode: ProcessStartMode.detached,
    );
  }

  Future<void> quit(ProviderContainer container) => performQuit(container);
}

final updateInstallOpsProvider = Provider<UpdateInstallOps>(
  (ref) => const UpdateInstallOps(),
);

final updateDownloaderProvider = Provider<UpdateDownloader>((ref) {
  final d = UpdateDownloader();
  ref.onDispose(d.dispose);
  return d;
});

/// The [kUpdatesEnabled] compile-time gate, as a provider so tests can drive
/// the state machine without a release build. Production never overrides it.
final updatesEnabledProvider = Provider<bool>((ref) => kUpdatesEnabled);

/// The swappable install root, or null in debug / an unrecognised layout.
final installRootProvider = Provider<InstallRoot?>((ref) {
  if (!ref.watch(updatesEnabledProvider)) return null;
  return ref.watch(updateInstallOpsProvider).resolveRoot();
});

/// Resolvable *and* writable — the full condition for installing in place. A
/// read-only /Applications or /opt resolves false, and the banner then keeps
/// today's open-the-release-page behaviour instead of failing at download.
final updateInstallSupportedProvider = FutureProvider<bool>((ref) async {
  final root = ref.watch(installRootProvider);
  if (root == null) return false;
  return ref.watch(updateInstallOpsProvider).writable(root);
});

/// Drives the install half of the updater. Detection, "Later" and "Skip" stay
/// in [UpdateAvailabilityNotifier]; this only ever acts on what that offers.
class UpdateInstallNotifier extends Notifier<UpdateStage> {
  StreamSubscription<DownloadProgress>? _sub;
  Completer<void>? _completer;
  String? _activeVersion;
  bool _inFlight = false;
  bool _installing = false;

  /// Bumped by anything that supersedes a run. A run whose generation is stale
  /// must not touch [state] again — that is what stops a cancelled download's
  /// continuation overwriting the user's Idle with Ready or Failed.
  int _generation = 0;

  @override
  UpdateStage build() {
    ref.onDispose(() => _sub?.cancel());
    ref.listen<ReleaseInfo?>(updateBannerProvider, (_, next) {
      if (next != null) _maybeAutoStart(next);
    }, fireImmediately: true);
    return const UpdateIdle();
  }

  InstallRoot? get _root => ref.read(installRootProvider);

  Future<void> _maybeAutoStart(ReleaseInfo release) async {
    if (!ref.read(autoDownloadUpdatesProvider)) return;
    if (state is! UpdateIdle) return;
    // A non-writable root degrades quietly to the browser fallback rather
    // than showing a failure banner on every launch.
    if (!await ref.read(updateInstallSupportedProvider.future)) return;
    if (state is! UpdateIdle) return;
    await start(release);
  }

  /// Downloads, verifies and stages [release]. Single-flight.
  Future<void> start([ReleaseInfo? release]) async {
    final target = release ?? ref.read(updateTrayProvider);
    if (target == null || !ref.read(updatesEnabledProvider)) return;
    // The in-flight marker is set before the first await, so two near
    // simultaneous calls cannot both get past this.
    if (_inFlight || _installing) return;
    if (_activeVersion == target.version && state is! UpdateFailed) return;
    // Defence in depth — fetchLatest already refuses an invalid tag, and this
    // version reaches a shell script and a filesystem path.
    if (!ReleaseChecker.isValidVersion(target.version)) {
      state = const UpdateFailed('The release version is not recognised.');
      return;
    }

    final root = _root;
    if (root == null) {
      state = const UpdateFailed('This install cannot be updated in place.');
      return;
    }
    final asset = target.assetFor(ReleaseChecker.currentPlatformKey());
    if (asset == null) {
      state = const UpdateFailed('No download is published for this platform.');
      return;
    }

    final gen = ++_generation;
    _inFlight = true;
    _activeVersion = target.version;
    state = const UpdateDownloading(null);

    try {
      if (!await ref.read(updateInstallOpsProvider).writable(root)) {
        throw UpdateInstallException(
          'The install folder is not writable by this user.',
        );
      }
      if (gen != _generation) throw const _Cancelled();

      final dest = File(
        '${KwaainetPaths.updatesDir}${Platform.pathSeparator}'
        '${target.version}${Platform.pathSeparator}${asset.name}',
      );
      await _runDownload(asset, dest, gen);
      if (gen != _generation) throw const _Cancelled();

      // Spans the unpack and, on macOS, the codesign --verify that must pass
      // before anything is swapped. The digest was checked inside download().
      state = const UpdateVerifying();
      final staged = await ref
          .read(updateInstallOpsProvider)
          .unpack(dest, root, target.version);
      if (gen != _generation) throw const _Cancelled();

      state = UpdateReady(
        version: target.version,
        stagedPath: staged.path,
        stagePath: stagePathFor(root, target.version),
      );
      _log('staged ${target.version} at ${staged.path}');
    } on _Cancelled {
      _log('run for ${target.version} superseded — cleaning up');
      await _cleanupFor(root, target.version);
    } catch (e) {
      _log('install failed: $e');
      await _cleanupFor(root, target.version);
      if (gen == _generation) {
        _activeVersion = null;
        state = UpdateFailed(_message(e));
      }
    } finally {
      _inFlight = false;
      _sub = null;
      _completer = null;
    }
  }

  /// Bridges the download stream onto a future that [cancel] can also
  /// complete — without that, a cancelled subscription fires neither onDone
  /// nor onError and this frame would hang forever.
  Future<void> _runDownload(ReleaseAsset asset, File dest, int gen) {
    final completer = Completer<void>();
    _completer = completer;
    _sub = ref
        .read(updateDownloaderProvider)
        .download(asset, dest: dest)
        .listen(
          (p) {
            if (gen == _generation) state = UpdateDownloading(p.fraction);
          },
          onError: (Object e) {
            if (!completer.isCompleted) completer.completeError(e);
          },
          onDone: () {
            if (!completer.isCompleted) completer.complete();
          },
          cancelOnError: true,
        );
    return completer.future;
  }

  /// Aborts an in-flight run and removes everything it wrote. Safe at any
  /// stage: work already past the download is left to finish, but its
  /// generation is stale so it can no longer change [state].
  Future<void> cancel() async {
    if (state is UpdateIdle) return;
    _generation++;
    final version = _activeVersion;
    _activeVersion = null;
    final wasInFlight = _inFlight;
    // Not awaited: cancelling an async* subscription only takes effect at the
    // generator's next yield, so a stalled download would freeze the UI here.
    // The stale generation stops any late state write; the downloader's
    // finally still deletes the partial whenever it does unwind.
    unawaited(_sub?.cancel() ?? Future<void>.value());
    _sub = null;
    // Already completed once the download is done and the unpack is running.
    final c = _completer;
    if (c != null && !c.isCompleted) c.completeError(const _Cancelled());
    _completer = null;
    state = const UpdateIdle();
    // A live run cleans up in its own finally; only clean here when there
    // isn't one, or we would delete files out from under a running ditto.
    if (!wasInFlight && version != null) {
      final root = _root;
      if (root != null) await _cleanupFor(root, version);
    }
  }

  /// Clears a failure so the banner's Retry can start clean.
  void dismiss() {
    if (state is UpdateFailed) state = const UpdateIdle();
  }

  Future<void> retry() async {
    if (_inFlight || _installing) return;
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
    // Latched before the first await. The shutdown overlay engages several
    // awaits later and does not cover the native tray menu, so without this a
    // second click launches a second helper against the same pid — and two
    // helpers racing on `$TARGET.old` can destroy the installed app.
    if (_installing) return;
    _installing = true;

    final root = _root;
    if (root == null) {
      _installing = false;
      return;
    }

    final ops = ref.read(updateInstallOpsProvider);
    // Re-validate: the probe ran at download time, and the staged build may
    // have been swept or the install made read-only since.
    if (!await ops.exists(ready.stagedPath) || !await ops.writable(root)) {
      _installing = false;
      _activeVersion = null;
      state = const UpdateFailed(
        'The prepared update is no longer available. Try again.',
      );
      return;
    }

    final windows = root.kind == InstallKind.windowsDir;
    final path =
        '${KwaainetPaths.updatesDir}${Platform.pathSeparator}${ready.version}'
        '${Platform.pathSeparator}${windows ? 'swap.ps1' : 'swap.sh'}';
    try {
      _log('launching swap helper $path');
      await ops.launchHelper(
        path: path,
        script: swapScript(
          pid: pid,
          target: root.path,
          staged: ready.stagedPath,
          stage: ready.stagePath,
          relaunch: relaunchCommand(root),
          kind: root.kind,
        ),
        windows: windows,
      );
    } catch (e) {
      _log('could not launch the swap helper: $e');
      _installing = false;
      state = const UpdateFailed('Could not start the update. Try again.');
      return;
    }

    await ops.quit(ref.read(appContainerProvider));
  }

  Future<void> _cleanupFor(InstallRoot root, String version) async {
    for (final path in [
      stagePathFor(root, version),
      '${KwaainetPaths.updatesDir}${Platform.pathSeparator}$version',
    ]) {
      try {
        final dir = Directory(path);
        if (await dir.exists()) await dir.delete(recursive: true);
      } catch (_) {}
    }
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

/// Startup housekeeping: drops downloads for versions no newer than [current],
/// and every staged bundle beside the install root. A stage dir surviving into
/// a new launch is dead by definition — a successful swap deletes its own, and
/// these run ~150 MB each. Never allowed to block startup.
Future<void> sweepStaleUpdates(String current, {InstallRoot? root}) async {
  try {
    final dir = Directory(KwaainetPaths.updatesDir);
    if (await dir.exists()) {
      await for (final entry in dir.list()) {
        if (entry is! Directory) continue;
        final name = entry.path.split(Platform.pathSeparator).last;
        if (!ReleaseChecker.isNewer(name, current)) {
          await entry.delete(recursive: true);
        }
      }
    }
  } catch (_) {}

  final r = root;
  if (r == null) return;
  try {
    await for (final entry in Directory(r.parentPath).list()) {
      if (entry is! Directory) continue;
      final name = entry.path.split(RegExp(r'[/\\]')).last;
      if (name.startsWith('.kwaainet-update-')) {
        await entry.delete(recursive: true);
      }
    }
  } catch (_) {}
}
