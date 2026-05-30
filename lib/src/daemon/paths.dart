import 'dart:io';

class KwaainetPaths {
  static String get home {
    final override = Platform.environment['KWAAINET_HOME'];
    if (override != null && override.isNotEmpty) return override;
    final base =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    return '$base${Platform.pathSeparator}.kwaainet';
  }

  static String get runDir => '$home${Platform.pathSeparator}run';
  static String get pidFile => '$runDir${Platform.pathSeparator}kwaainet.pid';
  static String get statusFile =>
      '$runDir${Platform.pathSeparator}kwaainet.status';
  static String get configFile => '$home${Platform.pathSeparator}config.yaml';
  static String get logsDir => '$home${Platform.pathSeparator}logs';
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
String get builtInDebugDaemonPath {
  final sep = Platform.pathSeparator;
  final exeName = Platform.isWindows ? 'kwaainet.exe' : 'kwaainet';

  // Explicit override always wins — point this at any built kwaainet binary.
  final override = Platform.environment['KWAAINET_DEBUG_BIN'];
  if (override != null && override.isNotEmpty) return override;

  // Case 1: bundled next to the GUI executable (production / sandbox install).
  final exeDir = File(Platform.resolvedExecutable).absolute.parent.path;
  for (final neighbour in [
    '$exeDir$sep$exeName', // …/MacOS/kwaainet
    '$exeDir$sep..${sep}Resources$sep$exeName', // …/Resources/kwaainet
  ]) {
    if (File(neighbour).existsSync()) {
      return File(neighbour).absolute.path;
    }
  }

  // Case 2: dev sibling checkout. Find this GUI project's root by walking up
  // to the directory that holds pubspec.yaml (self-limiting — no magic
  // depth), then look for the KwaaiNet repo beside it.
  final sibling = ['..', 'KwaaiNet', 'core', 'target', 'debug', exeName];
  String? projectRoot(String start) {
    for (var dir = Directory(start); ; dir = dir.parent) {
      if (File('${dir.path}${sep}pubspec.yaml').existsSync()) return dir.path;
      if (dir.parent.path == dir.path) return null; // hit filesystem root
    }
  }

  final root = projectRoot(exeDir) ?? projectRoot(Directory.current.path);
  if (root != null) {
    final candidate = [root, ...sibling].join(sep);
    if (File(candidate).existsSync()) return File(candidate).absolute.path;
  }

  // Nothing found — return the sibling-layout guess relative to cwd so the
  // error message points somewhere actionable.
  return [Directory.current.absolute.path, ...sibling].join(sep);
}
