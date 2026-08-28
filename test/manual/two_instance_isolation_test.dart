@Tags(['manual'])
library;

// Acceptance gate for per-instance daemon isolation. Excluded from the default
// suite (see dart_test.yaml) because it starts two real daemons.
//
//   KWAAINET_BIN=/path/to/kwaainet \
//     flutter test test/manual/two_instance_isolation_test.dart --tags manual
//
// Stands up an "installed" daemon on one state directory and a "sandboxed" one
// on another, exactly as two GUIs would, and asserts the three things that
// used to be false: that they are two processes, that they hold two distinct
// gRPC endpoints, and — the one that bit hardest — that stopping either leaves
// the other alive, p2pd child included.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kwaainet_gui/src/daemon/daemon_env.dart';
import 'package:kwaainet_gui/src/daemon/port_allocator.dart';

String get _binary =>
    Platform.environment['KWAAINET_BIN'] ??
    '../KwaaiNet/core/target/release/kwaainet';

/// Bring up a daemon on its own state directory, the way DaemonController does.
Future<({int grpcPort, String home})> startDaemon(Directory home) async {
  final grpcPort = await allocateFreePort();
  final p2pPort = await allocateFreePort(address: InternetAddress.anyIPv4);
  final env = daemonChildEnvironment(
    base: Platform.environment,
    home: home.path,
    p2pdSocket: p2pdSocketFor(home.path, sandboxed: true),
    grpcPort: grpcPort,
    p2pPort: p2pPort,
  );
  final r = await Process.run(_binary, ['start', '--daemon'], environment: env);
  expect(r.exitCode, 0, reason: 'start failed: ${r.stderr}');
  return (grpcPort: grpcPort, home: home.path);
}

Future<void> stopDaemon(String home) async {
  await Process.run(
    _binary,
    ['stop'],
    environment: daemonChildEnvironment(
      base: Platform.environment,
      home: home,
      p2pdSocket: p2pdSocketFor(home, sandboxed: true),
    ),
  );
}

int? readPid(String home) {
  final f = File('$home/run/kwaainet.pid');
  return f.existsSync() ? int.tryParse(f.readAsStringSync().trim()) : null;
}

Future<bool> alive(int pid) async =>
    (await Process.run('kill', ['-0', '$pid'])).exitCode == 0;

Future<bool> waitFor(Future<bool> Function() probe, {int seconds = 30}) async {
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(deadline)) {
    if (await probe()) return true;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  return false;
}

void main() {
  late Directory installed;
  late Directory sandbox;

  setUp(() {
    installed = Directory.systemTemp.createTempSync('kwaai-installed');
    sandbox = Directory.systemTemp.createTempSync('kwaai-sandbox');
  });

  tearDown(() async {
    await stopDaemon(installed.path);
    await stopDaemon(sandbox.path);
    installed.deleteSync(recursive: true);
    sandbox.deleteSync(recursive: true);
  });

  test('two instances coexist and neither stop takes out the other', () async {
    final a = await startDaemon(installed);
    final b = await startDaemon(sandbox);

    expect(
      await waitFor(() async =>
          readPid(a.home) != null && readPid(b.home) != null),
      isTrue,
      reason: 'both daemons must write their own pid file',
    );
    final pidA = readPid(a.home)!;
    final pidB = readPid(b.home)!;
    expect(pidA, isNot(pidB), reason: 'one daemon was shared, not two started');

    // Each reports its own port, and they are not the same port.
    expect(
      await waitFor(() async =>
          File('${a.home}/run/kwaainet.grpc').existsSync() &&
          File('${b.home}/run/kwaainet.grpc').existsSync()),
      isTrue,
      reason: 'each daemon must record the gRPC port it bound',
    );
    expect(a.grpcPort, isNot(b.grpcPort));
    expect(
      File('${a.home}/run/kwaainet.grpc').readAsStringSync().trim(),
      '${a.grpcPort}',
    );

    // Two sockets, not one — before the kwaainet_dir() fix the second bind
    // unlinked the first daemon's live socket.
    expect(File('${a.home}/run/kwaai.sock').existsSync(), isTrue);
    expect(File('${b.home}/run/kwaai.sock').existsSync(), isTrue);

    // The headline: stopping the sandbox must leave the other one running.
    await stopDaemon(b.home);
    expect(await waitFor(() async => !await alive(pidB)), isTrue);
    expect(
      await alive(pidA),
      isTrue,
      reason: "stopping one instance killed the other's daemon",
    );

    // ...and its p2pd child, which kill_orphaned_p2pd() used to SIGKILL
    // machine-wide regardless of which instance was stopping.
    final p2pd = await Process.run('pgrep', ['-f', 'p2pd']);
    expect(
      p2pd.stdout.toString().trim(),
      isNotEmpty,
      reason: "the surviving daemon's p2pd was killed too",
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
