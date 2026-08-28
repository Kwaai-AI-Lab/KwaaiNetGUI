import 'package:flutter_test/flutter_test.dart';
import 'package:kwaainet_gui/src/chat/kwaai_rpc_client.dart';
import 'package:kwaainet_gui/src/daemon/status_watcher.dart';

/// `run/kwaainet.grpc` is how the GUI finds a live daemon it did not spawn
/// (its own restart, an out-of-band `kwaainet restart`). The daemon writes it
/// only after a successful bind, so a *parseable* value means "listening" —
/// which is exactly why an unparseable one must not be believed.
void main() {
  group('parseGrpcPortFile', () {
    test('accepts a port, with or without the trailing newline', () {
      expect(parseGrpcPortFile('51234'), 51234);
      expect(parseGrpcPortFile('51234\n'), 51234);
      expect(parseGrpcPortFile('  51234  \n'), 51234);
    });

    test('rejects a half-written or empty file', () {
      expect(parseGrpcPortFile(''), isNull);
      expect(parseGrpcPortFile('\n'), isNull);
      expect(parseGrpcPortFile('512'), 512); // short but valid — not our call
      expect(parseGrpcPortFile('not-a-port'), isNull);
    });

    // 0 is "any port" when binding and meaningless when dialling.
    test('rejects out-of-range values', () {
      expect(parseGrpcPortFile('0'), isNull);
      expect(parseGrpcPortFile('-1'), isNull);
      expect(parseGrpcPortFile('65536'), isNull);
      expect(parseGrpcPortFile('65535'), 65535);
    });
  });

  group('NodeStatus.withGrpcPort', () {
    test('carries the port without disturbing the rest of the reading', () {
      final s = NodeStatus(
        running: true,
        pid: 4242,
        uptimeSecs: 90,
        cpuPercent: 1.5,
        source: 'status',
      );
      final withPort = s.withGrpcPort(51234);
      expect(withPort.grpcPort, 51234);
      expect(withPort.running, isTrue);
      expect(withPort.pid, 4242);
      expect(withPort.uptimeSecs, 90);
      expect(withPort.cpuPercent, 1.5);
      expect(withPort.source, 'status');
    });

    test('a daemon too old to write the file reads as null, not zero', () {
      expect(NodeStatus(running: true, pid: 1).withGrpcPort(null).grpcPort,
          isNull);
    });
  });

  group('KwaaiRpcClient.tcpPort', () {
    test('drops the channel so the probe re-dials the new port', () async {
      final client = KwaaiRpcClient();
      addTearDown(client.close);

      // Opens a channel (lazily — no server needed) and records its path.
      await client.daemonVersion();
      expect(client.debugConnectionPath, 'tcp://127.0.0.1:$kDefaultGrpcPort');

      client.tcpPort = kDefaultGrpcPort + 1;
      // Without this the probe short-circuits on the channel it already has
      // and pings the dead port for the rest of the session.
      expect(client.debugConnectionPath, isNull);
    });

    // The env var names a daemon on another host or in a container; the
    // status stream describes this host, so nothing must move this port.
    test('starts on the env port when one is set, else the default', () async {
      final client = KwaaiRpcClient();
      addTearDown(client.close);
      await client.daemonVersion();
      expect(
        client.debugConnectionPath,
        'tcp://127.0.0.1:${envGrpcPort ?? kDefaultGrpcPort}',
      );
    });

    test('setting the same port is a no-op', () async {
      final client = KwaaiRpcClient();
      addTearDown(client.close);

      await client.daemonVersion();
      final path = client.debugConnectionPath;
      client.tcpPort = kDefaultGrpcPort;
      expect(client.debugConnectionPath, path);
    });
  });
}
