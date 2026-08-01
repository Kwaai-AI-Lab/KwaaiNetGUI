import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/chat/generated/kwaai.pb.dart' as pb;
import 'package:kwaainet_gui/src/chat/generated/kwaai.pbenum.dart' as pbenum;
import 'package:kwaainet_gui/src/ui/pages/peers_tab.dart';

pb.ConnectedPeer _conn(
  String peerId, {
  bool relay = false,
  bool bootstrap = false,
  bool trustedRelay = false,
  bool dcutr = false,
  String addr = '/ip4/198.18.0.10/tcp/8000',
}) {
  return pb.ConnectedPeer()
    ..peerId = peerId
    ..addr = addr
    ..kind = relay
        ? pbenum.PeerConnKind.PEER_CONN_KIND_RELAY
        : pbenum.PeerConnKind.PEER_CONN_KIND_DIRECT
    ..direction = 'outbound'
    ..isBootstrap = bootstrap
    ..isTrustedRelay = trustedRelay
    ..dcutr = dcutr;
}

pb.RoutingPeer _routing(
  String peerId, {
  bool connected = false,
  bool bootstrap = false,
}) {
  return pb.RoutingPeer()
    ..peerId = peerId
    ..connected = connected
    ..isBootstrap = bootstrap;
}

/// The merged table exists because a peer can be connected, in the DHT routing
/// table, or both — and the two sets overlap without either containing the
/// other. These tests pin all three states, since the middle one (connected but
/// deliberately not in the routing table, because the peer does not speak kad)
/// is the case two separate tables made invisible.
void main() {
  group('mergePeerRows', () {
    test('a peer in both sets produces one row', () {
      final rows = mergePeerRows([_conn('A')], [_routing('A', connected: true)]);

      expect(rows, hasLength(1));
      expect(rows.single.peerId, 'A');
      expect(rows.single.isConnected, isTrue);
      expect(rows.single.inRoutingTable, isTrue);
    });

    test('a connected peer absent from the routing table', () {
      // The normal state of a client-mode node: it does not advertise
      // /ipfs/kad/1.0.0, so the daemon deliberately never adds it. Previously
      // this peer simply did not appear in the routing table and the user had
      // no way to tell that from an error.
      final rows = mergePeerRows([_conn('A')], []);

      expect(rows.single.isConnected, isTrue);
      expect(rows.single.inRoutingTable, isFalse);
    });

    test('a known peer with no live connection', () {
      final rows = mergePeerRows([], [_routing('B')]);

      expect(rows.single.isConnected, isFalse);
      expect(rows.single.inRoutingTable, isTrue);
      expect(rows.single.primary, isNull);
      expect(rows.single.connections, isEmpty);
    });

    test('all three states coexist in one table', () {
      final rows = mergePeerRows(
        [_conn('both'), _conn('conn-only')],
        [_routing('both', connected: true), _routing('dht-only')],
      );

      expect(rows, hasLength(3));
      final byId = {for (final r in rows) r.peerId: r};
      expect(byId['both']!.isConnected && byId['both']!.inRoutingTable, isTrue);
      expect(byId['conn-only']!.isConnected, isTrue);
      expect(byId['conn-only']!.inRoutingTable, isFalse);
      expect(byId['dht-only']!.isConnected, isFalse);
      expect(byId['dht-only']!.inRoutingTable, isTrue);
    });
  });

  group('multiple connections to one peer', () {
    test('collapse into a single row that keeps both paths', () {
      // Mid-hole-punch: the relayed path still open, the direct one just built.
      final rows = mergePeerRows([
        _conn('A', relay: true, addr: '/ip4/1.2.3.4/tcp/1/p2p-circuit'),
        _conn('A', dcutr: true, addr: '/ip4/5.6.7.8/tcp/2'),
      ], []);

      expect(rows, hasLength(1));
      expect(rows.single.connections, hasLength(2));
      expect(rows.single.anyDcutr, isTrue);
    });

    test('the row is described by its direct path, not the relayed one', () {
      // If a peer is reachable both ways the direct path is what matters;
      // leading with the relay would understate the connection.
      final rows = mergePeerRows([
        _conn('A', relay: true),
        _conn('A', dcutr: true, addr: '/ip4/5.6.7.8/tcp/2'),
      ], []);

      expect(
        rows.single.primary!.kind,
        pbenum.PeerConnKind.PEER_CONN_KIND_DIRECT,
      );
      expect(rows.single.primary!.dcutr, isTrue);
    });

    test('a relay-only peer is described by its relayed path', () {
      final rows = mergePeerRows([_conn('A', relay: true)], []);
      expect(
        rows.single.primary!.kind,
        pbenum.PeerConnKind.PEER_CONN_KIND_RELAY,
      );
      expect(rows.single.anyDcutr, isFalse);
    });
  });

  group('ordering', () {
    test('follows the CLI grouping', () {
      // bootstrap → trusted relay → direct → relayed → routing-only. Matching
      // `kwaainet p2p peers list` means both surfaces describe the same network
      // the same way.
      final rows = mergePeerRows(
        [
          _conn('relayed', relay: true),
          _conn('direct'),
          _conn('trusted', trustedRelay: true),
          _conn('boot', bootstrap: true),
        ],
        [_routing('known-only')],
      );

      expect(rows.map((r) => r.peerId).toList(), [
        'boot',
        'trusted',
        'direct',
        'relayed',
        'known-only',
      ]);
    });

    test('a bootstrap sorts first even when reached over a relay', () {
      // "Did my bootstraps connect?" outranks how they connected.
      final rows = mergePeerRows(
        [_conn('zzz-boot', bootstrap: true, relay: true), _conn('aaa-direct')],
        [],
      );
      expect(rows.first.peerId, 'zzz-boot');
    });

    test('is stable, by peer id within a group', () {
      final rows = mergePeerRows(
        [_conn('c'), _conn('a'), _conn('b')],
        [],
      );
      expect(rows.map((r) => r.peerId).toList(), ['a', 'b', 'c']);
    });

    test('a routing-only bootstrap is still labelled and sorted first', () {
      // The flag comes off the routing entry when there is no connection to
      // read it from.
      final rows = mergePeerRows([_conn('zzz')], [_routing('aaa', bootstrap: true)]);
      expect(rows.first.peerId, 'aaa');
      expect(rows.first.isBootstrap, isTrue);
      expect(rows.first.isConnected, isFalse);
    });
  });

  test('an empty network produces no rows', () {
    expect(mergePeerRows([], []), isEmpty);
  });
}
