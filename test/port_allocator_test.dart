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
}
