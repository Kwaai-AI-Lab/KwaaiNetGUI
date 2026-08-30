import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/chat/generated/kwaai.pb.dart' as pb;
import 'package:kwaainet_gui/src/chat/generated/kwaai.pbenum.dart' as pbenum;
import 'package:kwaainet_gui/src/daemon/peers_state.dart';
import 'package:kwaainet_gui/src/p2p/protocols.dart';
import 'package:kwaainet_gui/src/ui/pages/peers_tab.dart';
import 'package:kwaainet_gui/src/ui/theme/theme_variants.dart';

pb.ConnectedPeer _conn(String id, List<String> protocols) =>
    pb.ConnectedPeer()
      ..peerId = id
      ..addr = '/ip4/198.18.0.10/tcp/8000'
      ..kind = pbenum.PeerConnKind.PEER_CONN_KIND_DIRECT
      ..direction = 'outbound'
      ..protocols.addAll(protocols)
      ..dhtRole = pbenum.DhtRole.DHT_ROLE_SERVER;

/// Two connected peers with different KwaaiNet capabilities, on a node that
/// itself serves both.
pb.NetworkUpdate _update({List<String>? localProtocols}) => pb.NetworkUpdate()
  ..serverTime = '2026-08-01T12:00:00Z'
  ..reason = pbenum.UpdateReason.UPDATE_REASON_PEERS
  ..selfStatus = (pb.SelfStatus()
    ..peerId = '12D3KooWSelfExamplePeerIdentifier'
    ..reachability = 'public'
    ..reachabilitySource = 'autonat'
    ..announceable = true
    ..localProtocols.addAll(
      localProtocols ??
          const [
            '/ipfs/id/1.0.0',
            '/ipfs/kad/1.0.0',
            '/kwaai/inference/1.0.0',
            '/kwaai/p2p/hello/1.0.0',
          ],
    ))
  ..connected.addAll([
    _conn('12D3KooWPeerWithInferencexxxxAAINFER1', [
      '/ipfs/kad/1.0.0',
      // Deliberately a *newer* version than we advertise: the filter matches
      // by family, so a version skew must not hide the peer.
      '/kwaai/inference/2.0.0',
    ]),
    _conn('12D3KooWPeerHelloOnlyxxxxxxxxBBHELLO1', [
      '/ipfs/kad/1.0.0',
      '/kwaai/p2p/hello/1.0.0',
    ]),
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
  group('protocolFamily', () {
    test('strips a trailing version segment', () {
      expect(protocolFamily('/kwaai/inference/1.0.0'), '/kwaai/inference');
      expect(protocolFamily('/kwaai/p2p/hello/1.0.0'), '/kwaai/p2p/hello');
      expect(protocolFamily('/ipfs/kad/1.0.0'), '/ipfs/kad');
    });

    test('leaves an unversioned id whole', () {
      expect(protocolFamily('/libp2p/dcutr'), '/libp2p/dcutr');
      expect(protocolFamily('DHTProtocol.rpc_find'), 'DHTProtocol.rpc_find');
    });
  });

  group('kwaaiProtocolFamilies', () {
    test('keeps only /kwaai/ ids, one per family, sorted', () {
      final families = kwaaiProtocolFamilies(const [
        '/ipfs/id/1.0.0',
        '/kwaai/p2p/hello/1.0.0',
        '/kwaai/inference/1.0.0',
        '/kwaai/inference/2.0.0',
        '/libp2p/dcutr',
      ]);
      expect(families.keys.toList(), [
        '/kwaai/inference',
        '/kwaai/p2p/hello',
      ]);
      // The mapped id is a full versioned form, usable with describeProtocol.
      expect(families['/kwaai/inference'], '/kwaai/inference/1.0.0');
    });
  });

  group('protocol filter drop-down', () {
    testWidgets('shows all peers by default, next to the other filters', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_update()));
      await tester.pumpAndSettle();

      expect(find.text('Protocols'), findsOneWidget);
      expect(_textWith('AAINFER1'), findsOneWidget);
      expect(_textWith('BBHELLO1'), findsOneWidget);
    });

    testWidgets('narrows to peers advertising a checked family, across '
        'versions', (tester) async {
      await tester.pumpWidget(_host(_update()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Protocols'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/kwaai/inference'));
      await tester.pumpAndSettle();

      // We advertise 1.0.0, the peer advertises 2.0.0 — family matching
      // keeps it visible.
      expect(_textWith('AAINFER1'), findsOneWidget);
      expect(_textWith('BBHELLO1'), findsNothing);
      // The withheld row is counted, same as the other filters.
      expect(_textWith('1 hidden'), findsOneWidget);
      // The trigger reports the active selection.
      expect(find.text('Protocols (1)'), findsOneWidget);
    });

    testWidgets('clearing the selection restores every peer', (tester) async {
      await tester.pumpWidget(_host(_update()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Protocols'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/kwaai/inference'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show all peers'));
      await tester.pumpAndSettle();

      expect(_textWith('AAINFER1'), findsOneWidget);
      expect(_textWith('BBHELLO1'), findsOneWidget);
      expect(_textWith('hidden'), findsNothing);
    });

    testWidgets('absent when this node advertises no KwaaiNet protocol', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(_update(localProtocols: ['/ipfs/id/1.0.0', '/ipfs/kad/1.0.0'])),
      );
      await tester.pumpAndSettle();

      expect(find.text('Protocols'), findsNothing);
    });
  });
}
