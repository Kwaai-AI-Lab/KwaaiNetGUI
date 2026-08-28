import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Environment for every `kwaainet` child this app runs.
///
/// Every daemon-identity artifact the CLI touches is selected by environment,
/// so this is the one place that decides which daemon a child talks about.
/// It must be applied to `stop` and `--version` as well as to `start`: a
/// `stop` without it reads `~/.kwaainet` and kills whatever is there, which
/// is why quitting one GUI used to take down the other one's daemon.
///
/// [grpcPort] and [p2pPort] are for `start` only — the others describe *which*
/// daemon, these describe how to bring a new one up.
Map<String, String> daemonChildEnvironment({
  required Map<String, String> base,
  required String home,
  String? p2pdSocket,
  int? grpcPort,
  int? p2pPort,
}) {
  final env = Map<String, String>.from(base);

  // Suppress the daemon's in-process auto-updater. The GUI owns notifying the
  // user about new versions — without this the daemon silently swaps its own
  // binary for the latest upstream release ~5 minutes into a session and exits
  // to restart, losing any locally-built feature work.
  env['KWAAINET_NO_AUTO_UPDATE'] = '1';

  // Set even when it resolves to ~/.kwaainet, so the child's view of its state
  // directory is identical to ours by construction rather than by inference.
  env['KWAAINET_HOME'] = home;

  if (p2pdSocket != null) env['KWAAINET_SOCKET'] = p2pdSocket;
  if (grpcPort != null) env['KWAAINET_GRPC_PORT'] = '$grpcPort';
  if (p2pPort != null) env['KWAAINET_PORT'] = '$p2pPort';

  return env;
}

/// The p2pd control socket for a sandboxed state directory, or null to leave
/// the CLI on its default (`/tmp/kwaai-p2pd.sock`).
///
/// Digest-named beside that default rather than placed inside [home]: a Unix
/// socket path is capped at 104 bytes on macOS, and both a deep checkout and
/// the per-user `TMPDIR` would eat into that. Only sandboxed instances move,
/// so a terminal `kwaainet p2p peers list` still finds the released daemon.
String? p2pdSocketFor(String home, {required bool sandboxed}) {
  if (!sandboxed || Platform.isWindows) return null;
  final digest = sha256.convert(utf8.encode(home)).toString().substring(0, 8);
  return '/tmp/kwaai-p2pd-$digest.sock';
}
