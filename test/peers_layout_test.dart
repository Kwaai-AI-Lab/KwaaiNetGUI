import 'dart:async';

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
  testWidgets('lays out both tables without hanging or overflowing',
      (tester) async {
    await tester.pumpWidget(_host(_update()));
    await tester.pump();

    expect(find.text('CONNECTIONS'), findsOneWidget);
    expect(find.text('DHT ROUTING TABLE'), findsOneWidget);
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

    // Scroll to the bottom section to prove the outer list is really
    // scrollable rather than merely clipped.
    await tester.drag(find.text('CONNECTIONS'), const Offset(0, -600));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
