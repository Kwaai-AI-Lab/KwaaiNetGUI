import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/settings.dart';
import 'package:kwaainet_gui/src/window/shutdown.dart';
import 'package:kwaainet_gui/src/update/release_checker.dart';
import 'package:kwaainet_gui/src/update/update_controller.dart';
import 'package:kwaainet_gui/src/update/update_downloader.dart';
import 'package:kwaainet_gui/src/update/update_installer.dart';

const _root = InstallRoot(
  path: '/Applications/KwaaiNet.app',
  kind: InstallKind.macOsApp,
);

/// One asset per platform: `start` resolves the asset through
/// [ReleaseChecker.currentPlatformKey], so a macOS-only release fails with
/// "no download for this platform" on the Linux CI runner.
ReleaseInfo _release(String version) => ReleaseInfo(
  version: version,
  htmlUrl: 'https://example.test/r',
  assets: [
    for (final name in const [
      'kwaainet-gui-macos.zip',
      'kwaainet-gui-windows.zip',
      'kwaainet-gui-linux.tar.gz',
    ])
      ReleaseAsset(
        name: name,
        url: 'https://example.test/a.zip',
        sizeBytes: 10,
        sha256: 'a' * 64,
      ),
  ],
);

/// A downloader whose stream we drive by hand, so a run can be held open
/// exactly where a test needs it.
class _FakeDownloader implements UpdateDownloader {
  final controller = StreamController<DownloadProgress>();
  int calls = 0;

  @override
  Stream<DownloadProgress> download(ReleaseAsset asset, {required File dest}) {
    calls++;
    return controller.stream;
  }

  @override
  void dispose() {}
}

class _FakeOps implements UpdateInstallOps {
  _FakeOps({this.writableResult = true, this.stagedExists = true});

  bool writableResult;
  bool stagedExists;
  int quitCalls = 0;
  int launchCalls = 0;
  int unpackCalls = 0;

  /// When set, unpack waits on this — lets a test sit inside "verifying".
  Completer<void>? unpackGate;

  @override
  InstallRoot? resolveRoot() => _root;

  @override
  Future<bool> writable(InstallRoot root) async => writableResult;

  @override
  Future<bool> exists(String path) async => stagedExists;

  @override
  Future<Directory> unpack(File a, InstallRoot r, String version) async {
    unpackCalls++;
    if (unpackGate != null) await unpackGate!.future;
    return Directory(stagedPayloadPath(r, stagePathFor(r, version)));
  }

  String? launchedScript;

  @override
  Future<void> launchHelper({
    required String path,
    required String script,
    required bool windows,
  }) async {
    launchCalls++;
    launchedScript = script;
  }

  @override
  Future<void> quit(ProviderContainer container) async {
    quitCalls++;
  }
}

ProviderContainer _containerWith(_FakeDownloader dl, _FakeOps ops) {
  late final ProviderContainer c;
  c = ProviderContainer(
    overrides: [
      appContainerProvider.overrideWith((_) => c),
      updatesEnabledProvider.overrideWithValue(true),
      updateDownloaderProvider.overrideWithValue(dl),
      updateInstallOpsProvider.overrideWithValue(ops),
      autoDownloadUpdatesProvider.overrideWith((_) => false),
      updateBannerProvider.overrideWithValue(null),
      updateTrayProvider.overrideWithValue(null),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

/// Runs one download to completion and leaves the notifier in UpdateReady.
Future<UpdateInstallNotifier> _staged(
  ProviderContainer c,
  _FakeDownloader dl,
) async {
  final n = c.read(updateStageProvider.notifier);
  final run = n.start(_release('0.3.0'));
  await Future<void>.delayed(Duration.zero);
  await dl.controller.close();
  await run;
  return n;
}

void main() {
  // installSupported reads a FutureProvider; these tests always resolve it.
  Future<void> settle(ProviderContainer c) async {
    await c.read(updateInstallSupportedProvider.future);
  }

  group('installAndRestart is single-flight', () {
    test('a second click cannot launch a second helper', () async {
      final dl = _FakeDownloader();
      final ops = _FakeOps();
      final c = _containerWith(dl, ops);
      await settle(c);
      final n = await _staged(c, dl);
      expect(c.read(updateStageProvider), isA<UpdateReady>());

      // Two clicks with no await between them — banner plus tray, or a
      // double-click before the shutdown overlay engages.
      final a = n.installAndRestart();
      final b = n.installAndRestart();
      await Future.wait([a, b]);

      expect(ops.launchCalls, 1);
      expect(ops.quitCalls, 1);
    });

    test('a missing staged build fails instead of quitting', () async {
      final dl = _FakeDownloader();
      final ops = _FakeOps(stagedExists: false);
      final c = _containerWith(dl, ops);
      await settle(c);
      final n = await _staged(c, dl);

      await n.installAndRestart();

      expect(ops.launchCalls, 0);
      expect(ops.quitCalls, 0);
      expect(c.read(updateStageProvider), isA<UpdateFailed>());
    });

    test('an install root gone read-only fails instead of quitting', () async {
      final dl = _FakeDownloader();
      final ops = _FakeOps();
      final c = _containerWith(dl, ops);
      await settle(c);
      final n = await _staged(c, dl);

      // Writable at download time, not at restart time.
      ops.writableResult = false;
      await n.installAndRestart();

      expect(ops.quitCalls, 0);
      expect(c.read(updateStageProvider), isA<UpdateFailed>());
    });
  });

  group('cancel', () {
    test('completes the run rather than leaking the frame', () async {
      final dl = _FakeDownloader();
      final ops = _FakeOps();
      final c = _containerWith(dl, ops);
      await settle(c);
      final n = c.read(updateStageProvider.notifier);

      final run = n.start(_release('0.3.0'));
      await Future<void>.delayed(Duration.zero);
      expect(c.read(updateStageProvider), isA<UpdateDownloading>());

      await n.cancel();
      // Without cancel() completing the completer this never returns.
      await run.timeout(const Duration(seconds: 2));
      expect(c.read(updateStageProvider), isA<UpdateIdle>());
      expect(ops.unpackCalls, 0);
    });

    test('cancel during verifying does not later overwrite Idle', () async {
      final dl = _FakeDownloader();
      final gate = Completer<void>();
      final ops = _FakeOps()..unpackGate = gate;
      final c = _containerWith(dl, ops);
      await settle(c);
      final n = c.read(updateStageProvider.notifier);

      final run = n.start(_release('0.3.0'));
      await Future<void>.delayed(Duration.zero);
      await dl.controller.close();
      await Future<void>.delayed(Duration.zero);
      expect(c.read(updateStageProvider), isA<UpdateVerifying>());

      await n.cancel();
      expect(c.read(updateStageProvider), isA<UpdateIdle>());

      // The unpack finishes afterwards; its result must be discarded.
      gate.complete();
      await run;
      expect(c.read(updateStageProvider), isA<UpdateIdle>());
    });
  });

  group('start', () {
    test('two concurrent calls produce one download', () async {
      final dl = _FakeDownloader();
      final ops = _FakeOps();
      final c = _containerWith(dl, ops);
      await settle(c);
      final n = c.read(updateStageProvider.notifier);

      final a = n.start(_release('0.3.0'));
      final b = n.start(_release('0.3.0'));
      await Future<void>.delayed(Duration.zero);
      await dl.controller.close();
      await Future.wait([a, b]);

      expect(dl.calls, 1);
    });

    test('a non-writable root fails without downloading', () async {
      final dl = _FakeDownloader();
      final ops = _FakeOps(writableResult: false);
      final c = _containerWith(dl, ops);
      await settle(c);
      final n = c.read(updateStageProvider.notifier);

      await n.start(_release('0.3.0'));

      expect(dl.calls, 0);
      expect(c.read(updateStageProvider), isA<UpdateFailed>());
    });

    test('an invalid version is refused before touching the disk', () async {
      final dl = _FakeDownloader();
      final ops = _FakeOps();
      final c = _containerWith(dl, ops);
      await settle(c);
      final n = c.read(updateStageProvider.notifier);

      await n.start(_release(r"9.9.9'; rm -rf $HOME; '"));

      expect(dl.calls, 0);
      expect(c.read(updateStageProvider), isA<UpdateFailed>());
    });

    test('UpdateReady carries the version that was actually staged', () async {
      final dl = _FakeDownloader();
      final ops = _FakeOps();
      final c = _containerWith(dl, ops);
      await settle(c);
      await _staged(c, dl);

      final ready = c.read(updateStageProvider) as UpdateReady;
      expect(ready.version, '0.3.0');
      expect(
        ready.stagedPath,
        '/Applications/.kwaainet-update-0.3.0/KwaaiNet.app',
      );
    });
  });

  group('updateInstallSupportedProvider', () {
    test('false when the root is not writable', () async {
      final c = _containerWith(_FakeDownloader(), _FakeOps(writableResult: false));
      expect(await c.read(updateInstallSupportedProvider.future), isFalse);
    });

    test('true when resolvable and writable', () async {
      final c = _containerWith(_FakeDownloader(), _FakeOps());
      expect(await c.read(updateInstallSupportedProvider.future), isTrue);
    });
  });
}
