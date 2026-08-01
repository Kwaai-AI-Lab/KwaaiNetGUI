import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/chat/generated/kwaai.pb.dart' as pb;
import 'package:kwaainet_gui/src/ui/pages/storage_tab.dart';

/// The staleness cue exists because the daemon suppresses discovery
/// rounds that would say nothing new (see `HEARTBEAT` and
/// `storage_identity` in kwaai-cli/src/grpc_server.rs). Silence is
/// therefore normal, and the only thing separating "healthy and quiet"
/// from "wedged" is that the daemon still sends an unchanged snapshot
/// every 60 s.
///
/// That makes these constants a cross-repo contract rather than a local
/// style choice, which is what this test pins.
void main() {
  group('storage staleness threshold', () {
    // The daemon's HEARTBEAT, shared with block coverage. If that
    // constant moves, this test should fail and storageStaleAfter has to
    // move with it.
    const daemonHeartbeat = Duration(seconds: 60);

    test('clears the daemon heartbeat with margin', () {
      expect(
        storageStaleAfter,
        greaterThan(daemonHeartbeat),
        reason: 'a threshold at or below the heartbeat would flag every '
            'healthy quiet period as stale',
      );
      expect(
        storageStaleAfter - daemonHeartbeat,
        greaterThanOrEqualTo(const Duration(seconds: 30)),
        reason: 'too little margin makes the cue flap on normal jitter — a '
            'round that dials every node can legitimately run long',
      );
    });

    test('still catches a genuinely quiet daemon promptly', () {
      // Past a couple of missed heartbeats the view is stale in a way the
      // user should see rather than trust.
      expect(
        storageStaleAfter,
        lessThanOrEqualTo(daemonHeartbeat * 3),
        reason: 'too much slack leaves stale capacity figures looking live',
      );
    });

    test('re-evaluates often enough to be responsive', () {
      // Nothing rebuilds the view between rounds, so the tick is what
      // makes the cue appear at all.
      expect(storageStaleTick, lessThan(storageStaleAfter));
      expect(storageStaleTick.inSeconds, greaterThan(0));
    });
  });

  group('describeStorageStaleness', () {
    test('rounds coarsely and never shows a bare number', () {
      expect(describeStorageStaleness(const Duration(seconds: 45)), '45s');
      expect(describeStorageStaleness(const Duration(minutes: 5)), '5m');
      expect(describeStorageStaleness(const Duration(hours: 3)), '3h');
      expect(describeStorageStaleness(const Duration(days: 2)), '2d');
    });

    test('falls back when no update has ever arrived', () {
      // Null means the subscription has produced nothing yet, which is a
      // different state from "arrived a long time ago" — it must not
      // render as "0s", which would read as perfectly fresh.
      expect(describeStorageStaleness(null), 'a while');
    });

    test('switches units at the boundaries, not mid-range', () {
      expect(describeStorageStaleness(const Duration(seconds: 119)), '119s');
      expect(describeStorageStaleness(const Duration(seconds: 120)), '2m');
      expect(describeStorageStaleness(const Duration(minutes: 59)), '59m');
      expect(describeStorageStaleness(const Duration(minutes: 60)), '1h');
    });
  });

  group('StorageTotals', () {
    pb.StoragePeer peer({
      required double capacity,
      required double free,
      required pb.StorageReachability reach,
      int tenants = 0,
    }) =>
        pb.StoragePeer()
          ..peerId = 'p${capacity.toStringAsFixed(0)}${free.toStringAsFixed(0)}'
          ..capacityGb = capacity
          ..capacityGbFree = free
          ..tenantCount = tenants
          ..reachability = reach;

    const reachable = pb.StorageReachability.STORAGE_REACHABILITY_REACHABLE;
    const unreachable = pb.StorageReachability.STORAGE_REACHABILITY_UNREACHABLE;
    const unknown = pb.StorageReachability.STORAGE_REACHABILITY_UNKNOWN;

    test('splits reachable capacity into used and free', () {
      final t = StorageTotals.of([
        peer(capacity: 100, free: 40, reach: reachable),
        peer(capacity: 50, free: 50, reach: reachable),
      ]);

      expect(t.usedGb, 60);
      expect(t.freeGb, 90);
      expect(t.unreachableGb, 0);
      expect(t.reachableGb, 150);
      expect(t.advertisedGb, 150);
    });

    test('keeps unreachable capacity out of used and free', () {
      // Nothing is known about an unreachable node's occupancy, so its
      // capacity must not land in either confirmed zone — that would
      // claim free space this daemon cannot actually use.
      final t = StorageTotals.of([
        peer(capacity: 100, free: 40, reach: reachable),
        peer(capacity: 80, free: 80, reach: unreachable),
      ]);

      expect(t.usedGb, 60);
      expect(t.freeGb, 40);
      expect(t.unreachableGb, 80);
      expect(t.advertisedGb, 180);
    });

    test('leaves still-probing nodes out of every zone', () {
      // A pending node belongs to one of the three zones, but which one
      // is exactly what is unknown — counting it anywhere would make the
      // bar jump when the probe lands.
      final t = StorageTotals.of([
        peer(capacity: 100, free: 40, reach: reachable),
        peer(capacity: 60, free: 0, reach: unknown),
      ]);

      expect(t.usedGb + t.freeGb + t.unreachableGb, 100);
      expect(t.advertisedGb, 160, reason: 'the header still counts it');
      expect(t.pendingCount, 1);
      expect(t.nodeCount, 2);
    });

    test('clamps a node reporting more free space than it has', () {
      // Would otherwise contribute negative used space and shrink the bar.
      final t = StorageTotals.of([
        peer(capacity: 10, free: 25, reach: reachable),
      ]);

      expect(t.usedGb, 0);
      expect(t.usedGb, greaterThanOrEqualTo(0));
    });

    test('counts nodes and tenants across every reachability', () {
      final t = StorageTotals.of([
        peer(capacity: 10, free: 5, reach: reachable, tenants: 2),
        peer(capacity: 10, free: 0, reach: unreachable, tenants: 3),
        peer(capacity: 10, free: 0, reach: unknown, tenants: 1),
      ]);

      expect(t.tenants, 6);
      expect(t.reachableCount, 1);
      expect(t.unreachableCount, 1);
      expect(t.pendingCount, 1);
      expect(t.nodeCount, 3);
    });

    test('is all zeroes for an empty network', () {
      final t = StorageTotals.of([]);
      expect(t.advertisedGb, 0);
      expect(t.usedGb, 0);
      expect(t.freeGb, 0);
      expect(t.unreachableGb, 0);
      expect(t.nodeCount, 0);
    });
  });

  group('freeBandFor', () {
    pb.StoragePeer peer(
      String id,
      double free, {
      pb.StorageReachability reach =
          pb.StorageReachability.STORAGE_REACHABILITY_REACHABLE,
    }) =>
        pb.StoragePeer()
          ..peerId = id
          ..capacityGb = free
          ..capacityGbFree = free
          ..reachability = reach;

    test('offsets by the free space of the peers ahead of it', () {
      final peers = [peer('a', 10), peer('b', 20), peer('c', 30)];

      expect(freeBandFor(peers, 'a').offsetGb, 0);
      expect(freeBandFor(peers, 'b').offsetGb, 10);
      expect(freeBandFor(peers, 'c').offsetGb, 30);

      expect(freeBandFor(peers, 'b').freeGb, 20);
    });

    test('the last peer ends exactly at the free total', () {
      // Otherwise the band would overhang the zone it sits in.
      final peers = [peer('a', 10), peer('b', 20), peer('c', 30)];
      final band = freeBandFor(peers, 'c');
      expect(band.offsetGb + band.freeGb, 60);
    });

    test('skips peers that contribute no free space', () {
      // Unreachable and still-probing peers take up no room in the free
      // zone, so they must not push later peers along it either.
      final peers = [
        peer('a', 10),
        peer('skip', 999,
            reach: pb.StorageReachability.STORAGE_REACHABILITY_UNREACHABLE),
        peer('pending', 999,
            reach: pb.StorageReachability.STORAGE_REACHABILITY_UNKNOWN),
        peer('b', 20),
      ];

      expect(freeBandFor(peers, 'b').offsetGb, 10);
    });

    test('is empty when nothing is selected or the peer cannot hold data',
        () {
      final peers = [
        peer('a', 10),
        peer('down', 50,
            reach: pb.StorageReachability.STORAGE_REACHABILITY_UNREACHABLE),
      ];

      expect(freeBandFor(peers, null).freeGb, 0);
      expect(freeBandFor(peers, 'missing').freeGb, 0);
      // Selectable in the table, but it has no confirmed free space to
      // point at, so the cylinder highlights nothing.
      expect(freeBandFor(peers, 'down').freeGb, 0);
      expect(freeBandFor(peers, 'down').offsetGb, 0);
    });
  });

  group('formatCapacity', () {
    test('reads in GB below a terabyte', () {
      expect(formatCapacity(0), '0.0 GB');
      expect(formatCapacity(5), '5.0 GB');
      expect(formatCapacity(69.53), '69.5 GB');
      expect(formatCapacity(999.9), '999.9 GB');
    });

    test('switches to TB rather than showing four digits of GB', () {
      // A network of a few dozen contributors passes 1000 GB easily, and
      // "1234.5 GB" is harder to size up at a glance than "1.2 TB".
      expect(formatCapacity(1000), '1.0 TB');
      expect(formatCapacity(1234.5), '1.2 TB');
    });
  });
}
