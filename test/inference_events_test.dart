import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/chat/generated/kwaai.pb.dart' as pb;
import 'package:kwaainet_gui/src/chat/inference_events_state.dart';

pb.InferenceEvent _event(
  pb.InferencePhase phase, {
  int? blockStart,
  int? blockEnd,
  double? durationMs,
  int elapsedMs = 0,
  List<pb.InferenceHop>? hops,
  int? totalBlocks,
  String model = '',
}) {
  final e = pb.InferenceEvent()
    ..phase = phase
    ..elapsedMs = Int64(elapsedMs)
    ..model = model;
  if (blockStart != null) e.blockStart = blockStart;
  if (blockEnd != null) e.blockEnd = blockEnd;
  if (durationMs != null) e.durationMs = durationMs;
  if (totalBlocks != null) e.totalBlocks = totalBlocks;
  if (hops != null) e.hops.addAll(hops);
  return e;
}

pb.InferenceHop _hop(String name, int start, int end, {bool isSelf = false}) =>
    pb.InferenceHop()
      ..peerId = '12D3KooW${name}xxxxxxxxxxxxxxxxxxxx'
      ..peerName = name
      ..blockStart = start
      ..blockEnd = end
      ..isSelf = isSelf;

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  InferenceEventsNotifier notifier() =>
      container.read(inferenceEventsProvider.notifier);
  InferenceRunLog log() => container.read(inferenceEventsProvider);

  /// Feed events and let the notifier's throttle settle.
  Future<void> feed(List<pb.InferenceEvent> events) async {
    final ctrl = StreamController<pb.InferenceEvent>();
    notifier().ingest(ctrl.stream);
    for (final e in events) {
      ctrl.add(e);
    }
    await ctrl.close();
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  group('InferenceEventsNotifier', () {
    test('starts empty and not running', () {
      expect(log().events, isEmpty);
      expect(log().running, isFalse);
      expect(log().sawAnyEvent, isFalse);
    });

    test('startRun marks the run live and clears the previous one', () async {
      notifier().startRun();
      await feed([_event(pb.InferencePhase.INFERENCE_PHASE_HOP_START)]);
      expect(log().events, isNotEmpty);

      notifier().startRun();
      expect(log().events, isEmpty, reason: 'previous run is discarded');
      expect(log().running, isTrue);
      expect(log().sawAnyEvent, isFalse);
    });

    test('records the pinned chain and resolved model', () async {
      notifier().startRun();
      await feed([
        _event(
          pb.InferencePhase.INFERENCE_PHASE_RESOLVED,
          model: 'meta-llama/Llama-3.2-1B',
          totalBlocks: 16,
        ),
        _event(
          pb.InferencePhase.INFERENCE_PHASE_CHAIN_PINNED,
          totalBlocks: 16,
          hops: [_hop('me', 0, 8, isSelf: true), _hop('node-f', 8, 16)],
        ),
      ]);

      expect(log().model, 'meta-llama/Llama-3.2-1B');
      expect(log().totalBlocks, 16);
      expect(log().chain, hasLength(2));
      expect(log().chain.first.isSelf, isTrue);
      expect(log().chain.last.peerName, 'node-f');
    });

    test('tracks per-hop status through start, ok and failure', () async {
      notifier().startRun();
      await feed([
        _event(
          pb.InferencePhase.INFERENCE_PHASE_CHAIN_PINNED,
          hops: [_hop('a', 0, 8), _hop('b', 8, 16)],
        ),
        _event(
          pb.InferencePhase.INFERENCE_PHASE_HOP_OK,
          blockStart: 0,
          blockEnd: 8,
          durationMs: 12.0,
        ),
        _event(
          pb.InferencePhase.INFERENCE_PHASE_HOP_START,
          blockStart: 8,
          blockEnd: 16,
        ),
      ]);

      expect(log().hopStatus[0], HopStatus.ok);
      expect(log().hopMs[0], 12.0);
      expect(log().hopStatus[8], HopStatus.inFlight);

      await feed([
        _event(
          pb.InferencePhase.INFERENCE_PHASE_HOP_FAILED,
          blockStart: 8,
          blockEnd: 16,
        ),
      ]);
      expect(log().hopStatus[8], HopStatus.failed);
    });

    /// A rebuilt route can serve the same block range from a different
    /// peer, so stale per-hop state would attribute the old peer's timing
    /// to the new one.
    test('re-pinning the chain clears stale hop state', () async {
      notifier().startRun();
      await feed([
        _event(
          pb.InferencePhase.INFERENCE_PHASE_CHAIN_PINNED,
          hops: [_hop('a', 0, 8)],
        ),
        _event(
          pb.InferencePhase.INFERENCE_PHASE_HOP_OK,
          blockStart: 0,
          blockEnd: 8,
          durationMs: 99.0,
        ),
        _event(
          pb.InferencePhase.INFERENCE_PHASE_CHAIN_PINNED,
          hops: [_hop('b', 0, 8)],
        ),
      ]);

      expect(log().chain.single.peerName, 'b');
      expect(log().hopStatus, isEmpty);
      expect(log().hopMs, isEmpty);
    });

    test('caps the log and reports what was dropped', () async {
      notifier().startRun();
      await feed([
        for (var i = 0; i < kMaxInferenceEvents + 10; i++)
          _event(pb.InferencePhase.INFERENCE_PHASE_HOP_OK, elapsedMs: i),
      ]);

      expect(log().events.length, lessThanOrEqualTo(kMaxInferenceEvents));
      expect(log().droppedFromFront, greaterThan(0));
      // The tail is what survives — the newest event is still present.
      expect(
        log().events.last.elapsedMs.toInt(),
        kMaxInferenceEvents + 9,
      );
    });

    test('a closed stream ends the run', () async {
      notifier().startRun();
      expect(log().running, isTrue);
      await feed([_event(pb.InferencePhase.INFERENCE_PHASE_COMPLETE)]);
      expect(log().running, isFalse);
      expect(log().sawAnyEvent, isTrue);
    });

    /// The operation's failure arrives on this stream too. The panel must
    /// stop claiming the run is live, or it shows a spinner forever.
    test('a stream error ends the run', () async {
      notifier().startRun();
      final ctrl = StreamController<pb.InferenceEvent>();
      notifier().ingest(ctrl.stream);
      ctrl.addError(StateError('operation failed'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(log().running, isFalse);
    });

    test('reset clears everything', () async {
      notifier().startRun();
      await feed([_event(pb.InferencePhase.INFERENCE_PHASE_HOP_OK)]);
      notifier().reset();
      expect(log().events, isEmpty);
      expect(log().chain, isEmpty);
      expect(log().running, isFalse);
      expect(log().sawAnyEvent, isFalse);
    });
  });
}
