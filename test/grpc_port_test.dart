import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/chat/kwaai_rpc_client.dart';

/// `KWAAINET_GRPC_PORT` decides which daemon the whole app talks to, so the
/// parsing has to fail safe: a bad value must fall back to the default rather
/// than leave the GUI pointed at nothing.
///
/// Dart cannot mutate `Platform.environment` in-process, so these exercise the
/// parse/validate rules directly. The wiring — that `_openChannel` uses this
/// port and skips the Unix socket when it is set — is covered by
/// `test/manual/grpc_port_live_test.dart` against a real daemon.
void main() {
  group('grpcPort', () {
    test('defaults to the daemon\'s own port when unset', () {
      // The env var is not set in the test runner, so this is the real path a
      // normal desktop launch takes.
      expect(grpcPort, kDefaultGrpcPort);
      expect(kDefaultGrpcPort, 8093);
    });
  });

  group('parseGrpcPort', () {
    test('accepts a plain port number', () {
      expect(parseGrpcPort('8099'), 8099);
      expect(parseGrpcPort('1'), 1);
      expect(parseGrpcPort('65535'), 65535);
    });

    test('falls back on values that are not a number', () {
      // The bug this guards against: an int.parse would throw here and take
      // out every RPC in the app, including against a perfectly good local
      // daemon the user never meant to redirect away from.
      expect(parseGrpcPort('node-f'), kDefaultGrpcPort);
      expect(parseGrpcPort('8099abc'), kDefaultGrpcPort);
      expect(parseGrpcPort('  '), kDefaultGrpcPort);
    });

    test('falls back on ports outside the valid range', () {
      // 0 is "any port" to bind(2) but meaningless to connect to, and a
      // ClientChannel would accept it and then fail obscurely.
      expect(parseGrpcPort('0'), kDefaultGrpcPort);
      expect(parseGrpcPort('-1'), kDefaultGrpcPort);
      expect(parseGrpcPort('65536'), kDefaultGrpcPort);
      expect(parseGrpcPort('99999999'), kDefaultGrpcPort);
    });

    test('treats unset and empty as unset', () {
      expect(parseGrpcPort(null), kDefaultGrpcPort);
      expect(parseGrpcPort(''), kDefaultGrpcPort);
    });
  });

  group('isGrpcPortOverridden', () {
    // This is what makes the override work at all on macOS/Linux: without it
    // the client prefers the Unix socket, a local daemon answers, and the port
    // is silently ignored.
    test('true only when a value is actually present', () {
      expect(isGrpcPortOverridden('8099'), isTrue);
      // Deliberately true even for a value that fails validation: the user
      // asked for a remote daemon, so falling back to the *local socket* would
      // be a surprising answer to a typo. Falling back to the default TCP port
      // at least keeps the transport they asked for.
      expect(isGrpcPortOverridden('garbage'), isTrue);
    });

    test('false when unset or empty', () {
      expect(isGrpcPortOverridden(null), isFalse);
      expect(isGrpcPortOverridden(''), isFalse);
    });
  });
}
