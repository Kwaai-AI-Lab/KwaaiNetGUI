import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat/kwaai_rpc_client.dart';
import '../chat/session_client.dart';

/// How long "no bootstrap reachable" must persist before the banner shows:
/// dnsaddr resolution and the initial dials are still in flight right after
/// a daemon start, and a banner that flashes red on every healthy start
/// teaches users to ignore it.
const bootstrapDownGrace = Duration(seconds: 30);

/// Delay before resubscribing after the network feed errors. UNAVAILABLE
/// during native startup ("p2p node is still starting") is the expected
/// case; the rpc connection itself is already up, so nothing else would
/// trigger a rebuild.
const _retryDelay = Duration(seconds: 10);

/// While the down state persists no new update arrives (the daemon
/// suppresses unchanged snapshots up to its heartbeat), so this local tick
/// re-evaluates [BootstrapHealth.downFor] against the grace period.
const _graceTick = Duration(seconds: 5);

/// `Error.Code.UNIMPLEMENTED` from kwaai.proto — the Go p2p path, where the
/// network feed will never exist. Retrying is pointless.
const _unimplemented = 6;

/// Bootstrap connectivity from the daemon's `NetworkUpdate` event stream.
///
/// [reachable] counts configured bootstraps that are connected or that
/// successfully connected within the daemon's ~15-minute contact window.
/// Recency rather than the live set because bootstraps close idle
/// connections (~30 s) while the announce loop re-contacts them every
/// ~5 minutes; and not the kad routing table, which is seeded with the
/// configured addresses before any dial succeeds and so proves nothing.
class BootstrapHealth {
  const BootstrapHealth({
    required this.total,
    required this.reachable,
    this.downFor,
  });

  /// Distinct peer IDs derivable from the daemon's configured bootstrap
  /// set. 0 from daemons predating the field or when no entry carries a
  /// `/p2p/` component — "unknowable", not "healthy", so the banner stays
  /// silent rather than crying wolf.
  final int total;

  final int reachable;

  /// How long the down state (total > 0, reachable == 0) has persisted,
  /// null when not down. What the grace period is measured against.
  final Duration? downFor;
}

/// Whether the red "bootstraps unreachable" banner shows. Pure, so the
/// whole truth table is a unit test.
///
/// Null health (daemon stopped or not answering) is not this banner's
/// story — the daemon-availability UX already covers it.
bool showBootstrapDownBanner(BootstrapHealth? health) =>
    health != null &&
    health.total > 0 &&
    health.reachable == 0 &&
    (health.downFor ?? Duration.zero) >= bootstrapDownGrace;

/// Shown only when reachable == 0, so it always reads "0 of N".
String bootstrapDownMessage(BootstrapHealth health) =>
    '${health.reachable} of ${health.total} bootstrap '
    '${health.total == 1 ? 'peer' : 'peers'} reachable — '
    'this node cannot join the network.';

/// Latest bootstrap-health sample, null while the daemon is unreachable.
///
/// Fed by the daemon's `NetworkUpdate` subscription, which is an *event*
/// stream: a peer-set change is pushed as it happens, so the banner clears
/// the moment a bootstrap connects rather than at the next poll. The
/// subscription is held open for the app's lifetime — unlike `peersProvider`
/// this cannot be autoDispose, since the whole point is watching while the
/// user is *not* looking at the Peers view. The long interval keeps the
/// standing cost to a heartbeat; transitions arrive on push regardless.
final bootstrapHealthProvider = StreamProvider<BootstrapHealth?>((ref) {
  final client = ref.watch(kwaaiRpcClientProvider);
  final conn = ref.watch(kwaaiRpcConnectionProvider).valueOrNull;
  final controller = StreamController<BootstrapHealth?>();
  if (conn != RpcConnection.connected) {
    controller.add(null);
    return controller.stream;
  }

  DateTime? downSince;
  var total = 0;
  var reachable = 0;
  var seen = false;
  var disposed = false;

  void emit() {
    if (disposed) return;
    controller.add(
      !seen
          ? null
          : BootstrapHealth(
              total: total,
              reachable: reachable,
              downFor: downSince == null
                  ? null
                  : DateTime.now().difference(downSince!),
            ),
    );
  }

  Future<void> run() async {
    while (!disposed) {
      try {
        await for (final update in client.networkStream(intervalSecs: 60)) {
          seen = true;
          total = update.bootstrapTotal;
          reachable = update.bootstrapReachable;
          final down = total > 0 && reachable == 0;
          downSince = down ? (downSince ?? DateTime.now()) : null;
          emit();
        }
      } on SessionOpError catch (e) {
        if (e.code == _unimplemented) return; // Go path: never available.
      } catch (_) {
        // Startup UNAVAILABLE or a dropped channel; state below resets.
      }
      seen = false;
      downSince = null;
      emit();
      await Future<void>.delayed(_retryDelay);
    }
  }

  final ticker = Timer.periodic(_graceTick, (_) {
    if (downSince != null) emit();
  });
  unawaited(run());

  // A dispose mid-`await for` lets the generator run until its next event,
  // when the loop guard ends it (and networkStream's finally cancels the
  // daemon-side op). Disposal only happens on a connection flip, which
  // kills the underlying channel — and the op with it — so the lag is moot.
  ref.onDispose(() {
    disposed = true;
    ticker.cancel();
    controller.close();
  });
  return controller.stream;
});
