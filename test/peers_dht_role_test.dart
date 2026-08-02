import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/chat/generated/kwaai.pb.dart' as pb;
import 'package:kwaainet_gui/src/chat/generated/kwaai.pbenum.dart' as pbenum;
import 'package:kwaainet_gui/src/ui/pages/peers_tab.dart';

pb.ConnectedPeer _conn(
  String peerId, {
  pbenum.DhtRole role = pbenum.DhtRole.DHT_ROLE_SERVER,
  bool relay = false,
  bool bootstrap = false,
  bool trustedRelay = false,
}) {
  return pb.ConnectedPeer()
    ..peerId = peerId
    ..addr = '/ip4/198.18.0.10/tcp/8000'
    ..kind = relay
        ? pbenum.PeerConnKind.PEER_CONN_KIND_RELAY
        : pbenum.PeerConnKind.PEER_CONN_KIND_DIRECT
    ..direction = 'outbound'
    ..isBootstrap = bootstrap
    ..isTrustedRelay = trustedRelay
    ..dhtRole = role;
}

pb.RoutingPeer _routing(String peerId, {bool connected = false}) {
  return pb.RoutingPeer()
    ..peerId = peerId
    ..connected = connected;
}

PeerRow _row(pb.ConnectedPeer conn) =>
    mergePeerRows([conn], const []).single;

/// Client-mode peers query the DHT without serving it. They are real peers —
/// every hivemind/Python process proxies through one, and one of our own nodes
/// enters this mode whenever it is only reachable via a relay — but they can
/// never be a routing hop, which is why the table marks and optionally hides
/// them rather than counting them as nodes.
void main() {
  test('a kad speaker is not a client', () {
    expect(_row(_conn('A')).isDhtClient, isFalse);
  });

  test('a query-only peer is a client', () {
    final row = _row(_conn('A', role: pbenum.DhtRole.DHT_ROLE_CLIENT));
    expect(row.isDhtClient, isTrue);
  });

  /// The flicker guard. identify lands *after* the connection establishes, so
  /// a just-connected peer reports no role at all. Treating that as "client"
  /// would drop every new peer out of the default view for its first moments
  /// and then pop it back in.
  test('an unreported role is not treated as a client', () {
    final row = _row(_conn('A', role: pbenum.DhtRole.DHT_ROLE_UNKNOWN));
    expect(row.isDhtClient, isFalse);
  });

  /// A routing-only peer has no connection to read a role from. It is in the
  /// routing table, which is the opposite of being a non-serving client.
  test('a routing-only peer is never a client', () {
    final rows = mergePeerRows(const [], [_routing('A')]);
    expect(rows.single.isDhtClient, isFalse);
  });

  /// The axes are independent, not exclusive. `is_bootstrap` and
  /// `is_trusted_relay` come from operator configuration; the DHT role is
  /// observed from identify. Nothing stops a configured peer being client-mode,
  /// and the row must report both rather than letting one mask the other.
  test('a configured peer can also be client-mode', () {
    final row = _row(_conn(
      'A',
      bootstrap: true,
      role: pbenum.DhtRole.DHT_ROLE_CLIENT,
    ));
    expect(row.isBootstrap, isTrue);
    expect(row.isDhtClient, isTrue);
  });

  test('a trusted relay can also be client-mode', () {
    final row = _row(_conn(
      'A',
      trustedRelay: true,
      role: pbenum.DhtRole.DHT_ROLE_CLIENT,
    ));
    expect(row.isTrustedRelay, isTrue);
    expect(row.isDhtClient, isTrue);
  });

  /// The collapsed row describes the primary (direct-preferred) connection, so
  /// the role must be read from that same connection rather than from whichever
  /// one happens to be first.
  test('the role follows the primary connection', () {
    final rows = mergePeerRows(
      [
        _conn('A', relay: true, role: pbenum.DhtRole.DHT_ROLE_UNKNOWN),
        _conn('A', role: pbenum.DhtRole.DHT_ROLE_CLIENT),
      ],
      const [],
    );
    expect(rows.single.isDhtClient, isTrue);
  });
}
