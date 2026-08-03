import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/chat/generated/kwaai.pb.dart' as pb;
import 'package:kwaainet_gui/src/chat/inference_events_state.dart';
import 'package:kwaainet_gui/src/ui/theme/theme_variants.dart';
import 'package:kwaainet_gui/src/ui/widgets/inference_panel.dart';

Widget _host(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    theme: buildKwaaiTheme(ThemeVariantKey.kwaai, Brightness.dark),
    home: const Scaffold(
      // Bounded height: the panel's log is an Expanded ListView.
      body: SizedBox(height: 600, child: InferencePanel()),
    ),
  ),
);

pb.InferenceEvent _event(pb.InferencePhase phase) =>
    pb.InferenceEvent()
      ..phase = phase
      ..elapsedMs = Int64(120);

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  testWidgets('prompts to send a message when idle', (tester) async {
    await tester.pumpWidget(_host(container));
    expect(find.textContaining('Send a message'), findsOneWidget);
  });

  testWidgets('renders the chain and the log', (tester) async {
    final notifier = container.read(inferenceEventsProvider.notifier);
    notifier.startRun();
    await tester.pumpWidget(_host(container));

    final pinned = pb.InferenceEvent()
      ..phase = pb.InferencePhase.INFERENCE_PHASE_CHAIN_PINNED
      ..elapsedMs = Int64(40)
      ..totalBlocks = 16
      ..hops.addAll([
        pb.InferenceHop()
          ..peerId = '12D3KooWaaaaaaaaaaaaaaaaaaaaaaaa'
          ..peerName = 'me'
          ..blockStart = 0
          ..blockEnd = 8
          ..isSelf = true,
        pb.InferenceHop()
          ..peerId = '12D3KooWbbbbbbbbbbbbbbbbbbbbbbbb'
          ..peerName = 'node-f'
          ..blockStart = 8
          ..blockEnd = 16,
      ]);

    final stream = Stream<pb.InferenceEvent>.fromIterable([
      _event(pb.InferencePhase.INFERENCE_PHASE_RESOLVED),
      pinned,
    ]);
    notifier.ingest(stream);
    await tester.pump(const Duration(milliseconds: 150));

    // Chain rows: block ranges and the self-hop's friendlier label.
    expect(find.text('CHAIN · 2 hops'), findsOneWidget);
    expect(find.text('0–8'), findsOneWidget);
    expect(find.text('8–16'), findsOneWidget);
    expect(find.text('you (local)'), findsOneWidget);
    expect(find.text('node-f'), findsOneWidget);

    // Log rows.
    expect(find.textContaining('pinned'), findsOneWidget);
  });

  /// The collapse itself is covered in inference_log_rows_test; this is the
  /// wiring — that the panel renders rows rather than raw events.
  testWidgets('a dial burst and a completed hop are one row each', (
    tester,
  ) async {
    final notifier = container.read(inferenceEventsProvider.notifier);
    notifier.startRun();
    await tester.pumpWidget(_host(container));

    pb.InferenceEvent dial(String name) => pb.InferenceEvent()
      ..phase = pb.InferencePhase.INFERENCE_PHASE_PEER_DIAL
      ..elapsedMs = Int64(3000)
      ..peerName = name
      ..ok = true;

    notifier.ingest(
      Stream<pb.InferenceEvent>.fromIterable([
        dial('a'),
        dial('b'),
        dial('c'),
        pb.InferenceEvent()
          ..phase = pb.InferencePhase.INFERENCE_PHASE_HOP_START
          ..elapsedMs = Int64(4700)
          ..peerName = 'metro-linux'
          ..blockStart = 0
          ..blockEnd = 32,
        pb.InferenceEvent()
          ..phase = pb.InferencePhase.INFERENCE_PHASE_HOP_OK
          ..elapsedMs = Int64(6800)
          ..peerName = 'metro-linux'
          ..blockStart = 0
          ..blockEnd = 32
          ..durationMs = 2103,
      ]),
    );
    await tester.pump(const Duration(milliseconds: 150));

    // Three dials, one line.
    expect(find.text('3 peers'), findsOneWidget);
    // The hop resolved in place rather than adding a second line.
    expect(find.text('hop ✓'), findsOneWidget);
    expect(find.text('hop →'), findsNothing);
    expect(find.text('2103ms'), findsOneWidget);
  });

  /// An old daemon ignores the request field silently, so the panel has to
  /// infer it from sustained silence rather than an error.
  testWidgets('reports a daemon that never sends events', (tester) async {
    final notifier = container.read(inferenceEventsProvider.notifier);
    notifier.startRun();
    await tester.pumpWidget(_host(container));
    expect(find.textContaining('Waiting for the daemon'), findsOneWidget);

    // Past the grace period, still nothing.
    await tester.pump(const Duration(seconds: 9));
    await tester.pump();
    expect(
      find.textContaining('does not report inference events'),
      findsOneWidget,
    );
  });
}
