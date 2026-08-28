import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kwaainet_gui/src/daemon/daemon_env.dart';

/// Every daemon-identity artifact the CLI touches is selected by environment,
/// so a child launched without this map talks about the wrong daemon. That is
/// not hypothetical: `stop` used to be launched with no environment at all,
/// which is how quitting one GUI killed the other one's node.
void main() {
  const base = {'PATH': '/usr/bin', 'HOME': '/Users/nobody'};

  group('daemonChildEnvironment', () {
    test('always names the state directory and suppresses auto-update', () {
      final env = daemonChildEnvironment(base: base, home: '/state');
      expect(env['KWAAINET_HOME'], '/state');
      expect(env['KWAAINET_NO_AUTO_UPDATE'], '1');
    });

    test('preserves the base environment', () {
      final env = daemonChildEnvironment(base: base, home: '/state');
      expect(env['PATH'], '/usr/bin');
      expect(env['HOME'], '/Users/nobody');
    });

    // stop/--version describe *which* daemon; only start brings one up.
    test('omits the port variables unless they are given', () {
      final env = daemonChildEnvironment(base: base, home: '/state');
      expect(env.containsKey('KWAAINET_GRPC_PORT'), isFalse);
      expect(env.containsKey('KWAAINET_PORT'), isFalse);
      expect(env.containsKey('KWAAINET_SOCKET'), isFalse);
    });

    test('carries the ports and socket when given', () {
      final env = daemonChildEnvironment(
        base: base,
        home: '/state',
        p2pdSocket: '/tmp/kwaai-p2pd-abc.sock',
        grpcPort: 51234,
        p2pPort: 51235,
      );
      expect(env['KWAAINET_GRPC_PORT'], '51234');
      expect(env['KWAAINET_PORT'], '51235');
      expect(env['KWAAINET_SOCKET'], '/tmp/kwaai-p2pd-abc.sock');
    });
  });

  group('p2pdSocketFor', () {
    test('leaves an unsandboxed instance on the CLI default', () {
      expect(p2pdSocketFor('/Users/nobody/.kwaainet', sandboxed: false), isNull);
    });

    test('is stable for a given home and differs between homes', () {
      final a = p2pdSocketFor('/proj/a/.kwaainet-dev', sandboxed: true);
      final b = p2pdSocketFor('/proj/b/.kwaainet-dev', sandboxed: true);
      expect(a, isNotNull);
      expect(a, p2pdSocketFor('/proj/a/.kwaainet-dev', sandboxed: true));
      expect(a, isNot(b));
    });

    // sun_path is 104 bytes; a socket inside a deep checkout would blow it,
    // which is why this lives beside the CLI default rather than under home.
    test('stays short regardless of how deep the checkout is', () {
      final deep = '/${List.filled(20, 'very-long-directory-name').join('/')}';
      final sock = p2pdSocketFor(deep, sandboxed: true)!;
      expect(sock.length, lessThan(104));
      expect(sock, startsWith('/tmp/kwaai-p2pd-'));
    });
  }, skip: Platform.isWindows);
}
