import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat/generated/kwaai.pb.dart' as pb;
import '../chat/kwaai_rpc_client.dart';

/// Live local-p2p feed from the daemon: connections, the DHT routing table
/// and this node's own reachability.
///
/// Subscribes over the gRPC Session while listened to and cancels the
/// daemon-side operation on dispose (autoDispose), so the swarm is only
/// polled while the Network view is actually on screen. Gated on the rpc
/// connection state: watching it means the provider rebuilds, and thus
/// resubscribes, whenever the daemon goes away and comes back.
///
/// Unlike the block-coverage and storage feeds this is not purely periodic —
/// a reachability change is pushed as it happens, and `update.reason` says
/// which kind of update arrived.
///
/// Errors with `SessionOpError(code: UNIMPLEMENTED)` against a daemon running
/// the Go p2p stack, which has no way to report most of this. The view
/// renders that as an unavailable state rather than an error.
final peersProvider = StreamProvider.autoDispose<pb.NetworkUpdate>((
  ref,
) async* {
  final client = ref.watch(kwaaiRpcClientProvider);
  final conn = ref.watch(kwaaiRpcConnectionProvider).valueOrNull;
  if (conn != RpcConnection.connected) {
    return;
  }
  yield* client.networkStream();
});
