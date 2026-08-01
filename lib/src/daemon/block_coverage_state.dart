import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat/generated/kwaai.pb.dart' as pb;
import '../chat/kwaai_rpc_client.dart';

/// Live model block-coverage feed from the daemon.
///
/// Subscribes over the gRPC Session while listened to and cancels the
/// daemon-side operation on dispose (autoDispose), so the DHT is only
/// polled while a coverage view is actually on screen. Gated on the rpc
/// connection state: watching it means the provider rebuilds — and thus
/// resubscribes — whenever the daemon goes away and comes back.
final blockCoverageProvider =
    StreamProvider.autoDispose<pb.BlockCoverageUpdate>((ref) async* {
  final client = ref.watch(kwaaiRpcClientProvider);
  final conn = ref.watch(kwaaiRpcConnectionProvider).valueOrNull;
  if (conn != RpcConnection.connected) {
    return;
  }
  yield* client.blockCoverageStream();
});
