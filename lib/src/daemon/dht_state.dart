import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat/generated/kwaai.pb.dart' as pb;
import '../chat/kwaai_rpc_client.dart';

/// One-shot listing of the hivemind DHT records this node holds locally.
///
/// A stream that yields once and completes, rather than a FutureProvider: it
/// has to watch the rpc connection and emit nothing at all while the daemon is
/// away, which a Future cannot express without inventing a failure.
///
/// Refreshed by invalidating it — there is no subscription to keep open, so
/// the daemon is only asked when the DHT view is on screen and the reader asks
/// for a fresh reading.
///
/// Metadata only: values are the expensive half of the request and are fetched
/// per record by the detail view. Errors with
/// `SessionOpError(code: UNIMPLEMENTED)` against a daemon running the Go p2p
/// stack, which has no hivemind store to enumerate.
final dhtRecordsProvider = StreamProvider.autoDispose<pb.DhtRecordsReply>((
  ref,
) async* {
  final client = ref.watch(kwaaiRpcClientProvider);
  final conn = ref.watch(kwaaiRpcConnectionProvider).valueOrNull;
  if (conn != RpcConnection.connected) {
    return;
  }
  yield await client.dhtRecords();
});
