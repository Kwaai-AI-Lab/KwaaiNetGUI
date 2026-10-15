import 'dart:async';

import 'package:flutter/foundation.dart';
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

/// Announced names by peer id, for the Peers table's NAME column.
///
/// Derived from the block-coverage and storage-registry feeds rather than its
/// own RPC, at a 60 s cadence with storage probes skipped: watching this must
/// not start the Sharding tab's 5 s crawl or dial every Eve.
///
/// Coverage is read for this node's own model only, so a name shows just for
/// peers serving that model or in the VPK registry; anyone else reads '—'.
final peerNamesProvider = StreamProvider.autoDispose<Map<String, String>>((
  ref,
) {
  final client = ref.watch(kwaaiRpcClientProvider);
  final conn = ref.watch(kwaaiRpcConnectionProvider).valueOrNull;
  if (conn != RpcConnection.connected) {
    return const Stream.empty();
  }
  return mergePeerNameStreams(
    client.blockCoverageStream(intervalSecs: 60).map(namesFromCoverage),
    client
        .storageDiscoveryStream(intervalSecs: 60, skipProbes: true)
        .map(namesFromStorage),
  );
});

/// Non-empty announced names in a coverage update, by peer id.
Map<String, String> namesFromCoverage(pb.BlockCoverageUpdate update) => {
  for (final p in update.peers)
    if (p.publicName.isNotEmpty) p.peerId: p.publicName,
};

/// Non-empty announced names in a storage-registry update, by peer id.
Map<String, String> namesFromStorage(pb.StorageUpdate update) => {
  for (final p in update.peers)
    if (p.publicName.isNotEmpty) p.peerId: p.publicName,
};

/// One name per peer; a block record's name wins over a storage record's.
Map<String, String> mergePeerNames(
  Map<String, String> blocks,
  Map<String, String> storage,
) => {...storage, ...blocks};

/// Emits [mergePeerNames] of the latest map from each source whenever either
/// updates and the result changed. A source's error is logged and its end
/// keeps its last names; cancelling the result cancels both sources.
Stream<Map<String, String>> mergePeerNameStreams(
  Stream<Map<String, String>> blocks,
  Stream<Map<String, String>> storage,
) {
  var fromBlocks = const <String, String>{};
  var fromStorage = const <String, String>{};
  final subs = <StreamSubscription<Map<String, String>>>[];
  late final StreamController<Map<String, String>> out;
  Map<String, String>? last;
  var open = 2;
  void done() {
    if (--open == 0) out.close();
  }

  void emit() {
    final merged = mergePeerNames(fromBlocks, fromStorage);
    if (last != null && mapEquals(last, merged)) return;
    out.add(last = merged);
  }

  out = StreamController<Map<String, String>>(
    onListen: () {
      subs.add(
        blocks.listen(
          (names) {
            fromBlocks = names;
            emit();
          },
          onError: (Object e) => debugPrint('peer names: blocks feed: $e'),
          onDone: done,
        ),
      );
      subs.add(
        storage.listen(
          (names) {
            fromStorage = names;
            emit();
          },
          onError: (Object e) => debugPrint('peer names: storage feed: $e'),
          onDone: done,
        ),
      );
    },
    onCancel: () => Future.wait([for (final s in subs) s.cancel()]),
  );
  return out.stream;
}
