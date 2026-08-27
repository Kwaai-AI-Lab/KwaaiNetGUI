import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/chat/generated/kwaai.pb.dart' as pb;
import 'package:kwaainet_gui/src/ui/pages/storage_tab.dart';

/// The daemon sends the VPK registry sorted by name then peer id, with
/// reachability filled in afterwards (`build_storage_peers` /
/// `probe_storage_peers` in kwaai-cli/src/grpc_server.rs). Wire order
/// therefore says nothing about which nodes this daemon can use, which is
/// what the view's own ordering fixes.
void main() {
  pb.StoragePeer peer(
    String name,
    pb.StorageReachability reach, {
    String id = '',
  }) => pb.StoragePeer(
    peerId: id.isEmpty ? '12D3Koo$name' : id,
    publicName: name,
    reachability: reach,
  );

  const reachable = pb.StorageReachability.STORAGE_REACHABILITY_REACHABLE;
  const unreachable = pb.StorageReachability.STORAGE_REACHABILITY_UNREACHABLE;
  const unknown = pb.StorageReachability.STORAGE_REACHABILITY_UNKNOWN;

  group('orderStoragePeers', () {
    test('reachable first, then probing, then unreachable', () {
      final ordered = orderStoragePeers([
        peer('a-down', unreachable),
        peer('b-probing', unknown),
        peer('c-up', reachable),
      ]);

      expect(
        ordered.map((p) => p.publicName),
        ['c-up', 'b-probing', 'a-down'],
        reason: 'name order alone would bury the only usable node',
      );
    });

    test('keeps the daemon name-then-id order within a group', () {
      final ordered = orderStoragePeers([
        peer('eve', reachable, id: 'zzz'),
        peer('bob', reachable),
        peer('eve', reachable, id: 'aaa'),
      ]);

      expect(ordered.map((p) => p.peerId), ['12D3Koobob', 'aaa', 'zzz']);
    });

    test('leaves the pending round in name order', () {
      // Every node is unknown until the probes land, so the first update
      // must not shuffle relative to what the daemon sent.
      final ordered = orderStoragePeers([
        peer('alice', unknown),
        peer('bob', unknown),
      ]);

      expect(ordered.map((p) => p.publicName), ['alice', 'bob']);
    });
  });
}
