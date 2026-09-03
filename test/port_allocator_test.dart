import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kwaainet_gui/src/daemon/port_allocator.dart';

void main() {
  test('hands back a port the daemon can then bind', () async {
    final port = await allocateFreePort();
    expect(port, greaterThan(0));
    // The whole mechanism rests on the port being free once we close it —
    // if reuseAddress or a lingering TIME_WAIT got in the way, the daemon
    // would fail to start on every port we ever chose.
    final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    expect(s.port, port);
    await s.close();
  });

  test('does not hand back the same port twice in a row', () async {
    final a = await allocateFreePort();
    final b = await allocateFreePort();
    expect(a, isNot(b));
  });

  test('can allocate on the wildcard address for the p2p listener', () async {
    final port = await allocateFreePort(address: InternetAddress.anyIPv4);
    expect(port, greaterThan(0));
  });

  // The daemon binds [::1] on the same port it was handed, so a port only
  // IPv4 vouched for would make it fail to start on a dual-stack host.
  test('returned port is bindable on ::1', () async {
    if (!await _hasIPv6Loopback()) {
      markTestSkipped('host has no IPv6 loopback');
      return;
    }
    final port = await allocateFreePort();
    final s = await ServerSocket.bind(
      InternetAddress.loopbackIPv6,
      port,
      v6Only: true,
    );
    expect(s.port, port);
    await s.close();
  });

  test('avoids a port held only on IPv6', () async {
    if (!await _hasIPv6Loopback()) {
      markTestSkipped('host has no IPv6 loopback');
      return;
    }
    final held = await ServerSocket.bind(
      InternetAddress.loopbackIPv6,
      0,
      v6Only: true,
    );
    final v4 = InternetAddress.loopbackIPv4;
    expect(await freeOnBothFamilies(v4, held.port), isFalse);
    await held.close();
    expect(await freeOnBothFamilies(v4, held.port), isTrue);
  });
}

/// CI images and some containers run without an IPv6 stack; there the v6
/// half of the check is unreachable rather than failing.
Future<bool> _hasIPv6Loopback() async {
  try {
    final s = await ServerSocket.bind(InternetAddress.loopbackIPv6, 0);
    await s.close();
    return true;
  } on SocketException {
    return false;
  }
}
