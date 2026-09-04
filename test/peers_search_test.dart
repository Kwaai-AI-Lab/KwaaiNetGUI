import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/chat/generated/kwaai.pb.dart' as pb;
import 'package:kwaainet_gui/src/chat/generated/kwaai.pbenum.dart' as pbenum;
import 'package:kwaainet_gui/src/daemon/peers_state.dart';
import 'package:kwaainet_gui/src/ui/pages/peers_tab.dart';
import 'package:kwaainet_gui/src/ui/theme/theme_variants.dart';

pb.ConnectedPeer _conn(String id, {String addr = '', String version = ''}) =>
    pb.ConnectedPeer()
      ..peerId = id
      ..addr = addr
      ..agentVersion = version
      ..kind = pbenum.PeerConnKind.PEER_CONN_KIND_DIRECT
      ..direction = 'outbound'
      ..dhtRole = pbenum.DhtRole.DHT_ROLE_SERVER;

/// Two connected peers differing in every searchable field.
pb.NetworkUpdate _update() => pb.NetworkUpdate()
  ..serverTime = '2026-08-01T12:00:00Z'
  ..reason = pbenum.UpdateReason.UPDATE_REASON_PEERS
  ..selfStatus = (pb.SelfStatus()
    ..peerId = '12D3KooWSelfExamplePeerIdentifier'
    ..reachability = 'public'
    ..announceable = true)
  ..connected.addAll([
    _conn(
      '12D3KooWPeerOnexxxxxxxxxxxxxxAAONE01',
      addr: '/ip4/198.18.0.10/tcp/8000',
      version: 'kwaainet/0.6.8',
    ),
    _conn(
      '12D3KooWPeerTwoxxxxxxxxxxxxxxBBTWO02',
      addr: '/ip4/192.168.1.10/tcp/8000',
      version: 'kwaainet/0.6.7',
    ),
  ]);

Widget _host(pb.NetworkUpdate update) => ProviderScope(
  overrides: [peersProvider.overrideWith((ref) => Stream.value(update))],
  child: MaterialApp(
    theme: buildKwaaiTheme(ThemeVariantKey.kwaai, Brightness.dark),
    home: const Scaffold(
      body: SizedBox(width: 1300, height: 700, child: PeersTab()),
    ),
  ),
);

Finder _textWith(String fragment) => find.byWidgetPredicate(
  (w) => w is Text && (w.data ?? '').contains(fragment),
);

final _field = find.byKey(const Key('peer-search'));

/// Pumps on a surface wide enough for the whole caption bar: on the default
/// 800px one the filter slot scrolls, and the field sits out of view.
Future<void> _pump(WidgetTester tester, Widget host) async {
  tester.view.physicalSize = const Size(1400, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host);
}

Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(_field, query);
  await tester.pumpAndSettle();
}

pb.RoutingPeer _routing(String id, List<String> addrs) => pb.RoutingPeer()
  ..peerId = id
  ..addrs.addAll(addrs);

/// The row for [peerId] as the table itself would build it.
///
/// Built through [mergePeerRows] rather than by calling the `PeerRow`
/// constructor: how a routing entry is carried differs between the branches
/// this lands beside, while the merge's own signature does not.
PeerRow _row(
  String peerId, {
  List<pb.ConnectedPeer> connected = const [],
  List<pb.RoutingPeer> routing = const [],
}) => mergePeerRows(connected, routing).firstWhere((r) => r.peerId == peerId);

void main() {
  group('PeerRow.matches', () {
    final row = _row(
      '12D3KooWPeerOnexxxxxxxxxxxxxxAAONE01',
      connected: [
        _conn(
          '12D3KooWPeerOnexxxxxxxxxxxxxxAAONE01',
          addr: '/ip4/198.18.0.10/tcp/8000',
          version: 'kwaainet/0.6.8',
        ),
      ],
    );

    test('an empty query matches everything', () {
      expect(row.matches(''), isTrue);
    });

    test('matches on id, version and address', () {
      expect(row.matches('aaone01'), isTrue);
      expect(row.matches('0.6.8'), isTrue);
      expect(row.matches('198.18.0.10'), isTrue);
      expect(row.matches('192.168'), isFalse);
    });

    test('matches the part of the id the row abbreviates away', () {
      // The cell shows `12D3KooW…AAONE01`; this lands in the elided middle.
      expect(row.matches('peeronexxx'), isTrue);
    });

    test('matches the relay a connection goes through', () {
      final relayed = _row(
        '12D3KooWRelayedPeerxxxxxxxxxDDREL04',
        connected: [
          _conn('12D3KooWRelayedPeerxxxxxxxxxDDREL04')
            ..via = '12D3KooWRelayItselfxxxxxxxxxEERLY05',
        ],
      );
      // The ADDRESS cell shows `via` in place of the address for a relayed
      // connection, so it has to be searchable on what is on screen.
      expect(relayed.matches('eerly05'), isTrue);
    });

    test('a routing-only peer is searchable by its routing addresses', () {
      final routingOnly = _row(
        '12D3KooWRoutingOnlyxxxxxxxxxCCRO03',
        routing: [
          _routing('12D3KooWRoutingOnlyxxxxxxxxxCCRO03', const [
            '/ip4/198.18.0.40/tcp/8000',
          ]),
        ],
      );
      expect(routingOnly.matches('198.18.0.40'), isTrue);
      expect(routingOnly.matches('198.18.0.99'), isFalse);
    });
  });

  group('search field', () {
    testWidgets('shows every peer until something is typed', (tester) async {
      await _pump(tester, _host(_update()));
      await tester.pumpAndSettle();

      expect(find.text('Search peers'), findsOneWidget);
      expect(_textWith('AAONE01'), findsOneWidget);
      expect(_textWith('BBTWO02'), findsOneWidget);
      expect(_textWith('hidden'), findsNothing);
    });

    testWidgets('narrows the table and counts what it withheld', (
      tester,
    ) async {
      await _pump(tester, _host(_update()));
      await tester.pumpAndSettle();

      await _search(tester, '0.6.7');

      expect(_textWith('BBTWO02'), findsOneWidget);
      expect(_textWith('AAONE01'), findsNothing);
      // Same accounting as the other filters — a hidden row is never silent.
      expect(_textWith('1 hidden'), findsOneWidget);
    });

    testWidgets('is case-insensitive and ignores surrounding space', (
      tester,
    ) async {
      await _pump(tester, _host(_update()));
      await tester.pumpAndSettle();

      await _search(tester, '  BBTWO02  ');

      expect(_textWith('BBTWO02'), findsOneWidget);
      expect(_textWith('AAONE01'), findsNothing);
    });

    testWidgets('clearing restores every peer', (tester) async {
      await _pump(tester, _host(_update()));
      await tester.pumpAndSettle();

      await _search(tester, '0.6.7');
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      expect(_textWith('AAONE01'), findsOneWidget);
      expect(_textWith('BBTWO02'), findsOneWidget);
      expect(_textWith('hidden'), findsNothing);
    });

    testWidgets('survives a snapshot arriving while a query is typed', (
      tester,
    ) async {
      // The page rebuilds every few seconds from the daemon. The controller
      // lives in the field's own State for exactly this reason, and a single
      // Stream.value host would never exercise it.
      final updates = StreamController<pb.NetworkUpdate>();
      addTearDown(updates.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [peersProvider.overrideWith((ref) => updates.stream)],
          child: MaterialApp(
            theme: buildKwaaiTheme(ThemeVariantKey.kwaai, Brightness.dark),
            home: const Scaffold(
              body: SizedBox(width: 1300, height: 700, child: PeersTab()),
            ),
          ),
        ),
      );
      updates.add(_update());
      await tester.pumpAndSettle();

      await _search(tester, '0.6.7');
      updates.add(_update());
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(_field).controller?.text, '0.6.7');
      expect(_textWith('BBTWO02'), findsOneWidget);
      expect(_textWith('AAONE01'), findsNothing);
    });

    testWidgets('whitespace narrows nothing but is still clearable', (
      tester,
    ) async {
      await _pump(tester, _host(_update()));
      await tester.pumpAndSettle();

      await _search(tester, '   ');

      expect(_textWith('AAONE01'), findsOneWidget);
      expect(_textWith('BBTWO02'), findsOneWidget);
      // The button follows the text, not the filtering — otherwise a field
      // that looks full has no way to empty it but backspacing.
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('a row both filters hide is counted once', (tester) async {
      // node-c is routing-only, so "Show unconnected" hides it as well as the
      // query does. The hidden count is a difference, not a sum.
      final update = _update()
        ..routing.add(
          _routing('12D3KooWRoutingOnlyxxxxxxxxxCCRO03', const [
            '/ip4/198.18.0.40/tcp/8000',
          ]),
        );
      await _pump(tester, _host(update));
      await tester.pumpAndSettle();

      await _search(tester, '0.6.7');

      expect(_textWith('BBTWO02'), findsOneWidget);
      expect(_textWith('2 hidden'), findsOneWidget);
    });

    testWidgets('hides the detail panel of a peer the query filters out', (
      tester,
    ) async {
      await _pump(tester, _host(_update()));
      await tester.pumpAndSettle();

      await tester.tap(_textWith('AAONE01'));
      await tester.pumpAndSettle();
      expect(_textWith('CONNECTIONS'), findsOneWidget);

      await _search(tester, '0.6.7');
      expect(_textWith('CONNECTIONS'), findsNothing);

      // The selection itself survives — clearing brings the panel back.
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();
      expect(_textWith('CONNECTIONS'), findsOneWidget);
    });

    testWidgets('a query matching nothing says so rather than looking empty', (
      tester,
    ) async {
      await _pump(tester, _host(_update()));
      await tester.pumpAndSettle();

      await _search(tester, 'no-such-peer');

      expect(find.text('No peers match these filters.'), findsOneWidget);
      expect(_textWith('2 hidden'), findsOneWidget);
    });
  });
}
