import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;

/// Directory name of the project-local sandbox. See [resolveProjectSandbox].
const String kSandboxDirName = '.kwaainet-dev';

class KwaainetPaths {
  /// The daemon state directory this app instance owns.
  ///
  /// Cached: it is read on the 2 s status poll and the 3 s RPC probe, and
  /// resolving it walks directories. Nothing it depends on can change while
  /// the process lives.
  static String? _homeCache;

  static String get home => _homeCache ??= resolveKwaainetHome(
    envHome: Platform.environment['KWAAINET_HOME'],
    exePath: Platform.resolvedExecutable,
    userHome: _userHomeBase,
  );

  /// `~/.kwaainet`, ignoring any sandbox. Only for state that belongs to the
  /// *user* rather than to this app instance — see [updatesDir].
  static String get userHome =>
      '$_userHomeBase${Platform.pathSeparator}.kwaainet';

  static String get _userHomeBase =>
      Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      '.';

  /// True when [home] is a project-local sandbox rather than `~/.kwaainet`.
  static bool get isSandboxed => home != userHome;

  static String get runDir => '$home${Platform.pathSeparator}run';
  static String get pidFile => '$runDir${Platform.pathSeparator}kwaainet.pid';
  static String get statusFile =>
      '$runDir${Platform.pathSeparator}kwaainet.status';

  /// The port the running daemon bound, written by it once the gRPC listener
  /// is up and removed on shutdown. Only meaningful while the pid is alive.
  static String get grpcPortFile =>
      '$runDir${Platform.pathSeparator}kwaainet.grpc';

  static String get configFile => '$home${Platform.pathSeparator}config.yaml';
  static String get logsDir => '$home${Platform.pathSeparator}logs';

  /// Downloaded update archives, one dir per version. Must outlive the app
  /// process, so a temp dir won't do.
  ///
  /// Deliberately [userHome], not [home]: this is the *GUI's* self-update
  /// staging area, not daemon state. Under a sandbox it would drop
  /// hundred-megabyte archives into the working tree, and `sweepStaleUpdates`
  /// would stop cleaning the real one.
  static String get updatesDir => '$userHome${Platform.pathSeparator}updates';

  @visibleForTesting
  static void debugResetHomeCache() => _homeCache = null;
}

/// Resolve the daemon state directory: `KWAAINET_HOME`, else a project-local
/// sandbox when this executable is a build artifact of a KwaaiNetGUI checkout,
/// else `~/.kwaainet`.
///
/// The sandbox is what lets a GUI run from source alongside an installed one
/// without the two sharing a daemon, an identity key or a pid file.
String resolveKwaainetHome({
  required String? envHome,
  required String exePath,
  required String userHome,
}) {
  if (envHome != null && envHome.isNotEmpty) return envHome;
  return resolveProjectSandbox(exePath) ??
      '$userHome${Platform.pathSeparator}.kwaainet';
}

/// The project-local sandbox for [exePath], or null if it isn't a dev build.
///
/// Three gates, each load-bearing:
///   1. **[exePath] only, never `Directory.current`** — an installed release
///      launched from a terminal inside some unrelated Flutter checkout would
///      otherwise relocate its identity and config into that checkout.
///   2. **The exe must live under `<root>/build/`** — "has an ancestor with a
///      pubspec.yaml" also matches an app someone copied into a checkout.
///      This is also why the gate isn't `kDebugMode`: `build-local.sh`
///      produces a *Release* bundle under `build/` and runs it in place,
///      which is a dev artifact and should be sandboxed.
///   3. **That pubspec must be ours** — defence in depth.
String? resolveProjectSandbox(String exePath) {
  final sep = Platform.pathSeparator;
  final exe = File(exePath).absolute.path;
  final root = pubspecRoot(File(exe).parent.path);
  if (root == null) return null;
  if (!exe.startsWith('$root${sep}build$sep')) return null;

  final pubspec = File('$root${sep}pubspec.yaml');
  try {
    if (!RegExp(
      r'^name:\s*kwaainet_gui\s*$',
      multiLine: true,
    ).hasMatch(pubspec.readAsStringSync())) {
      return null;
    }
  } on FileSystemException {
    return null;
  }
  return '$root$sep$kSandboxDirName';
}

/// Locates the bundled `kwaainet` daemon for "built-in" mode.
///
/// The built-in binary can live in one of two places:
///   1. A production/sandbox install — shipped *inside* the app bundle,
///      alongside the GUI executable (a fixed offset, no searching).
///   2. A dev checkout — built at `core/target/debug/kwaainet` in the
///      KwaaiNet repo, which is now a *sibling* of this GUI project.
///
/// `KWAAINET_DEBUG_BIN` overrides both.
String get builtInDebugDaemonPath => resolveBuiltInDaemonPath();

/// Walk up from [start] to the first directory holding a `pubspec.yaml`.
/// Self-limiting — no magic depth. Null once the filesystem root is reached.
String? pubspecRoot(String start) {
  final sep = Platform.pathSeparator;
  for (var dir = Directory(start); ; dir = dir.parent) {
    if (File('${dir.path}${sep}pubspec.yaml').existsSync()) return dir.path;
    if (dir.parent.path == dir.path) return null;
  }
}

/// The body of [builtInDebugDaemonPath]. [exePath] is an injection point for
/// tests, which need to stand up a fake bundle the running exe isn't in.
String resolveBuiltInDaemonPath({String? exePath}) {
  final sep = Platform.pathSeparator;
  final exeName = Platform.isWindows ? 'kwaainet.exe' : 'kwaainet';

  // Explicit override always wins — point this at any built kwaainet binary.
  final override = Platform.environment['KWAAINET_DEBUG_BIN'];
  if (override != null && override.isNotEmpty) return override;

  // Case 1: bundled next to the GUI executable (production / sandbox install).
  final selfExe = exePath ?? Platform.resolvedExecutable;
  final exeDir = File(selfExe).absolute.parent.path;
  for (final neighbour in [
    '$exeDir$sep..${sep}Resources$sep$exeName', // …/Resources/kwaainet
    '$exeDir$sep$exeName', // …/MacOS/kwaainet (Windows/Linux: beside the exe)
  ]) {
    if (!File(neighbour).existsSync()) continue;
    // Case-insensitive filesystems match "kwaainet" against the GUI's own
    // executable. Starting that would fork-bomb the app, so never return it.
    if (FileSystemEntity.identicalSync(neighbour, selfExe)) continue;
    return File(neighbour).absolute.path;
  }

  // Case 2: dev sibling checkout. Find this GUI project's root by walking up
  // to the directory that holds pubspec.yaml (self-limiting — no magic
  // depth), then look for the KwaaiNet repo beside it.
  final sibling = ['..', 'KwaaiNet', 'core', 'target', 'debug', exeName];
  final root = pubspecRoot(exeDir) ?? pubspecRoot(Directory.current.path);
  if (root != null) {
    final candidate = [root, ...sibling].join(sep);
    if (File(candidate).existsSync()) return File(candidate).absolute.path;
  }

  // Nothing found — return the sibling-layout guess relative to cwd so the
  // error message points somewhere actionable.
  return [Directory.current.absolute.path, ...sibling].join(sep);
}

/// True when the resolved built-in daemon sits *inside* the app bundle (next
/// to the GUI executable) — i.e. a normal installed/release app, where the
/// path is an implementation detail not worth showing the user.
bool get _builtInDaemonIsBundled {
  final sep = Platform.pathSeparator;
  final exeDir = File(Platform.resolvedExecutable).absolute.parent.path;
  final resolved = builtInDebugDaemonPath;
  return resolved ==
          '$exeDir$sep${Platform.isWindows ? 'kwaainet.exe' : 'kwaainet'}' ||
      resolved.startsWith('$exeDir$sep..${sep}Resources$sep');
}

/// User-facing label for the "Use built-in" daemon option.
///
/// Release/installed builds bundle the daemon inside the app, so the path is
/// noise — just say "Use built-in". Only in a debug build where the daemon is
/// run from a *different* directory than the GUI (the dev sibling checkout) do
/// we surface the actual relative path being used, e.g.
/// `../KwaaiNet/core/target/debug/kwaainet`.
String get builtInDaemonLabel {
  if (!kDebugMode || _builtInDaemonIsBundled) return 'Use built-in';
  final rel = _relativeToCwd(builtInDebugDaemonPath);
  return 'Use built-in (dev: $rel)';
}

/// Render [target] relative to the current working directory, so a dev sees
/// `../KwaaiNet/core/target/debug/kwaainet` rather than an absolute path.
/// Falls back to the absolute path if the two share no common root.
String _relativeToCwd(String target) {
  final sep = Platform.pathSeparator;
  final from = Directory.current.absolute.path.split(sep)
    ..removeWhere((s) => s.isEmpty);
  final to = File(target).absolute.path.split(sep)
    ..removeWhere((s) => s.isEmpty);

  var common = 0;
  while (common < from.length &&
      common < to.length &&
      from[common] == to[common]) {
    common++;
  }
  if (common == 0) return File(target).absolute.path; // no shared root
  final ups = List.filled(from.length - common, '..');
  final down = to.sublist(common);
  return [...ups, ...down].join(sep);
}
