import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/chat/generated/kwaai.pb.dart' as pb;
import 'package:kwaainet_gui/src/chat/generated/kwaai.pbenum.dart' as pbenum;
import 'package:kwaainet_gui/src/daemon/peers_state.dart';
import 'package:kwaainet_gui/src/ui/pages/peers_tab.dart';
import 'package:kwaainet_gui/src/ui/theme/theme_variants.dart';

/// Two kad-serving peers and [clients] query-only ones.
pb.NetworkUpdate _update({int clients = 2}) {
  return pb.NetworkUpdate()
    ..serverTime = '2026-08-01T12:00:00Z'
    ..reason = pbenum.UpdateReason.UPDATE_REASON_PEERS
    ..selfStatus = (pb.SelfStatus()
      ..peerId = '12D3KooWSelfExamplePeerIdentifier'
      ..reachability = 'public'
      ..reachabilitySource = 'autonat'
      ..announceable = true)
    ..connected.addAll([
      for (var i = 0; i < 2; i++)
        pb.ConnectedPeer()
          ..peerId = '12D3KooWServerPeerNumber${i}xxxxxxxxxxxxxxxxxxxx'
          ..addr = '/ip4/198.18.0.${10 + i}/tcp/8000'
          ..kind = pbenum.PeerConnKind.PEER_CONN_KIND_DIRECT
          ..direction = 'outbound'
          ..protocols.add('/ipfs/kad/1.0.0')
          ..dhtRole = pbenum.DhtRole.DHT_ROLE_SERVER
          ..agentVersion = 'kwaainet/0.5.4',
      for (var i = 0; i < clients; i++)
        pb.ConnectedPeer()
          ..peerId = '12D3KooWClientPeerNumber${i}xxxxxxxxxxxxxxxxxxxx'
          ..addr = '/p2p/12D3KooWClientPeerNumber${i}xxxxxxxxxxxxxxxxxxxx'
          ..kind = pbenum.PeerConnKind.PEER_CONN_KIND_RELAY
          ..direction = 'inbound'
          ..protocols.add('/ipfs/id/1.0.0')
          ..dhtRole = pbenum.DhtRole.DHT_ROLE_CLIENT
          ..agentVersion = 'p2pd/0.1',
    ]);
}

Widget _host(pb.NetworkUpdate update) {
  return ProviderScope(
    overrides: [peersProvider.overrideWith((ref) => Stream.value(update))],
    child: MaterialApp(
      theme: buildKwaaiTheme(ThemeVariantKey.kwaai, Brightness.dark),
      home: Scaffold(
        body: SizedBox(width: 1100, height: 700, child: const PeersTab()),
      ),
    ),
  );
}

Finder _summaryWith(String fragment) => find.byWidgetPredicate(
  (w) => w is Text && (w.data ?? '').contains(fragment),
);

/// The client filter hides query-only peers by default. These pin the two ways
/// that has previously gone wrong: the count contradicting what is on screen,
/// and the control moving as it is used.
void main() {
  testWidgets('hides client peers by default and says how many', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_update(clients: 2)));
    await tester.pumpAndSettle();

    expect(find.text('Show DHT clients'), findsOneWidget);
    expect(_summaryWith('2 hidden'), findsOneWidget);
  });

  /// Nothing is hidden once they are shown, so claiming otherwise contradicts
  /// the table directly below it.
  testWidgets('drops the hidden count once clients are shown', (tester) async {
    await tester.pumpWidget(_host(_update(clients: 2)));
    await tester.pumpAndSettle();
    expect(_summaryWith('hidden'), findsOneWidget);

    await tester.tap(find.text('Show DHT clients'));
    await tester.pumpAndSettle();

    expect(_summaryWith('hidden'), findsNothing);
  });

  /// The toggle must survive being used — it was previously keyed off the
  /// hidden count, so checking it made the control disappear.
  testWidgets('keeps the toggle visible after it is checked', (tester) async {
    await tester.pumpWidget(_host(_update(clients: 2)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Show DHT clients'));
    await tester.pumpAndSettle();

    expect(find.text('Show DHT clients'), findsOneWidget);
  });

  /// The label carried the count, so its width changed between states and the
  /// checkbox moved under the cursor. Its position must not depend on state.
  testWidgets('does not move when toggled', (tester) async {
    await tester.pumpWidget(_host(_update(clients: 2)));
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(find.text('Show DHT clients'));

    await tester.tap(find.text('Show DHT clients'));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('Show DHT clients')), before);
  });

  /// Both count summaries — the "This node" header and the PEERS caption —
  /// sit against the same right edge. The header's lived inside a Wrap and so
  /// flowed to wherever the preceding chips ended, which read as centred.
  testWidgets('both summaries share a right edge', (tester) async {
    await tester.pumpWidget(_host(_update(clients: 2)));
    await tester.pumpAndSettle();

    final rects = _summaryWith('in routing table')
        .evaluate()
        .map((e) => tester.getRect(find.byWidget(e.widget)))
        .toList();

    expect(rects.length, 2, reason: 'header summary and caption summary');
    expect(rects[0].right, closeTo(rects[1].right, 0.5));
  });

  /// The toggle stays put with no client peers; only the hidden count goes.
  testWidgets('hides nothing when no client peers exist', (tester) async {
    await tester.pumpWidget(_host(_update(clients: 0)));
    await tester.pumpAndSettle();

    expect(find.text('Show DHT clients'), findsOneWidget);
    expect(_summaryWith('hidden'), findsNothing);
  });
}
