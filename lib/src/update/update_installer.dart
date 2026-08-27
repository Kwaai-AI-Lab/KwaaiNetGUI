import 'dart:io';

/// Which packaged layout an install root is, which decides how the archive is
/// extracted, what the payload inside it is called, and how to relaunch.
enum InstallKind { macOsApp, windowsDir, linuxDir }

/// A resolved, swappable install location — the thing the helper renames.
class InstallRoot {
  const InstallRoot({required this.path, required this.kind});

  /// macOS: the `.app` bundle. Windows/Linux: the directory holding the exe.
  final String path;
  final InstallKind kind;

  /// The directory the swap renames *within*, and where staging happens.
  String get parentPath => _dirname(path);
}

/// Anything that stops an update being installed. Surfaced in the banner.
class UpdateInstallException implements Exception {
  UpdateInstallException(this.message);
  final String message;
  @override
  String toString() => message;
}

String _sep(InstallKind kind) => kind == InstallKind.windowsDir ? '\\' : '/';

String _dirname(String path) {
  final i = path.lastIndexOf(RegExp(r'[/\\]'));
  if (i <= 0) return i == 0 ? path.substring(0, 1) : '.';
  return path.substring(0, i);
}

String _basename(String path) {
  final i = path.lastIndexOf(RegExp(r'[/\\]'));
  return i < 0 ? path : path.substring(i + 1);
}

/// The current platform's [InstallKind], or null where we ship no build.
InstallKind? currentInstallKind() {
  if (Platform.isMacOS) return InstallKind.macOsApp;
  if (Platform.isWindows) return InstallKind.windowsDir;
  if (Platform.isLinux) return InstallKind.linuxDir;
  return null;
}

/// Resolves the packaged install root, or null when the layout doesn't match
/// one we know how to swap (a dev tree, an odd install) — the caller then
/// degrades to opening the release page.
///
/// [exePath], [kind] and [exists] are injection points for tests.
InstallRoot? resolveInstallRoot({
  String? exePath,
  InstallKind? kind,
  bool Function(String path)? exists,
}) {
  final k = kind ?? currentInstallKind();
  if (k == null) return null;
  final exe = exePath ?? Platform.resolvedExecutable;
  final sep = _sep(k);
  final dirExists = exists ?? (p) => Directory(p).existsSync();

  if (k == InstallKind.macOsApp) {
    // …/KwaaiNet.app/Contents/MacOS/KwaaiNet — three parents up. Keyed off the
    // bundle shape alone: a locally-built .app has no daemon in Resources.
    final macOsDir = _dirname(exe);
    final contents = _dirname(macOsDir);
    final root = _dirname(contents);
    if (_basename(macOsDir) != 'MacOS') return null;
    if (_basename(contents) != 'Contents') return null;
    if (!root.endsWith('.app')) return null;
    return InstallRoot(path: root, kind: k);
  }

  // Windows/Linux: the exe's own directory, proven by the Flutter payload
  // that always sits beside it in a packaged build.
  final root = _dirname(exe);
  if (!dirExists('$root${sep}data${sep}flutter_assets')) return null;
  return InstallRoot(path: root, kind: k);
}

/// True when we can rename [root] in place. Probes the *parent*, since that's
/// the directory the swap actually writes to.
Future<bool> isWritable(InstallRoot root) async {
  final probe = File(
    '${root.parentPath}${_sep(root.kind)}.kwaainet-write-probe-$pid',
  );
  try {
    await probe.writeAsString('');
    await probe.delete();
    return true;
  } catch (_) {
    return false;
  }
}

/// Where [extract] stages a version, beside the install root so the final
/// move is a same-filesystem rename.
String stagePathFor(InstallRoot root, String version) =>
    '${root.parentPath}${_sep(root.kind)}.kwaainet-update-$version';

/// The payload inside a stage dir — what actually replaces the install root.
String stagedPayloadPath(InstallRoot root, String stagePath) {
  final sep = _sep(root.kind);
  return switch (root.kind) {
    InstallKind.macOsApp => '$stagePath$sep${_basename(root.path)}',
    InstallKind.linuxDir => '$stagePath${sep}bundle',
    // The Windows zip is flat, so we give it a wrapper to match the others.
    InstallKind.windowsDir => '$stagePath${sep}app',
  };
}

/// Unpacks [archive] into a fresh stage dir beside [root] and returns the
/// payload directory. Never `package:archive` — it drops the symlinks and
/// exec bits inside a macOS .app, which is why CI packages with `ditto`.
Future<Directory> extract(File archive, InstallRoot root, String version) async {
  final stage = Directory(stagePathFor(root, version));
  if (await stage.exists()) await stage.delete(recursive: true);
  await stage.create(recursive: true);

  final staged = stagedPayloadPath(root, stage.path);
  switch (root.kind) {
    case InstallKind.macOsApp:
      await _run('ditto', ['-x', '-k', archive.path, stage.path]);
      // Strip quarantine then re-seal the ad-hoc signature, mirroring the Rust
      // node updater — otherwise macOS calls the moved bundle "damaged".
      await _run('xattr', ['-dr', 'com.apple.quarantine', staged], check: false);
      await _run('codesign', ['--force', '--deep', '--sign', '-', staged]);
      await _run('codesign', ['--verify', '--deep', staged]);
    case InstallKind.linuxDir:
      await _run('tar', ['-xzf', archive.path, '-C', stage.path]);
    case InstallKind.windowsDir:
      await _run('powershell', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        'Expand-Archive -Path "${archive.path}" -DestinationPath "$staged" -Force',
      ]);
  }

  final dir = Directory(staged);
  if (!await dir.exists()) {
    throw UpdateInstallException('The update archive had an unexpected layout.');
  }
  return dir;
}

Future<void> _run(String exe, List<String> args, {bool check = true}) async {
  final r = await Process.run(exe, args);
  if (check && r.exitCode != 0) {
    throw UpdateInstallException(
      '$exe failed (${r.exitCode}): ${r.stderr.toString().trim()}',
    );
  }
}

/// The relaunch command the helper runs once the new build is in place.
String relaunchCommand(InstallRoot root) => switch (root.kind) {
  InstallKind.macOsApp => 'open -n "${root.path}"',
  InstallKind.linuxDir => '"${root.path}/kwaainet_gui"',
  InstallKind.windowsDir => '${root.path}\\kwaainet_gui.exe',
};

/// The detached swap helper's text. Pure — no I/O, no `Platform` reads — so
/// it can be golden-tested for every platform from any host.
///
/// The app cannot replace its own running bundle, so this waits for our pid to
/// exit, renames the live install aside to `.old`, moves the staged build in,
/// and rolls back from `.old` if that fails. `.old` survives a failure for
/// manual recovery, the same discipline as kwaai-cli's updater.rs.
String swapScript({
  required int pid,
  required String target,
  required String staged,
  required String stage,
  required String relaunch,
  required InstallKind kind,
}) {
  if (kind == InstallKind.windowsDir) {
    return '''
\$ErrorActionPreference = 'Stop'
Wait-Process -Id $pid -Timeout 120 -ErrorAction SilentlyContinue
\$target = '$target'
\$staged = '$staged'
\$stage  = '$stage'
\$old    = "\$target.old"
if (Test-Path \$old) { Remove-Item -LiteralPath \$old -Recurse -Force }
Move-Item -LiteralPath \$target -Destination \$old -Force
try {
  Move-Item -LiteralPath \$staged -Destination \$target -Force
} catch {
  if (Test-Path \$target) { Remove-Item -LiteralPath \$target -Recurse -Force }
  Move-Item -LiteralPath \$old -Destination \$target -Force
  exit 1
}
Remove-Item -LiteralPath \$old -Recurse -Force
if (Test-Path \$stage) { Remove-Item -LiteralPath \$stage -Recurse -Force }
Start-Process '$relaunch'
''';
  }

  final launch = kind == InstallKind.linuxDir
      ? 'nohup $relaunch >/dev/null 2>&1 &'
      : relaunch;
  return '''
#!/bin/sh
# Bounded wait (~120 s) for the app to exit; a wedged process must not leave
# this helper spinning forever.
i=0
while kill -0 $pid 2>/dev/null; do
  i=\$((i+1))
  [ "\$i" -ge 240 ] && exit 1
  sleep 0.5
done

TARGET='$target'
STAGED='$staged'
STAGE='$stage'

rm -rf "\$TARGET.old"
mv "\$TARGET" "\$TARGET.old" || exit 1
mv "\$STAGED" "\$TARGET" || { rm -rf "\$TARGET"; mv "\$TARGET.old" "\$TARGET"; exit 1; }
rm -rf "\$TARGET.old"
rm -rf "\$STAGE"
$launch
''';
}
