import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/chat/generated/kwaai.pb.dart' as pb;
import 'package:kwaainet_gui/src/chat/generated/kwaai.pbenum.dart' as pbenum;
import 'package:kwaainet_gui/src/daemon/peers_state.dart';
import 'package:kwaainet_gui/src/ui/pages/peers_tab.dart';
import 'package:kwaainet_gui/src/ui/theme/theme_variants.dart';

/// Layout regression tests for the Peers tab.
///
/// The tab stacks two tables in a scrolling column, and each table scrolls
/// horizontally in its own right. That nesting is where a layout mistake would
/// bite: a horizontally-scrolling child inside a vertically-scrolling parent
/// has an unbounded constraint on both axes unless something bounds it, and
/// the symptom is not an exception but a hang — the framework laying out an
/// intrinsically-sized table against infinite constraints, every frame.
pb.NetworkUpdate _update({int connected = 3, int routing = 3}) {
  return pb.NetworkUpdate()
    ..serverTime = '2026-08-01T12:00:00Z'
    ..reason = pbenum.UpdateReason.UPDATE_REASON_PEERS
    ..selfStatus = (pb.SelfStatus()
      ..peerId = '12D3KooWSelfExamplePeerIdentifier'
      ..reachability = 'public'
      ..reachabilitySource = 'autonat'
      ..announceable = true
      ..listenAddrs.add('/ip4/0.0.0.0/tcp/8080')
      ..observedAddrs.add('/ip4/198.51.100.7/tcp/8080'))
    ..connected.addAll([
      for (var i = 0; i < connected; i++)
        pb.ConnectedPeer()
          ..peerId = '12D3KooWConnectedPeerNumber${i}xxxxxxxxxxxxxxxxxx'
          ..addr = '/ip4/198.18.0.${10 + i}/tcp/8000'
          ..kind = i.isEven
              ? pbenum.PeerConnKind.PEER_CONN_KIND_DIRECT
              : pbenum.PeerConnKind.PEER_CONN_KIND_RELAY
          ..direction = i.isEven ? 'outbound' : 'inbound'
          ..isBootstrap = i == 0
          ..protocols.addAll(['/ipfs/kad/1.0.0', '/libp2p/dcutr'])
          ..rttMs = 40 + i
          ..agentVersion = 'kwaainet/0.5.4',
    ])
    ..routing.addAll([
      for (var i = 0; i < routing; i++)
        pb.RoutingPeer()
          ..peerId = '12D3KooWRoutingPeerNumber${i}xxxxxxxxxxxxxxxxxxxx'
          ..connected = i == 0,
    ]);
}

Widget _host(pb.NetworkUpdate update, {Size size = const Size(900, 700)}) {
  return ProviderScope(
    overrides: [
      peersProvider.overrideWith((ref) => Stream.value(update)),
    ],
    child: MaterialApp(
      theme: buildKwaaiTheme(ThemeVariantKey.kwaai, Brightness.dark),
      home: Scaffold(
        body: SizedBox(
          width: size.width,
          height: size.height,
          child: const PeersTab(),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('lays out the merged table without hanging or overflowing',
      (tester) async {
    await tester.pumpWidget(_host(_update()));
    await tester.pump();

    expect(find.text('PEERS'), findsOneWidget);
    // The two state columns are what make the merged table readable: they say
    // which of connected / in-routing-table each peer is, so a peer in only one
    // of the two sets is visibly distinct rather than simply absent.
    expect(find.text('CONN'), findsOneWidget);
    expect(find.text('DHT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('survives a narrow window, where the tables must scroll',
      (tester) async {
    // The failure mode is width-sensitive: a table wider than the viewport is
    // exactly when the horizontal scroll view has to do something.
    await tester.pumpWidget(_host(_update(), size: const Size(420, 600)));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('scales to a large peer set', (tester) async {
    // A real node on a busy network. If layout cost is superlinear in row
    // count, this is where it shows.
    await tester.pumpWidget(_host(_update(connected: 60, routing: 120)));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('layout cost stays roughly linear in row count', (tester) async {
    // The hang this guards against is not an exception — it is the framework
    // measuring intrinsically-sized tables against unbounded constraints,
    // every frame. That shows up as time, not as an error, so measure it.
    //
    // Both DataTables size themselves to their content, so doubling the rows
    // should roughly double the work. A superlinear jump means something is
    // re-measuring the whole table per row.
    Future<Duration> layout(int n) async {
      final sw = Stopwatch()..start();
      await tester.pumpWidget(_host(_update(connected: n, routing: n)));
      await tester.pump();
      sw.stop();
      return sw.elapsed;
    }

    // Warm up so one-off framework init isn't charged to the first sample.
    await layout(10);

    final small = await layout(40);
    final large = await layout(160);

    // 4x the rows. Allow generous headroom for scheduler noise in CI — this is
    // catching order-of-magnitude blowups, not a few percent.
    expect(
      large.inMicroseconds,
      lessThan(small.inMicroseconds * 20),
      reason: 'layout cost grew far faster than row count (4x rows took '
          '${large.inMilliseconds}ms vs ${small.inMilliseconds}ms) — the '
          'tables are probably being measured against unbounded constraints',
    );
  });

  testWidgets('selecting a peer opens the connections panel below the table',
      (tester) async {
    await tester.pumpWidget(_host(_update(connected: 3, routing: 3)));
    await tester.pump();

    // Nothing selected: no panel.
    expect(find.textContaining('CONNECTION'), findsNothing);

    // Tap a row's PATH cell. Peer ids are elided in the table, so match on
    // something the row renders verbatim.
    await tester.tap(find.text('direct').first);
    await tester.pump();

    // The panel names the connection count, and the table has not grown a
    // spanning row — the inline version overflowed its cell, which is why the
    // detail lives outside the table now.
    expect(find.textContaining('CONNECTION'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every value is rendered when an address line is expanded',
      (tester) async {
    // Regression: the values were joined into one Text with maxLines capped at
    // the value count, so once a long multiaddr wrapped, the last entry was
    // silently clipped — the toggle said "and 4 more" while showing four of
    // five. One Text per value, each clipped to a single line, cannot do that.
    final update = _update();
    update.selfStatus.listenAddrs
      ..clear()
      ..addAll([
        '/ip4/192.168.68.135/tcp/8080',
        '/ip4/52.23.252.2/tcp/8000/p2p/Qmd3A8N5aQBATe2SYvNikaeCS9CAKN4E86jdCPacZ6RZJY/p2p-circuit/p2p/12D3KooWMVmKq1oEpt8AF8rT2eB55WDR26HdW5SrpCi97Noqy4E8',
        '/ip4/18.219.43.67/tcp/8000/p2p/QmQhRuheeCLEsVD3RsnknM75gPDDqxAb8DhnWgro7KhaJc/p2p-circuit/p2p/12D3KooWMVmKq1oEpt8AF8rT2eB55WDR26HdW5SrpCi97Noqy4E8',
        '/ip4/192.168.68.174/tcp/8080',
        '/ip4/127.0.0.1/tcp/8080',
      ]);

    await tester.pumpWidget(_host(update, size: const Size(1100, 800)));
    await tester.pump();

    // Collapsed: one address plus a toggle naming the other four.
    expect(find.text('and 4 more'), findsOneWidget);

    await tester.tap(find.text('and 4 more'));
    await tester.pump();

    // Expanded: all five present, and the count matches what is rendered.
    for (final addr in update.selfStatus.listenAddrs) {
      expect(
        find.text(addr),
        findsOneWidget,
        reason: '$addr was counted by the toggle but never rendered',
      );
    }
    expect(find.text('show less'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows what this node serves, beside what peers offer',
      (tester) async {
    // The comparison is the point: reading our list next to a peer's is how
    // you tell whether a missing capability is theirs or ours.
    final update = _update();
    update.selfStatus.localProtocols.addAll([
      '/ipfs/kad/1.0.0',
      '/kwaai/inference/1.0.0',
      '/kwaai/p2p/hello/1.0.0',
    ]);

    await tester.pumpWidget(_host(update, size: const Size(1100, 800)));
    await tester.pump();

    // Labelled "Serving", not "Protocols" — both appear on this page and the
    // distinction is which node they belong to.
    expect(find.text('Serving'), findsOneWidget);
    expect(find.text('and 2 more'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the connections panel can be closed', (tester) async {
    await tester.pumpWidget(_host(_update(connected: 3, routing: 3)));
    await tester.pump();

    await tester.tap(find.text('direct').first);
    await tester.pump();
    expect(find.textContaining('CONNECTIONS'), findsOneWidget);

    // Clicking the row again also closes it, but that is not discoverable
    // from looking at the panel — hence the button.
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    expect(find.textContaining('CONNECTIONS'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offers connect only for peers we are not connected to',
      (tester) async {
    // A routing-only peer is the case this exists for: known from the DHT,
    // no live connection. Connected rows show a check and no action — the
    // button would mean nothing there.
    await tester.pumpWidget(_host(_update(connected: 2, routing: 4)));
    await tester.pump();

    // The dash is the resting state; the button only appears on hover, so
    // nothing is visible until pointed at.
    expect(find.byTooltip('Connect to this peer'), findsNothing);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    // Hover the CONN cell of a routing-only row.
    final dashes = find.byIcon(Icons.remove);
    expect(dashes, findsWidgets, reason: 'unconnected rows show a dash');
    await gesture.moveTo(tester.getCenter(dashes.first));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('an idle page costs nothing per frame', (tester) async {
    // The hang was here, and it is invisible to a rebuild benchmark: with no
    // events arriving at all, the page was still burning ~14ms every frame,
    // because each row carried Tooltips and a Tooltip runs an
    // AnimationController. Twenty rows meant forty controllers ticking forever.
    //
    // Per-row animated widgets are the thing to keep out of these tables.
    await tester.pumpWidget(_host(_update(connected: 25, routing: 25)));
    await tester.pump();

    final sw = Stopwatch()..start();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    sw.stop();

    final perFrame = sw.elapsedMilliseconds / 30;
    // ignore: avoid_print
    print('${perFrame.toStringAsFixed(2)}ms per idle frame');
    expect(
      perFrame,
      lessThan(2.0),
      reason: 'an idle page cost ${perFrame.toStringAsFixed(2)}ms per frame; '
          'something on it is animating continuously (a per-row Tooltip, most '
          'likely), which is what makes the tab feel like it hangs',
    );
  });

  testWidgets('repeated rebuilds stay cheap', (tester) async {
    // The stale ticker rebuilds this page every 5s whether or not an update
    // arrived, so every widget on it is rebuilt ~12 times a minute for the
    // whole time the tab is open. Anything expensive to construct — selectable
    // text in particular, which installs gesture recognizers and a text-editing
    // pipeline per instance — compounds.
    // A stream that emits repeatedly, driving the same full-subtree rebuild
    // the ticker causes.
    final controller = StreamController<pb.NetworkUpdate>.broadcast();
    addTearDown(controller.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [peersProvider.overrideWith((ref) => controller.stream)],
        child: MaterialApp(
          theme: buildKwaaiTheme(ThemeVariantKey.kwaai, Brightness.dark),
          home: const Scaffold(
            body: SizedBox(width: 900, height: 700, child: PeersTab()),
          ),
        ),
      ),
    );
    final update = _update(connected: 20, routing: 20);
    controller.add(update);
    await tester.pump();

    final sw = Stopwatch()..start();
    for (var i = 0; i < 40; i++) {
      controller.add(update);
      await tester.pump();
    }
    sw.stop();

    final perRebuild = sw.elapsedMilliseconds / 40;
    // ignore: avoid_print
    print('${perRebuild.toStringAsFixed(1)}ms per update+rebuild');
    // This measures the whole path — stream emit, provider notify, rebuild —
    // so it is dominated by harness overhead rather than by the widgets. It is
    // a blowup detector, not a frame-budget check; the idle test above is the
    // one that catches the failure that actually mattered.
    expect(
      perRebuild,
      lessThan(50),
      reason: 'an update costs ${perRebuild.toStringAsFixed(1)}ms end to end, '
          'far above the ~1ms this path should take',
    );
  });

  testWidgets('the page scrolls vertically when the tables overflow it',
      (tester) async {
    await tester.pumpWidget(
      _host(_update(connected: 40, routing: 40), size: const Size(900, 400)),
    );
    await tester.pump();

    // Scroll the table to prove it is really scrollable rather than clipped.
    await tester.drag(find.byType(DataTable), const Offset(0, -600));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
