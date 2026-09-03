import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;

/// How many draws before giving up. A port free on IPv4 but held on IPv6 is
/// rare; needing all of these in a row means something else is wrong.
const int _maxDraws = 16;

/// Reserve a free TCP port for a daemon we are about to spawn.
///
/// Bind-then-close, so there is a window between us releasing the port and
/// the child claiming it — and it is not a short one: it spans `Process.start`,
/// the `start --daemon` re-exec into `run-node`, and tokio coming up. The
/// daemon closes it from the other end by *failing* rather than carrying on
/// without a listener when a port it was given is taken, which lets the caller
/// notice and draw another one.
///
/// [address] must match where the daemon will listen — the gRPC surface is
/// loopback-only, the p2p listener is not, and a port free on one is not
/// necessarily free on the other.
///
/// The daemon now binds both families on the port it is handed — `[::1]` as
/// well as `127.0.0.1` for gRPC, `/ip6/::` as well as `/ip4/0.0.0.0` for p2p —
/// so a port only IPv4 says is free is not good enough; see
/// [freeOnBothFamilies].
Future<int> allocateFreePort({InternetAddress? address}) async {
  final v4 = address ?? InternetAddress.loopbackIPv4;
  for (var i = 0; i < _maxDraws; i++) {
    final socket = await ServerSocket.bind(v4, 0);
    final port = socket.port;
    final free = await freeOnBothFamilies(v4, port);
    // Default reuseAddress is what lets the daemon rebind immediately; a
    // listener that never accepted leaves no TIME_WAIT behind.
    await socket.close();
    if (free) return port;
  }
  throw StateError('No port free on both IPv4 and IPv6 after $_maxDraws draws');
}

/// True when [port] is also free on [v4]'s IPv6 twin, or when the host has no
/// IPv6 at all — that is not a reason to reject an otherwise usable port.
@visibleForTesting
Future<bool> freeOnBothFamilies(InternetAddress v4, int port) async {
  final v6 = v4.isLoopback
      ? InternetAddress.loopbackIPv6
      : InternetAddress.anyIPv6;
  // Probe an ephemeral port first: a host with no IPv6 fails that too, and
  // the difference between the two failures is not in the errno — Dart's own
  // same-process guard reports a rebind without one at all.
  if (!await _canBind(v6, 0)) return true;
  return _canBind(v6, port);
}

Future<bool> _canBind(InternetAddress v6, int port) async {
  ServerSocket? socket;
  try {
    // v6Only, so this probes the IPv6 port on its own rather than taking a
    // dual-stack bind that the caller's still-open v4 socket would refuse.
    socket = await ServerSocket.bind(v6, port, v6Only: true);
    return true;
  } on SocketException {
    return false;
  } finally {
    await socket?.close();
  }
}
