import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat/generated/kwaai.pb.dart' as pb;
import '../chat/kwaai_rpc_client.dart';

/// One-shot listing of this node's hivemind store, metadata only. Yields once
/// and completes; emits nothing while the daemon is away; invalidate to refresh.
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
