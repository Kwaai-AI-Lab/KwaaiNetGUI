import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kwaainet_gui/src/daemon/paths.dart';

/// Lays out a KwaaiNetGUI checkout with a built `.app` where `flutter run`
/// puts one: `<root>/build/macos/Build/Products/<flavour>/KwaaiNet.app`.
String devBuildExe(
  Directory root, {
  String flavour = 'Debug',
  String pubspecName = 'kwaainet_gui',
}) {
  File('${root.path}/pubspec.yaml').writeAsStringSync(
    'name: $pubspecName\nversion: 1.0.0\n',
  );
  final macOs = Directory(
    '${root.path}/build/macos/Build/Products/$flavour/KwaaiNet.app/Contents/MacOS',
  )..createSync(recursive: true);
  final exe = File('${macOs.path}/KwaaiNet')..writeAsStringSync('gui');
  return exe.path;
}

/// An installed app: no pubspec.yaml anywhere above it.
String installedExe(Directory root) {
  final macOs = Directory('${root.path}/Applications/KwaaiNet.app/Contents/MacOS')
    ..createSync(recursive: true);
  final exe = File('${macOs.path}/KwaaiNet')..writeAsStringSync('gui');
  return exe.path;
}

void main() {
  late Directory tmp;
  final sep = Platform.pathSeparator;
  setUp(() => tmp = Directory.systemTemp.createTempSync('kwaai-sandbox'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('resolveProjectSandbox', () {
    test('a dev build under <root>/build/ gets a project-local sandbox', () {
      final root = Directory('${tmp.path}/proj')..createSync();
      expect(
        resolveProjectSandbox(devBuildExe(root)),
        '${root.path}$sep$kSandboxDirName',
      );
    });

    // build-local.sh produces a Release bundle under build/ and runs it in
    // place. That is a dev artifact and must not collide with a debug GUI.
    test('a local Release build under build/ is still a sandbox', () {
      final root = Directory('${tmp.path}/proj')..createSync();
      expect(
        resolveProjectSandbox(devBuildExe(root, flavour: 'Release')),
        '${root.path}$sep$kSandboxDirName',
      );
    });

    test('an installed app gets no sandbox', () {
      expect(resolveProjectSandbox(installedExe(tmp)), isNull);
    });

    // The regression that would relocate a released daemon's identity key.
    test('an installed app inside a checkout still gets no sandbox', () {
      final root = Directory('${tmp.path}/proj')..createSync();
      File('${root.path}/pubspec.yaml').writeAsStringSync('name: kwaainet_gui\n');
      final macOs = Directory('${root.path}/KwaaiNet.app/Contents/MacOS')
        ..createSync(recursive: true);
      final exe = File('${macOs.path}/KwaaiNet')..writeAsStringSync('gui');
      // Has a pubspec ancestor, but is not a build artifact of it.
      expect(resolveProjectSandbox(exe.path), isNull);
    });

    test('a build artifact of some other Flutter project gets no sandbox', () {
      final root = Directory('${tmp.path}/proj')..createSync();
      expect(
        resolveProjectSandbox(devBuildExe(root, pubspecName: 'someone_else')),
        isNull,
      );
    });
  });

  group('resolveKwaainetHome', () {
    test('KWAAINET_HOME wins over a project sandbox', () {
      final root = Directory('${tmp.path}/proj')..createSync();
      expect(
        resolveKwaainetHome(
          envHome: '/explicit/home',
          exePath: devBuildExe(root),
          userHome: '/Users/nobody',
        ),
        '/explicit/home',
      );
    });

    test('an empty KWAAINET_HOME is ignored, not honoured', () {
      expect(
        resolveKwaainetHome(
          envHome: '',
          exePath: installedExe(tmp),
          userHome: '/Users/nobody',
        ),
        '/Users/nobody$sep.kwaainet',
      );
    });

    test('an installed app falls back to ~/.kwaainet', () {
      expect(
        resolveKwaainetHome(
          envHome: null,
          exePath: installedExe(tmp),
          userHome: '/Users/nobody',
        ),
        '/Users/nobody$sep.kwaainet',
      );
    });

    test('a dev build resolves to the sandbox', () {
      final root = Directory('${tmp.path}/proj')..createSync();
      expect(
        resolveKwaainetHome(
          envHome: null,
          exePath: devBuildExe(root),
          userHome: '/Users/nobody',
        ),
        '${root.path}$sep$kSandboxDirName',
      );
    });
  });
}
