import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/chat/generated/kwaai.pb.dart' as pb;
import 'package:kwaainet_gui/src/chat/generated/kwaai.pbenum.dart' as pbenum;
import 'package:kwaainet_gui/src/daemon/peers_state.dart';
import 'package:kwaainet_gui/src/ui/pages/peers_tab.dart';
import 'package:kwaainet_gui/src/ui/theme/theme_variants.dart';

pb.ConnectedPeer _conn(
  String id, {
  String direction = 'outbound',
  bool dcutr = false,
}) => pb.ConnectedPeer()
  ..peerId = id
  ..addr = '/ip4/198.18.0.10/tcp/8000'
  ..kind = pbenum.PeerConnKind.PEER_CONN_KIND_DIRECT
  ..direction = direction
  ..dcutr = dcutr
  ..protocols.add('/ipfs/kad/1.0.0')
  ..dhtRole = pbenum.DhtRole.DHT_ROLE_SERVER;

/// One connected peer and [routingOnly] peers we know of but have no
/// connection to.
pb.NetworkUpdate _update({
  int routingOnly = 2,
  String reachability = 'public',
  String source = 'autonat',
  bool usingRelay = false,
  bool dcutr = false,
}) => pb.NetworkUpdate()
  ..serverTime = '2026-08-01T12:00:00Z'
  ..reason = pbenum.UpdateReason.UPDATE_REASON_PEERS
  ..selfStatus = (pb.SelfStatus()
    ..peerId = '12D3KooWSelfExamplePeerIdentifier'
    ..reachability = reachability
    ..reachabilitySource = source
    ..usingRelay = usingRelay
    ..announceable = true)
  ..connected.add(
    _conn('12D3KooWServerPeerNumber0xxxxxxxxxxxxxxxxxxxx', dcutr: dcutr),
  )
  ..routing.addAll([
    for (var i = 0; i < routingOnly; i++)
      pb.RoutingPeer()
        ..peerId = '12D3KooWRoutingPeerNumber${i}xxxxxxxxxxxxxxxxxxx'
        ..connected = false
        ..addrs.add('/ip4/198.18.0.${20 + i}/tcp/8000'),
  ]);

Widget _host(pb.NetworkUpdate update) => ProviderScope(
  overrides: [peersProvider.overrideWith((ref) => Stream.value(update))],
  child: MaterialApp(
    theme: buildKwaaiTheme(ThemeVariantKey.kwaai, Brightness.dark),
    home: const Scaffold(
      body: SizedBox(width: 1100, height: 700, child: PeersTab()),
    ),
  ),
);

Finder _textWith(String fragment) => find.byWidgetPredicate(
  (w) => w is Text && (w.data ?? '').contains(fragment),
);

void main() {
  /// The routing table carries every peer this node has ever learned an
  /// address for. Listed, they bury the handful it is actually talking to.
  group('unconnected filter', () {
    testWidgets('hides routing-only peers by default and counts them', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_update(routingOnly: 2)));
      await tester.pumpAndSettle();

      expect(find.text('Show unconnected'), findsOneWidget);
      expect(_textWith('2 hidden'), findsOneWidget);
      expect(_textWith('RoutingPeerNumber'), findsNothing);
    });

    testWidgets('lists them once the box is checked', (tester) async {
      await tester.pumpWidget(_host(_update(routingOnly: 2)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show unconnected'));
      await tester.pumpAndSettle();

      expect(_textWith('hidden'), findsNothing);
      expect(find.text('Show unconnected'), findsOneWidget);
    });

    /// Nothing to hide, so the control would be noise.
    testWidgets('omits the box when every peer is connected', (tester) async {
      await tester.pumpWidget(_host(_update(routingOnly: 0)));
      await tester.pumpAndSettle();

      expect(find.text('Show unconnected'), findsNothing);
    });
  });

  /// The badge used to read "relayed" whenever a reservation was live, which
  /// understated a node peers had since punched through to.
  group('reachability badge', () {
    testWidgets('names the route in, strongest evidence first', (tester) async {
      await tester.pumpWidget(
        _host(
          _update(
            reachability: 'private',
            source: '',
            usingRelay: true,
            dcutr: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Behind NAT · hole punched'), findsOneWidget);
    });

    /// A reservation is a fact about us; it says nothing about whether a
    /// peer could punch through, which is unknowable until one tries.
    testWidgets('reports a held reservation without calling it the ceiling', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(_update(reachability: 'private', source: '', usingRelay: true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Behind NAT · relay reserved'), findsOneWidget);
    });

    testWidgets('says so when nothing can reach us', (tester) async {
      await tester.pumpWidget(
        _host(_update(reachability: 'private', source: '')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Behind NAT · outbound only'), findsOneWidget);
    });

    testWidgets('a public node keeps its evidence source', (tester) async {
      await tester.pumpWidget(_host(_update()));
      await tester.pumpAndSettle();

      expect(find.text('Public · via autonat'), findsOneWidget);
    });
  });

  /// A peer that dialled us *and* got dialled is described by neither arrow
  /// alone, and the collapsed row only draws one.
  group('PeerRow.bothDirections', () {
    const id = '12D3KooWBothDirectionsExamplePeerIdentifier';

    PeerRow row(List<pb.ConnectedPeer> conns) => PeerRow(
      peerId: id,
      connections: conns,
      inRoutingTable: true,
      isBootstrap: false,
      isTrustedRelay: false,
    );

    test('true only with a connection each way', () {
      expect(
        row([_conn(id), _conn(id, direction: 'inbound')]).bothDirections,
        isTrue,
      );
      expect(row([_conn(id)]).bothDirections, isFalse);
      expect(
        row([
          _conn(id, direction: 'inbound'),
          _conn(id, direction: 'inbound'),
        ]).bothDirections,
        isFalse,
      );
      expect(row(const []).bothDirections, isFalse);
    });
  });
}
