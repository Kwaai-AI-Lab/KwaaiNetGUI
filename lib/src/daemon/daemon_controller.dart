import 'dart:convert';
import 'dart:io';

import '../settings.dart';
import 'paths.dart';

void _log(String msg) {
  stderr.writeln('[daemon-controller] $msg');
}

class DaemonResolution {
  DaemonResolution({
    required this.path,
    required this.exists,
    required this.source,
  });
  final String path;
  final bool exists;
  final String source;
}

class DaemonController {
  DaemonController(this._settings);

  final Settings _settings;

  /// Resolve the binary for [mode], defaulting to the currently-selected
  /// mode. The settings UI passes an explicit mode so it can show each
  /// option's binary without having to select it first.
  DaemonResolution resolveBinary([DaemonMode? mode]) {
    switch (mode ?? _settings.mode) {
      case DaemonMode.builtIn:
        final p = builtInDebugDaemonPath;
        return DaemonResolution(
          path: p,
          exists: File(p).existsSync(),
          source: 'built-in (debug)',
        );
      case DaemonMode.system:
        final p = _whichKwaainet();
        return DaemonResolution(
          path: p ?? 'kwaainet',
          exists: p != null,
          source: 'system PATH',
        );
      case DaemonMode.custom:
        final p = _settings.customPath ?? '';
        return DaemonResolution(
          path: p,
          exists: p.isNotEmpty && File(p).existsSync(),
          source: 'custom path',
        );
      case DaemonMode.external:
        // The app neither launches nor manages the binary in this mode —
        // some external supervisor (launchd, systemd, Docker, manual
        // shell) runs it. resolveBinary() is still called by the
        // settings UI for display, so return a stable descriptor.
        return DaemonResolution(
          path: '',
          exists: false,
          source: 'externally managed',
        );
    }
  }

  /// Tail of the version-probe queue. Each [binaryVersion] call chains onto
  /// the previous one so at most one `--version` child process exists at a
  /// time — the settings page asks about several modes at once, and fanning
  /// those out concurrently would spike load on a low-power machine for no
  /// benefit. Probes are cheap and the UI reveals each row as it resolves,
  /// so serial costs nothing perceptible.
  Future<void> _versionQueue = Future.value();

  /// Version string of the binary [mode] resolves to (default: the selected
  /// mode), obtained by running `<binary> --version`.
  ///
  /// Serialized against every other in-flight call — see [_versionQueue].
  ///
  /// Returns null when there is nothing to interrogate — external mode (the
  /// app doesn't know which binary the supervisor launched), an unresolved or
  /// missing path, a non-zero exit, or output that doesn't look like a
  /// version. Callers render "unknown" rather than distinguishing the cases.
  ///
  /// `kwaainet --version` prints `kwaainet 0.5.4`; strip the leading binary
  /// name so the caller gets a bare `0.5.4`.
  Future<String?> binaryVersion([DaemonMode? mode]) {
    // Resolve *before* queueing: it's a cheap stat, and doing it up front
    // means a missing binary costs nothing and never occupies the queue.
    final r = resolveBinary(mode);
    if (!r.exists || r.path.isEmpty) return Future.value(null);

    final result = _versionQueue.then((_) => _probeVersion(r.path));
    // Keep the chain alive even if a probe throws — _probeVersion already
    // swallows its own errors, but a broken link here would wedge every
    // subsequent probe behind a permanently-failed future.
    _versionQueue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<String?> _probeVersion(String path) async {
    try {
      final proc = await Process.run(path, [
        '--version',
      ]).timeout(const Duration(seconds: 5));
      if (proc.exitCode != 0) {
        _log('--version exited ${proc.exitCode} for $path');
        return null;
      }
      return parseVersionOutput(proc.stdout as String);
    } catch (e) {
      _log('--version failed for $path: $e');
      return null;
    }
  }

  /// Extracts the bare version from `kwaainet --version` output.
  ///
  /// `kwaainet 0.5.4` → `0.5.4`. Only the first line is considered, so a
  /// binary that appends an update hint or banner still parses. Returns null
  /// for empty output or a trailing token that isn't digit-led (e.g. a usage
  /// string from an older binary that doesn't understand `--version`).
  static String? parseVersionOutput(String stdout) {
    final first = stdout.trim().split('\n').first.trim();
    if (first.isEmpty) return null;
    final space = first.lastIndexOf(' ');
    final token = space == -1 ? first : first.substring(space + 1);
    // Tolerate a `v` prefix; require the rest to start with a digit so
    // arbitrary prose doesn't get rendered as a version.
    final bare = token.startsWith('v') || token.startsWith('V')
        ? token.substring(1)
        : token;
    if (bare.isEmpty || !RegExp(r'^\d').hasMatch(bare)) return null;
    return bare;
  }

  String? findSystemBinary() => _whichKwaainet();

  String? _whichKwaainet() {
    final exeName = Platform.isWindows ? 'kwaainet.exe' : 'kwaainet';
    final paths = (Platform.environment['PATH'] ?? '').split(
      Platform.isWindows ? ';' : ':',
    );
    for (final dir in paths) {
      if (dir.isEmpty) continue;
      final candidate = '$dir${Platform.pathSeparator}$exeName';
      if (File(candidate).existsSync()) return candidate;
    }
    return null;
  }

  int? readPid() {
    final f = File(KwaainetPaths.pidFile);
    if (!f.existsSync()) return null;
    return int.tryParse(f.readAsStringSync().trim());
  }

  Future<bool> isAlive() async {
    final pid = readPid();
    if (pid == null) return false;
    return _processExists(pid);
  }

  Future<bool> _processExists(int pid) async {
    if (Platform.isWindows) {
      final r = await Process.run('tasklist', ['/FI', 'PID eq $pid', '/NH']);
      return r.stdout.toString().contains('$pid');
    }
    final r = await Process.run('kill', ['-0', '$pid']);
    return r.exitCode == 0;
  }

  Future<DaemonStartResult> start() async {
    _log('start() invoked');
    if (_settings.mode == DaemonMode.external) {
      _log('external mode — refusing to spawn (managed by user)');
      // Not an error — the GUI shows a dedicated "managed externally"
      // note in the status card instead of the bottom error bar.
      return DaemonStartResult.externalNoop();
    }
    if (await isAlive()) {
      final pid = readPid()!;
      _log('daemon already running (pid $pid) — attaching');
      return DaemonStartResult.alreadyRunning(pid);
    }
    final res = resolveBinary();
    _log('resolved daemon: ${res.path} (${res.source}, exists=${res.exists})');
    if (!res.exists) {
      _log('ABORT: binary not found');
      final where = res.path.isEmpty ? '(none)' : res.path;
      return DaemonStartResult.error(
        'Daemon binary not found at $where (${res.source})',
      );
    }
    Directory(KwaainetPaths.runDir).createSync(recursive: true);

    try {
      _log('spawning: ${res.path} start --daemon');
      // Suppress the daemon's in-process auto-updater. The GUI will own
      // notifying the user about new versions (forthcoming) — without
      // this the daemon silently swaps its own binary for the latest
      // upstream release ~5 minutes into a session and exits to
      // restart, which loses any locally-built feature work (e.g. a
      // newly-added rpc crate not yet in any release). See the
      // KWAAINET_NO_AUTO_UPDATE guard in kwaainet's node.rs.
      final env = Map<String, String>.from(Platform.environment)
        ..['KWAAINET_NO_AUTO_UPDATE'] = '1';
      final p = await Process.start(
        res.path,
        ['start', '--daemon'],
        environment: env,
      );
      _log('spawned pid ${p.pid} (piped — stdout/stderr will appear below)');

      p.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => stderr.writeln('[daemon] $line'));
      p.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => stderr.writeln('[daemon] $line'));
      p.exitCode.then((code) {
        _log('daemon process exited with code $code');
      });

      return DaemonStartResult.spawned(p.pid);
    } catch (e, st) {
      _log('spawn failed: $e\n$st');
      return DaemonStartResult.error('Failed to spawn daemon: $e');
    }
  }

  Future<bool> stop() async {
    _log('stop() invoked');
    if (_settings.mode == DaemonMode.external) {
      _log('external mode — refusing to stop (managed by user)');
      return false;
    }
    if (readPid() == null) {
      _log('no pid file — nothing to stop');
      return false;
    }
    // Defer to the CLI: `kwaainet stop` tears down the node AND its detached
    // children (shard serve, storage API), which a raw kill of the node pid
    // would orphan. Keep the GUI out of kwaainet's process internals.
    final res = resolveBinary();
    if (!res.exists) {
      _log('ABORT: binary not found at ${res.path} (${res.source})');
      return false;
    }
    _log('running: ${res.path} stop');
    try {
      final r = await Process.run(res.path, ['stop']);
      if (r.exitCode != 0) {
        _log('kwaainet stop exit ${r.exitCode}: ${r.stderr}');
      }
      return r.exitCode == 0;
    } catch (e, st) {
      _log('kwaainet stop failed: $e\n$st');
      return false;
    }
  }
}

enum DaemonStartKind {
  /// A new daemon process was spawned and its PID written to the state file.
  spawned,

  /// A daemon was already running; we reused its PID without spawning.
  alreadyRunning,

  /// Lifecycle isn't ours — see [DaemonMode.external]. The transition
  /// notifier treats this as success so it doesn't publish a red error bar.
  externalNoop,

  /// Spawn failed. The accompanying [DaemonStartResult.error] explains why.
  error,
}

class DaemonStartResult {
  DaemonStartResult._(this.kind, {this.pid, this.error});
  final DaemonStartKind kind;
  final int? pid;
  final String? error;

  factory DaemonStartResult.spawned(int pid) =>
      DaemonStartResult._(DaemonStartKind.spawned, pid: pid);
  factory DaemonStartResult.alreadyRunning(int pid) =>
      DaemonStartResult._(DaemonStartKind.alreadyRunning, pid: pid);
  factory DaemonStartResult.error(String message) =>
      DaemonStartResult._(DaemonStartKind.error, error: message);
  factory DaemonStartResult.externalNoop() =>
      DaemonStartResult._(DaemonStartKind.externalNoop);

  bool get ok => kind != DaemonStartKind.error;
}
