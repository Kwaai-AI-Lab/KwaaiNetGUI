import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/chat/generated/kwaai.pb.dart' as pb;
import 'package:kwaainet_gui/src/chat/generated/kwaai.pbenum.dart' as pbenum;
import 'package:kwaainet_gui/src/daemon/peers_state.dart';
import 'package:kwaainet_gui/src/ui/pages/peers_tab.dart';
import 'package:kwaainet_gui/src/ui/theme/theme_variants.dart';

/// The DHT-entry dialog: the way from "this peer is in my routing table" to
/// why the entry looks the way it does.
///
/// The k-bucket facts it shows have no other surface — the daemon reads them
/// from the in-memory buckets and nothing else renders them — so a regression
/// here is silent.
const _openTip = "Show this peer's DHT routing entry";
const _connectedId = '12D3KooWConnectedExamplePeerIdentifierBBBB';

/// Attached to the *connected* peer by default: routing-only peers are hidden
/// behind the "routing table only" filter, and a connected peer with an entry
/// is the common case anyway.
pb.RoutingPeer _entry({
  String peerId = _connectedId,
  bool connected = true,
  pbenum.KadStatus kadStatus = pbenum.KadStatus.KAD_STATUS_CONNECTED,
  int bucket = 251,
  int entries = 4,
  int capacity = 20,
  bool pending = false,
  List<String> addrs = const ['/ip4/198.18.0.32/tcp/8080'],
  int? lastContactSecs,
}) {
  final r = pb.RoutingPeer()
    ..peerId = peerId
    ..connected = connected
    ..kadStatus = kadStatus
    ..bucket = bucket
    ..bucketEntries = entries
    ..bucketCapacity = capacity
    ..bucketPending = pending
    ..distance = 'a3'.padRight(64, '0')
    ..addrs.addAll(addrs);
  if (lastContactSecs != null) r.lastContactSecs = lastContactSecs;
  return r;
}

pb.NetworkUpdate _update(List<pb.RoutingPeer> routing) {
  return pb.NetworkUpdate()
    ..serverTime = '2026-08-01T12:00:00Z'
    ..reason = pbenum.UpdateReason.UPDATE_REASON_PEERS
    ..selfStatus = (pb.SelfStatus()
      ..peerId = '12D3KooWSelfExamplePeerIdentifier'
      ..reachability = 'public'
      ..announceable = true)
    ..connected.add(
      pb.ConnectedPeer()
        ..peerId = _connectedId
        ..addr = '/ip4/198.18.0.10/tcp/8000'
        ..kind = pbenum.PeerConnKind.PEER_CONN_KIND_DIRECT
        ..direction = 'outbound'
        ..dhtRole = pbenum.DhtRole.DHT_ROLE_SERVER,
    )
    ..routing.addAll(routing);
}

Widget _host(pb.NetworkUpdate update) {
  return ProviderScope(
    overrides: [peersProvider.overrideWith((ref) => Stream.value(update))],
    child: MaterialApp(
      theme: buildKwaaiTheme(ThemeVariantKey.kwaai, Brightness.dark),
      home: const Scaffold(
        body: SizedBox(width: 900, height: 700, child: PeersTab()),
      ),
    ),
  );
}

void main() {
  group('formatLastContact', () {
    /// The one that is not a number. A routing entry exists the moment a
    /// configured address is seeded into kad, so "never dialled" is an
    /// ordinary state — and rendering it as "0s ago" would assert the
    /// opposite of what is true.
    test('absent is never, not zero', () {
      expect(formatLastContact(null), 'Never connected');
      expect(formatLastContact(0), '0s ago');
    });

    // The daemon does not resend the value as it grows.
    test('ages by the time since the snapshot', () {
      expect(
        formatLastContact(120, sinceSnapshot: const Duration(minutes: 3)),
        '5m ago',
      );
      expect(
        formatLastContact(null, sinceSnapshot: const Duration(minutes: 3)),
        'Never connected',
      );
    });

    test('coarsens with age', () {
      expect(formatLastContact(59), '59s ago');
      expect(formatLastContact(60), '1m ago');
      expect(formatLastContact(3599), '59m ago');
      expect(formatLastContact(3600), '1h ago');
      expect(formatLastContact(86400), '1d ago');
    });
  });

  group('kadStatusSummary', () {
    /// Kad's verdict and the swarm's connection set are two different claims,
    /// and they disagree routinely: kad marks an entry disconnected on close
    /// but keeps it, and lags the swarm by an event-loop turn either way. The
    /// summary has to name which case it is rather than leave two ticks
    /// looking like a contradiction.
    test('names each of the four combinations distinctly', () {
      final seen = <String>{};
      for (final status in [
        pbenum.KadStatus.KAD_STATUS_CONNECTED,
        pbenum.KadStatus.KAD_STATUS_DISCONNECTED,
      ]) {
        for (final connected in [true, false]) {
          seen.add(kadStatusSummary(kadStatus: status, connected: connected));
        }
      }
      expect(seen, hasLength(4));
    });

    /// A daemon predating the field sends the zero value. That is not a third
    /// real state — kad has only two — so it must not be reported as one.
    test('an unreported status blames the daemon, not the peer', () {
      final s = kadStatusSummary(
        kadStatus: pbenum.KadStatus.KAD_STATUS_UNSPECIFIED,
        connected: true,
      );
      expect(s, contains('daemon'));
    });
  });

  testWidgets('opens the entry from the DHT mark', (tester) async {
    await tester.pumpWidget(_host(_update([_entry(lastContactSecs: 120)])));
    await tester.pump();

    expect(find.text('DHT routing entry'), findsNothing);
    await tester.tap(find.byTooltip(_openTip));
    await tester.pumpAndSettle();

    expect(find.text('DHT routing entry'), findsOneWidget);
    expect(find.textContaining('251'), findsOneWidget);
    expect(find.text('Last connected'), findsOneWidget);
    expect(find.text('2m ago'), findsOneWidget);
    expect(find.textContaining('/ip4/198.18.0.32/tcp/8080'), findsOneWidget);
  });

  /// The affordance. Nothing else on the row says the mark is clickable, so if
  /// the magnifier stops appearing the dialog becomes undiscoverable rather
  /// than broken — which no other test would catch.
  testWidgets('the mark becomes a magnifier under the pointer', (tester) async {
    await tester.pumpWidget(_host(_update([_entry()])));
    await tester.pump();

    final mark = find.byTooltip(_openTip);
    expect(
      find.descendant(of: mark, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );

    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: Offset.zero);
    addTearDown(pointer.removePointer);
    await pointer.moveTo(tester.getCenter(mark));
    await tester.pump();

    expect(
      find.descendant(of: mark, matching: find.byIcon(Icons.search)),
      findsOneWidget,
    );
  });

  /// A peer with no entry has nothing to open. Offering the affordance anyway
  /// would lead to an empty dialog, so the dash stays inert.
  testWidgets('a peer with no entry is not clickable', (tester) async {
    await tester.pumpWidget(_host(_update(const [])));
    await tester.pump();

    // The connected-only peer's DHT cell.
    await tester.tap(find.byIcon(Icons.remove).first);
    await tester.pumpAndSettle();
    expect(find.text('DHT routing entry'), findsNothing);
  });

  /// The degenerate entry: kad holds the peer but no address for it. It looks
  /// identical to a healthy one on the row, and the dialog is where that has
  /// to become visible.
  testWidgets('says so when the entry carries no address', (tester) async {
    await tester.pumpWidget(_host(_update([_entry(addrs: const [])])));
    await tester.pump();
    await tester.tap(find.byTooltip(_openTip));
    await tester.pumpAndSettle();

    expect(find.textContaining('No address'), findsOneWidget);
  });

  /// A released daemon predating these fields sends none of them, and proto3
  /// erases the zeros. Printing "bucket 0 — 0 of 0" would be a confident claim
  /// about a peer built entirely out of absent data.
  testWidgets('does not invent bucket detail an old daemon omitted', (
    tester,
  ) async {
    final bare = pb.RoutingPeer()
      ..peerId = _connectedId
      ..connected = true
      ..addrs.add('/ip4/198.18.0.32/tcp/8080');
    await tester.pumpWidget(_host(_update([bare])));
    await tester.pump();
    await tester.tap(find.byTooltip(_openTip));
    await tester.pumpAndSettle();

    // Both the kad verdict and the bucket detail are absent, and both say so.
    expect(find.textContaining('Not reported'), findsNWidgets(2));
    expect(find.textContaining('of 0'), findsNothing);
    // Still useful: the addresses and the peer id do not depend on the new
    // fields, so the dialog is worth opening against an old daemon.
    expect(find.textContaining('/ip4/198.18.0.32/tcp/8080'), findsOneWidget);
  });

  /// Whether the bucket is full is the fact that decides if a newly-discovered
  /// peer can be inserted at all.
  testWidgets('marks a full bucket', (tester) async {
    await tester.pumpWidget(
      _host(_update([_entry(entries: 20, capacity: 20, pending: true)])),
    );
    await tester.pump();
    await tester.tap(find.byTooltip(_openTip));
    await tester.pumpAndSettle();

    expect(find.textContaining('(full)'), findsOneWidget);
    expect(find.textContaining('replacement pending'), findsOneWidget);
  });
}
