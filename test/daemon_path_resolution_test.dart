@TestOn('mac-os')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kwaainet_gui/src/daemon/paths.dart';

/// Builds a throwaway `.app` laid out exactly like a released bundle:
/// the GUI executable in Contents/MacOS, the daemon in Contents/Resources.
({String exe, String daemon}) fakeBundle(Directory root, String exeName) {
  final macOs = Directory('${root.path}/KwaaiNet.app/Contents/MacOS')
    ..createSync(recursive: true);
  final res = Directory('${root.path}/KwaaiNet.app/Contents/Resources')
    ..createSync(recursive: true);
  final exe = File('${macOs.path}/$exeName')..writeAsStringSync('gui');
  final daemon = File('${res.path}/kwaainet')..writeAsStringSync('daemon');
  return (exe: exe.path, daemon: daemon.path);
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('kwaai-paths'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('resolves the daemon in Resources, not the GUI beside it', () {
    final b = fakeBundle(tmp, 'KwaaiNetGUI');
    expect(
      File(resolveBuiltInDaemonPath(exePath: b.exe)).resolveSymbolicLinksSync(),
      File(b.daemon).resolveSymbolicLinksSync(),
    );
  });

  // The v0.3.0 launch bomb: on case-insensitive APFS "…/MacOS/kwaainet"
  // matches the GUI's own "KwaaiNet", so the GUI launched itself as its node.
  test('never returns the GUI itself when the exe is named KwaaiNet', () {
    final b = fakeBundle(tmp, 'KwaaiNet');
    // Guard the guard: prove this filesystem really is case-insensitive,
    // otherwise the test passes for the wrong reason.
    final collides = File(
      '${File(b.exe).parent.path}/kwaainet',
    ).existsSync();
    expect(collides, isTrue, reason: 'expected a case-insensitive filesystem');

    final resolved = resolveBuiltInDaemonPath(exePath: b.exe);
    expect(FileSystemEntity.identicalSync(resolved, b.exe), isFalse);
    expect(
      File(resolved).resolveSymbolicLinksSync(),
      File(b.daemon).resolveSymbolicLinksSync(),
    );
  });
}
