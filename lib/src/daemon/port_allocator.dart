import 'dart:io';

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
Future<int> allocateFreePort({InternetAddress? address}) async {
  final socket = await ServerSocket.bind(
    address ?? InternetAddress.loopbackIPv4,
    0,
  );
  final port = socket.port;
  // Default reuseAddress is what lets the daemon rebind immediately; a
  // listener that never accepted leaves no TIME_WAIT behind.
  await socket.close();
  return port;
}
