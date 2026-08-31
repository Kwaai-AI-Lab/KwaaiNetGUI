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

  group('per-peer dials (daemon announces PEER_DIAL_START)', () {
    pb.InferenceEvent start(String name, {int ms = 3000}) =>
        pb.InferenceEvent()
          ..phase = pb.InferencePhase.INFERENCE_PHASE_PEER_DIAL_START
          ..elapsedMs = Int64(ms)
          ..peerId = 'id-$name'
          ..peerName = name;

    pb.InferenceEvent result(
      String name, {
      bool ok = true,
      int ms = 3500,
      double durationMs = 480,
    }) =>
        pb.InferenceEvent()
          ..phase = pb.InferencePhase.INFERENCE_PHASE_PEER_DIAL
          ..elapsedMs = Int64(ms)
          ..peerId = 'id-$name'
          ..peerName = name
          ..ok = ok
          ..durationMs = durationMs;

    /// The whole point of the start event: a dial can take tens of
    /// seconds to time out, and this is the row that names who is being
    /// waited on while it does.
    test('a dial is pending, and names its peer, until its result', () {
      final rows = collapseEvents([start('node-f')]);

      expect(rows, hasLength(1));
      expect(rows.single.label, 'dial');
      expect(rows.single.detail, 'node-f');
      expect(rows.single.outcome, RowOutcome.pending);
    });

    test('the result resolves the same row rather than adding one', () {
      final rows = collapseEvents([start('node-f'), result('node-f')]);

      expect(rows, hasLength(1));
      expect(rows.single.outcome, RowOutcome.ok);
      expect(rows.single.trailing, '480ms');
    });

    test('an unreachable peer stays on screen by name, amber not red', () {
      // A refused dial is routine — the peer may still answer its hop —
      // so it must not read as a terminal failure.
      final rows = collapseEvents([
        start('node-g'),
        result('node-g', ok: false),
      ]);

      expect(rows.single.outcome, RowOutcome.failed);
      expect(rows.single.detail, 'node-g');
      expect(rows.single.trailing, 'unreachable');
      expect(rows.single.failure, pb.HopFailure.HOP_FAILURE_TRANSIENT);
    });

    test('sequential dials are one row per peer, in dial order', () {
      final rows = collapseEvents([
        start('a'),
        result('a'),
        start('b'),
        result('b', ok: false),
        start('c'),
      ]);

      expect(rows.map((r) => r.detail), ['a', 'b', 'c']);
      expect(rows.map((r) => r.outcome), [
        RowOutcome.ok,
        RowOutcome.failed,
        RowOutcome.pending,
      ]);
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

  group('token folding', () {
    pb.InferenceEvent token(int idx, {double ms = 731, bool prefill = false}) =>
        pb.InferenceEvent()
          ..phase = pb.InferencePhase.INFERENCE_PHASE_TOKEN_SAMPLED
          ..elapsedMs = Int64(6800)
          ..tokenIndex = idx
          ..isPrefill = prefill
          ..durationMs = ms;

    /// TOKEN_SAMPLED times the whole round trip, so on a single-hop chain
    /// it restates the hop's own duration a line later. One line per
    /// token is the point of the exercise.
    test('a token folds into the hop that produced it', () {
      final rows = collapseEvents([
        _hop(pb.InferencePhase.INFERENCE_PHASE_HOP_START, start: 0, end: 32),
        _hop(
          pb.InferencePhase.INFERENCE_PHASE_HOP_OK,
          start: 0,
          end: 32,
          durationMs: 724,
        ),
        token(0),
      ]);

      expect(rows, hasLength(1), reason: 'one line per token');
      expect(rows.single.prefix, '#0');
      expect(rows.single.trailing, '724ms');
      expect(rows.single.detail, contains('node-f'));
    });

    test('prefill is labelled rather than numbered', () {
      final rows = collapseEvents([
        _hop(pb.InferencePhase.INFERENCE_PHASE_HOP_START, start: 0, end: 32),
        _hop(
          pb.InferencePhase.INFERENCE_PHASE_HOP_OK,
          start: 0,
          end: 32,
          durationMs: 29681,
        ),
        token(0, prefill: true),
      ]);

      expect(rows, hasLength(1));
      expect(rows.single.prefix, 'prefill');
    });

    test('several tokens are one row each', () {
      final events = <pb.InferenceEvent>[];
      for (var i = 0; i < 5; i++) {
        events
          ..add(
            _hop(
              pb.InferencePhase.INFERENCE_PHASE_HOP_START,
              start: 0,
              end: 32,
              token: i,
            ),
          )
          ..add(
            _hop(
              pb.InferencePhase.INFERENCE_PHASE_HOP_OK,
              start: 0,
              end: 32,
              token: i,
              durationMs: 700 + i.toDouble(),
            ),
          )
          ..add(token(i));
      }

      final rows = collapseEvents(events);
      expect(rows, hasLength(5));
      expect(rows.map((r) => r.prefix), ['#0', '#1', '#2', '#3', '#4']);
    });

    /// On a multi-hop chain the hops are the interesting part, so the
    /// token folds into the *last* one rather than collapsing them all.
    test('a multi-hop token keeps its hops and folds into the last', () {
      final rows = collapseEvents([
        _hop(
          pb.InferencePhase.INFERENCE_PHASE_HOP_START,
          start: 0,
          end: 16,
          peer: 'node-a',
        ),
        _hop(
          pb.InferencePhase.INFERENCE_PHASE_HOP_OK,
          start: 0,
          end: 16,
          peer: 'node-a',
          durationMs: 120,
        ),
        _hop(
          pb.InferencePhase.INFERENCE_PHASE_HOP_START,
          start: 16,
          end: 32,
          peer: 'node-f',
        ),
        _hop(
          pb.InferencePhase.INFERENCE_PHASE_HOP_OK,
          start: 16,
          end: 32,
          peer: 'node-f',
          durationMs: 180,
        ),
        token(0),
      ]);

      expect(rows, hasLength(2));
      expect(rows.first.prefix, isEmpty);
      expect(rows.last.prefix, '#0');
      expect(rows.last.detail, contains('node-f'));
    });

    /// A failed hop is the diagnostic content of the log; folding a token
    /// onto it would overwrite the reason it is there.
    test('a token never folds into a failed hop', () {
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
        token(0),
      ]);

      expect(rows, hasLength(2));
      expect(rows.first.outcome, RowOutcome.failed);
      expect(rows.first.prefix, isEmpty, reason: 'failure keeps its own line');
      expect(rows.last.prefix, '#0');
    });

    /// A local run has no hops at all, and the ring buffer can drop the
    /// hop out from under a token. Either way the token must still show.
    test('a token with no hop to fold into keeps its own row', () {
      final rows = collapseEvents([token(3, ms: 45)]);

      expect(rows, hasLength(1));
      expect(rows.single.label, 'token');
      expect(rows.single.detail, contains('#3'));
    });
  });

  group('correlation ids', () {
    /// seq_pos is what the serving peer logs, so it must reach the row that
    /// represents that request — it is the only greppable handle a row has.
    test('a hop row carries the sequence position of its request', () {
      final start = _hop(
        pb.InferencePhase.INFERENCE_PHASE_HOP_START,
        start: 0,
        end: 32,
      )..seqPos = 41;
      final rows = collapseEvents([
        start,
        _hop(
          pb.InferencePhase.INFERENCE_PHASE_HOP_OK,
          start: 0,
          end: 32,
          durationMs: 724,
        ),
      ]);

      expect(rows.single.seqPos, 41);
    });

    /// Prefill covers the whole prompt, so the two diverge immediately.
    /// Conflating them would send someone grepping for a position that was
    /// never on the wire.
    test('sequence position is not the token index', () {
      final e = _hop(
        pb.InferencePhase.INFERENCE_PHASE_HOP_START,
        start: 0,
        end: 32,
        token: 1,
      )..seqPos = 41;
      final rows = collapseEvents([e]);

      expect(rows.single.seqPos, 41);
      expect(rows.single.seqPos, isNot(1));
    });

    test('a row whose event carried no position leaves it null', () {
      final rows = collapseEvents([
        _hop(pb.InferencePhase.INFERENCE_PHASE_HOP_START, start: 0, end: 32),
      ]);
      expect(rows.single.seqPos, isNull);
    });
  });

  group('condensed (completed run)', () {
    pb.InferenceEvent phase(
      pb.InferencePhase p, {
      int ms = 0,
      String msg = '',
    }) => pb.InferenceEvent()
      ..phase = p
      ..elapsedMs = Int64(ms)
      ..message = msg;

    test('successful per-token hops are dropped, failures stay', () {
      final rows = collapseEvents(condensed: true, [
        phase(pb.InferencePhase.INFERENCE_PHASE_RESOLVED),
        _hop(pb.InferencePhase.INFERENCE_PHASE_HOP_START, start: 0, end: 32),
        _hop(
          pb.InferencePhase.INFERENCE_PHASE_HOP_FAILED,
          start: 0,
          end: 32,
          failure: pb.HopFailure.HOP_FAILURE_TRANSIENT,
        ),
        _hop(
          pb.InferencePhase.INFERENCE_PHASE_HOP_START,
          start: 0,
          end: 32,
          candidate: 1,
        ),
        _hop(
          pb.InferencePhase.INFERENCE_PHASE_HOP_OK,
          start: 0,
          end: 32,
          candidate: 1,
          durationMs: 120,
        ),
        phase(pb.InferencePhase.INFERENCE_PHASE_COMPLETE, ms: 9000),
      ]);

      expect(rows.map((r) => r.label), ['resolved', 'hop', 'done']);
      expect(rows[1].outcome, RowOutcome.failed);
    });

    test('the prefill hop survives condensation', () {
      // Prefill duration is the number people actually ask about.
      final rows = collapseEvents(condensed: true, [
        _hop(pb.InferencePhase.INFERENCE_PHASE_HOP_START, start: 0, end: 32),
        _hop(
          pb.InferencePhase.INFERENCE_PHASE_HOP_OK,
          start: 0,
          end: 32,
          durationMs: 119600,
        ),
        pb.InferenceEvent()
          ..phase = pb.InferencePhase.INFERENCE_PHASE_TOKEN_SAMPLED
          ..elapsedMs = Int64(120000)
          ..tokenIndex = 0
          ..isPrefill = true,
      ]);

      expect(rows, hasLength(1));
      expect(rows.single.prefix, 'prefill');
      expect(rows.single.trailing, '119600ms');
    });

    test('successful per-peer dials fold back into a tally', () {
      pb.InferenceEvent dialStart(String name) => pb.InferenceEvent()
        ..phase = pb.InferencePhase.INFERENCE_PHASE_PEER_DIAL_START
        ..peerId = 'id-$name'
        ..peerName = name;
      pb.InferenceEvent dialResult(String name, {bool ok = true}) =>
          pb.InferenceEvent()
            ..phase = pb.InferencePhase.INFERENCE_PHASE_PEER_DIAL
            ..peerId = 'id-$name'
            ..peerName = name
            ..ok = ok;

      final rows = collapseEvents(condensed: true, [
        dialStart('a'),
        dialResult('a'),
        dialStart('b'),
        dialResult('b', ok: false),
        dialStart('c'),
        dialResult('c'),
      ]);

      // The unreachable peer keeps its name — that was the original
      // complaint — while the routine successes become one line.
      expect(rows, hasLength(2));
      expect(rows.first.detail, '2 peers reachable');
      expect(rows.last.detail, 'b');
      expect(rows.last.trailing, 'unreachable');
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
