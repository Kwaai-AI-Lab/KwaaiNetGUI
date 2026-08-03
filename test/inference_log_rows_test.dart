import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/chat/generated/kwaai.pb.dart' as pb;
import 'package:kwaainet_gui/src/chat/inference_log_rows.dart';

pb.InferenceEvent _dial(String name, {bool ok = true, int ms = 3000}) =>
    pb.InferenceEvent()
      ..phase = pb.InferencePhase.INFERENCE_PHASE_PEER_DIAL
      ..elapsedMs = Int64(ms)
      ..peerName = name
      ..ok = ok;

pb.InferenceEvent _hop(
  pb.InferencePhase phase, {
  required int start,
  required int end,
  String peer = 'node-f',
  int token = 0,
  int candidate = 0,
  int ms = 4000,
  double? durationMs,
  pb.HopFailure failure = pb.HopFailure.HOP_FAILURE_UNSPECIFIED,
}) {
  final e = pb.InferenceEvent()
    ..phase = phase
    ..elapsedMs = Int64(ms)
    ..peerName = peer
    ..blockStart = start
    ..blockEnd = end
    ..tokenIndex = token
    ..candidateIndex = candidate;
  if (durationMs != null) e.durationMs = durationMs;
  if (failure != pb.HopFailure.HOP_FAILURE_UNSPECIFIED) e.failure = failure;
  return e;
}

void main() {
  group('dial collapsing', () {
    test('a burst of dials becomes one row with a tally', () {
      final rows = collapseEvents([
        _dial('a'),
        _dial('b'),
        _dial('c'),
        _dial('d'),
      ]);

      expect(rows, hasLength(1));
      expect(rows.single.label, 'dial');
      expect(rows.single.detail, '4 peers');
      expect(rows.single.outcome, RowOutcome.ok);
    });

    test('unreachable peers are counted but do not fail the row', () {
      // Some peers refusing a dial is routine — the hop may still succeed
      // later — so the row must not read as an error.
      final rows = collapseEvents([
        _dial('a'),
        _dial('you', ok: false),
        _dial('c'),
      ]);

      expect(rows.single.detail, '3 peers · 1 unreachable');
      expect(rows.single.outcome, RowOutcome.ok);
    });

    test('a dial run where nothing answered is a failure', () {
      final rows = collapseEvents([_dial('a', ok: false)]);
      expect(rows.single.outcome, RowOutcome.failed);
    });

    test('a later burst starts a fresh row rather than extending the old', () {
      // Otherwise a rebuild's dials would silently increment a tally
      // rendered far above, and the count would describe two runs at once.
      final rows = collapseEvents([
        _dial('a'),
        _dial('b'),
        pb.InferenceEvent()
          ..phase = pb.InferencePhase.INFERENCE_PHASE_PATH_REBUILD
          ..elapsedMs = Int64(5000),
        _dial('c'),
      ]);

      expect(rows, hasLength(3));
      expect(rows.first.detail, '2 peers');
      expect(rows.last.detail, '1 peer');
    });
  });

  group('hop collapsing', () {
    test('a hop is one row that turns from → into ✓', () {
      final rows = collapseEvents([
        _hop(
          pb.InferencePhase.INFERENCE_PHASE_HOP_START,
          start: 0,
          end: 32,
          ms: 4700,
        ),
        _hop(
          pb.InferencePhase.INFERENCE_PHASE_HOP_OK,
          start: 0,
          end: 32,
          ms: 6800,
          durationMs: 2103,
        ),
      ]);

      expect(rows, hasLength(1), reason: 'request and answer are one line');
      expect(rows.single.outcome, RowOutcome.ok);
      expect(rows.single.detail, contains('0–32'));
      expect(rows.single.trailing, '2103ms');
      // The row keeps the *request's* time, so rows stay in the order
      // things were started rather than jumping when answers land.
      expect(rows.single.elapsedMs, 4700);
    });

    test('an unanswered hop stays pending', () {
      final rows = collapseEvents([
        _hop(pb.InferencePhase.INFERENCE_PHASE_HOP_START, start: 0, end: 32),
      ]);
      expect(rows.single.outcome, RowOutcome.pending);
      expect(rows.single.trailing, isEmpty);
    });

    test('a failure marks the row ✗ and names the reason', () {
      final rows = collapseEvents([
        _hop(pb.InferencePhase.INFERENCE_PHASE_HOP_START, start: 0, end: 32),
        _hop(
          pb.InferencePhase.INFERENCE_PHASE_HOP_FAILED,
          start: 0,
          end: 32,
          failure: pb.HopFailure.HOP_FAILURE_TIMEOUT,
        ),
      ]);

      expect(rows, hasLength(1));
      expect(rows.single.outcome, RowOutcome.failed);
      expect(rows.single.trailing, 'timeout');
    });

    /// The fallback is the whole reason the panel exists, so it must read
    /// as two lines — the peer that failed, then the one that worked.
    test('a retry is its own row, not a mutation of the failed one', () {
      final rows = collapseEvents([
        _hop(
          pb.InferencePhase.INFERENCE_PHASE_HOP_START,
          start: 0,
          end: 32,
          peer: 'node-b',
        ),
        _hop(
          pb.InferencePhase.INFERENCE_PHASE_HOP_FAILED,
          start: 0,
          end: 32,
          peer: 'node-b',
          failure: pb.HopFailure.HOP_FAILURE_TRANSIENT,
        ),
        _hop(
          pb.InferencePhase.INFERENCE_PHASE_HOP_START,
          start: 0,
          end: 32,
          peer: 'node-f',
          candidate: 1,
        ),
        _hop(
          pb.InferencePhase.INFERENCE_PHASE_HOP_OK,
          start: 0,
          end: 32,
          peer: 'node-f',
          candidate: 1,
          durationMs: 184,
        ),
      ]);

      expect(rows, hasLength(2));
      expect(rows.first.outcome, RowOutcome.failed);
      expect(rows.first.detail, contains('node-b'));
      expect(rows.last.outcome, RowOutcome.ok);
      expect(rows.last.detail, contains('node-f'));
      expect(rows.last.trailing, '184ms');
    });

    test('the same hop at different tokens does not collapse together', () {
      final rows = collapseEvents([
        _hop(
          pb.InferencePhase.INFERENCE_PHASE_HOP_START,
          start: 0,
          end: 32,
          token: 0,
        ),
        _hop(
          pb.InferencePhase.INFERENCE_PHASE_HOP_OK,
          start: 0,
          end: 32,
          token: 0,
          durationMs: 10,
        ),
        _hop(
          pb.InferencePhase.INFERENCE_PHASE_HOP_START,
          start: 0,
          end: 32,
          token: 1,
        ),
        _hop(
          pb.InferencePhase.INFERENCE_PHASE_HOP_OK,
          start: 0,
          end: 32,
          token: 1,
          durationMs: 12,
        ),
      ]);

      expect(rows, hasLength(2));
      expect(rows.map((r) => r.trailing), ['10ms', '12ms']);
    });

    /// The ring buffer drops from the front, so an answer can outlive the
    /// request that created its row. It must still render.
    test('an answer whose start was trimmed away still gets a row', () {
      final rows = collapseEvents([
        _hop(
          pb.InferencePhase.INFERENCE_PHASE_HOP_OK,
          start: 8,
          end: 16,
          durationMs: 55,
        ),
      ]);

      expect(rows, hasLength(1));
      expect(rows.single.outcome, RowOutcome.ok);
      expect(rows.single.trailing, '55ms');
    });
  });

  group('other phases', () {
    test('non-hop phases render one row each, in order', () {
      final rows = collapseEvents([
        pb.InferenceEvent()
          ..phase = pb.InferencePhase.INFERENCE_PHASE_RESOLVED
          ..elapsedMs = Int64(0)
          ..totalBlocks = 32,
        pb.InferenceEvent()
          ..phase = pb.InferencePhase.INFERENCE_PHASE_DISCOVERY_RESULT
          ..elapsedMs = Int64(1600)
          ..peerCount = 13
          ..coveredBlocks = 32
          ..totalBlocks = 32,
      ]);

      expect(rows.map((r) => r.label), ['resolved', 'discover']);
      expect(rows.first.detail, '32 blocks');
      expect(rows.last.detail, '→ 13 peers, 32/32 blocks');
    });

    /// A newer daemon may send a phase this build has no case for; it
    /// should stay readable rather than rendering as a blank line.
    test('an unknown phase falls back to the daemon text', () {
      final rows = collapseEvents([
        pb.InferenceEvent()
          ..phase = pb.InferencePhase.INFERENCE_PHASE_UNSPECIFIED
          ..elapsedMs = Int64(10)
          ..message = 'something new',
      ]);

      expect(rows.single.detail, 'something new');
    });
  });
}
