import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kwaainet_gui/src/daemon/daemon_controller.dart';
import 'package:kwaainet_gui/src/daemon/daemon_state.dart';
import 'package:kwaainet_gui/src/daemon/paths.dart';
import 'package:kwaainet_gui/src/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records stops instead of running `kwaainet stop`.
class _FakeController extends Fake implements DaemonController {
  _FakeController({required this.startedNode});

  @override
  final bool startedNode;

  int stops = 0;

  @override
  Future<bool> stop() async {
    stops++;
    return true;
  }
}

void main() {
  ProviderContainer container(_FakeController daemon) {
    final c = ProviderContainer(
      overrides: [
        daemonControllerProvider.overrideWithValue(daemon),
        daemonStatusProvider.overrideWith((ref) => const Stream.empty()),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  // Regression (KwaaiNetGUI#17 item 2): quitting the GUI ran `kwaainet stop`
  // on a node started from the CLI, which the GUI had only attached to.
  test('quit leaves a node the app attached to running', () async {
    final daemon = _FakeController(startedNode: false);
    await container(daemon)
        .read(daemonTransitionProvider.notifier)
        .stopOnQuit();
    expect(daemon.stops, 0);
  });

  test('quit stops a node the app spawned', () async {
    final daemon = _FakeController(startedNode: true);
    await container(daemon)
        .read(daemonTransitionProvider.notifier)
        .stopOnQuit();
    expect(daemon.stops, 1);
  });

  test('Stop service stops the node either way', () async {
    final daemon = _FakeController(startedNode: false);
    await container(daemon).read(daemonTransitionProvider.notifier).stop();
    expect(daemon.stops, 1);
  });

  group('DaemonController.startedNode', () {
    late DaemonController daemon;
    late File pidFile;

    setUp(() async {
      final home = Directory.systemTemp.createTempSync('kstarted');
      KwaainetPaths.debugOverrideHome(home.path);
      addTearDown(() {
        KwaainetPaths.debugResetHomeCache();
        home.deleteSync(recursive: true);
      });
      pidFile = File(KwaainetPaths.pidFile)..createSync(recursive: true);
      SharedPreferences.setMockInitialValues({});
      daemon = DaemonController(await Settings.load());
    });

    test('false for a node it never spawned', () {
      pidFile.writeAsStringSync('100');
      expect(daemon.startedNode, isFalse);
    });

    test('true from spawn until the node is up, then by pid', () {
      daemon.debugMarkSpawned();
      expect(daemon.startedNode, isTrue);
      pidFile.writeAsStringSync('100');
      daemon.claimSpawnedNode();
      expect(daemon.startedNode, isTrue);
    });

    // Regression (metro-win): the claim ran before the new node wrote its
    // pid, and the node the GUI had spawned became nobody's.
    test('a claim before the pid file exists keeps the node ours', () {
      pidFile.deleteSync();
      daemon.debugMarkSpawned();
      daemon.claimSpawnedNode();
      expect(daemon.startedNode, isTrue);
      pidFile.writeAsStringSync('100');
      daemon.claimSpawnedNode();
      pidFile.writeAsStringSync('200');
      expect(daemon.startedNode, isFalse);
    });

    // A spawn that never bound is given up; a node running later (say, one
    // the user then starts from the CLI) must not be taken for it.
    test('disownSpawn forgets a spawn that never came up', () {
      daemon.debugMarkSpawned();
      daemon.disownSpawn();
      pidFile.writeAsStringSync('100');
      daemon.claimSpawnedNode();
      expect(daemon.startedNode, isFalse);
    });

    test('attaching to a running node disowns a pending spawn', () async {
      daemon.debugMarkSpawned();
      pidFile.writeAsStringSync('$pid'); // this test process: alive
      final r = await daemon.start();
      expect(r.kind, DaemonStartKind.alreadyRunning);
      expect(daemon.startedNode, isFalse);
    });

    // Our node stopped from the CLI and another started: that one is the
    // user's, so Quit must leave it alone.
    test('false once the pid file names another node', () {
      daemon.debugMarkSpawned();
      pidFile.writeAsStringSync('100');
      daemon.claimSpawnedNode();
      pidFile.writeAsStringSync('200');
      expect(daemon.startedNode, isFalse);
      pidFile.deleteSync();
      expect(daemon.startedNode, isFalse);
    });

    // Regression (metro-win): `kwaainet stop` on Windows uses taskkill, so
    // the dead node's port file stayed and the bind wait passed at once.
    test('the bind wait needs the port it handed out', () {
      final portFile = File(KwaainetPaths.grpcPortFile);
      expect(grpcPortFileNames(5000), isFalse);
      portFile.writeAsStringSync('4000\n'); // a dead node's
      expect(grpcPortFileNames(5000), isFalse);
      portFile.writeAsStringSync('5000\n');
      expect(grpcPortFileNames(5000), isTrue);
    });
  });
}
