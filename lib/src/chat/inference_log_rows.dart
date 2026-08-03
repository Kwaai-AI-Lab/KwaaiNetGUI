import 'generated/kwaai.pb.dart' as pb;

/// How a row's outcome is drawn: a request awaiting its answer, a success,
/// or a failure.
enum RowOutcome { pending, ok, failed }

/// One line of the panel's log.
///
/// Deliberately *not* one-per-event. The daemon emits a request and its
/// answer as two separate events because they happen at two different
/// times, but a reader watching a run wants one line per thing-that-is-
/// happening, updating in place from `→` to `✓`. Rendering the raw stream
/// gives twice the rows and pushes the interesting ones off-screen.
class LogRow {
  LogRow({
    required this.key,
    required this.elapsedMs,
    required this.label,
    required this.outcome,
    this.detail = '',
    this.prefix = '',
    this.trailing = '',
    this.phase = pb.InferencePhase.INFERENCE_PHASE_UNSPECIFIED,
    this.failure = pb.HopFailure.HOP_FAILURE_UNSPECIFIED,
    this.isSelf = false,
  });

  /// Stable identity for this row across rebuilds, so a row that gains its
  /// outcome is recognised as the same row rather than a new one.
  final String key;

  /// Milliseconds since run start — of the *request*, not the answer, so
  /// rows stay in the order things were initiated.
  final int elapsedMs;

  /// The leading verb, e.g. `hop`, `dial`, `discover`.
  final String label;

  /// The middle column: what the row is about.
  String detail;

  /// Set when a token folded into this row, e.g. `#2`. Kept separate from
  /// [detail] so it can be dimmed independently — the index is a
  /// position-keeper, not the thing you read the row for.
  String prefix;

  /// The right column, e.g. a duration. Filled in when the answer lands.
  String trailing;

  RowOutcome outcome;
  pb.InferencePhase phase;
  pb.HopFailure failure;
  bool isSelf;
}

/// Identity of a hop attempt.
///
/// A hop's request and its answer are matched on this triple rather than on
/// adjacency, because other events interleave between them. Crucially it
/// includes the candidate index, so the *retry* after a failure is a
/// distinct attempt and gets its own row — collapsing it onto the failed
/// one would hide exactly the fallback behaviour the panel exists to show.
String _hopKey(pb.InferenceEvent e) {
  final token = e.hasTokenIndex() ? e.tokenIndex : -1;
  final cand = e.hasCandidateIndex() ? e.candidateIndex : 0;
  final start = e.hasBlockStart() ? e.blockStart : -1;
  return 'hop:$token:$start:$cand';
}

String _blocks(pb.InferenceEvent e) => e.hasBlockStart() && e.hasBlockEnd()
    ? '${e.blockStart}–${e.blockEnd}'
    : '';

String _peer(pb.InferenceEvent e) {
  if (e.isSelf) return 'you';
  if (e.peerName.isNotEmpty) return e.peerName;
  return shortPeerId(e.peerId);
}

/// Elide a base58 peer id to something that still identifies it on sight.
String shortPeerId(String id) {
  if (id.length <= 14) return id;
  return '${id.substring(0, 8)}…${id.substring(id.length - 4)}';
}

String _failureLabel(pb.HopFailure f) => switch (f) {
  pb.HopFailure.HOP_FAILURE_NO_HANDLER => 'no handler',
  pb.HopFailure.HOP_FAILURE_TRANSIENT => 'transient',
  pb.HopFailure.HOP_FAILURE_TIMEOUT => 'timeout',
  _ => 'failed',
};

/// Fold the raw event stream into display rows.
///
/// Pure and total: it never drops an event's *information*, only its
/// separate line. Three collapses, each answering a question the raw log
/// answered badly:
///
///  - **Dials** become a single running tally. A 13-peer mesh emitted 13
///    near-simultaneous lines that said nothing individually and buried
///    the chain that followed.
///  - **Hops** become one row that starts as `→` and becomes `✓` when the
///    answer arrives, carrying its duration. Two lines per hop per token
///    is the bulk of a long run's log.
///  - **Tokens** fold into the hop that produced them. `TOKEN_SAMPLED`
///    measures the whole round trip plus local sampling, so on a
///    single-hop chain it restates the hop's own duration one line later
///    (724ms of hop inside 731ms of token). The token index is worth
///    keeping; the second line is not.
///  - **Failures** stay as their own `✗` row, and the retry lands on the
///    next row, so a fallback reads as two lines rather than being merged
///    into one and disappearing.
List<LogRow> collapseEvents(List<pb.InferenceEvent> events) {
  final rows = <LogRow>[];
  final byKey = <String, LogRow>{};

  // The last successfully-completed hop row, per token. A token's result
  // is folded into this rather than getting a line of its own; a *failed*
  // hop is never a fold target, because the diagnostic value of a failure
  // is exactly the thing that must not be overwritten.
  final lastOkHopForToken = <int, LogRow>{};

  // The dial tally currently being accumulated. Cleared by any non-dial
  // event so a later burst (after a path rebuild) starts a fresh row
  // rather than silently adding to a stale count far above it.
  LogRow? dialRow;
  var dialOk = 0;
  var dialFail = 0;

  void endDialRun() {
    dialRow = null;
    dialOk = 0;
    dialFail = 0;
  }

  for (final e in events) {
    final ms = e.elapsedMs.toInt();

    if (e.phase == pb.InferencePhase.INFERENCE_PHASE_PEER_DIAL) {
      if (e.ok) {
        dialOk++;
      } else {
        dialFail++;
      }
      final total = dialOk + dialFail;
      if (dialRow == null) {
        dialRow = LogRow(
          key: 'dial:$ms:$total',
          elapsedMs: ms,
          label: 'dial',
          outcome: RowOutcome.ok,
          phase: e.phase,
        );
        rows.add(dialRow!);
        byKey[dialRow!.key] = dialRow!;
      }
      dialRow!
        ..detail =
            '$total peer${total == 1 ? '' : 's'}'
            '${dialFail > 0 ? ' · $dialFail unreachable' : ''}'
        // Some peers being unreachable is routine — the hop may still
        // succeed later — so the row only turns red if *none* answered.
        ..outcome = dialOk == 0 ? RowOutcome.failed : RowOutcome.ok;
      continue;
    }

    endDialRun();

    switch (e.phase) {
      case pb.InferencePhase.INFERENCE_PHASE_HOP_START:
        final key = _hopKey(e);
        final row = LogRow(
          key: key,
          elapsedMs: ms,
          label: 'hop',
          detail: '${_blocks(e)}  ${_peer(e)}',
          outcome: RowOutcome.pending,
          phase: e.phase,
          isSelf: e.isSelf,
        );
        rows.add(row);
        byKey[key] = row;

      case pb.InferencePhase.INFERENCE_PHASE_HOP_OK:
      case pb.InferencePhase.INFERENCE_PHASE_HOP_FAILED:
        final ok = e.phase == pb.InferencePhase.INFERENCE_PHASE_HOP_OK;
        final key = _hopKey(e);
        // Normally this resolves the row its HOP_START created. If the
        // start was trimmed off the front of the ring buffer — or a future
        // daemon stops emitting starts — the answer still gets a row of
        // its own instead of vanishing.
        final row =
            byKey[key] ??
            () {
              final r = LogRow(
                key: key,
                elapsedMs: ms,
                label: 'hop',
                detail: '${_blocks(e)}  ${_peer(e)}',
                outcome: RowOutcome.pending,
                isSelf: e.isSelf,
              );
              rows.add(r);
              byKey[key] = r;
              return r;
            }();
        row
          ..outcome = ok ? RowOutcome.ok : RowOutcome.failed
          ..phase = e.phase
          ..failure = e.failure
          ..trailing = ok
              ? (e.hasDurationMs() ? '${e.durationMs.round()}ms' : '')
              : _failureLabel(e.failure);
        // The last hop to succeed for a token is where that token's
        // result will be folded. On a multi-hop chain that is the final
        // hop, which is also when the token actually became available.
        if (ok && e.hasTokenIndex()) lastOkHopForToken[e.tokenIndex] = row;

      case pb.InferencePhase.INFERENCE_PHASE_TOKEN_SAMPLED:
        final idx = e.hasTokenIndex() ? e.tokenIndex : 0;
        final target = lastOkHopForToken[idx];
        if (target != null) {
          // Fold: the hop line already carries the peer, the blocks and
          // the time. All the token adds is which token it was.
          target.prefix = e.isPrefill ? 'prefill' : '#$idx';
        } else {
          // No hop to fold into — a local run, or the hop was trimmed.
          // The token still needs to be visible.
          rows.add(
            LogRow(
              key: 'tok:$idx',
              elapsedMs: ms,
              label: e.isPrefill ? 'prefill' : 'token',
              detail: _detail(e),
              outcome: RowOutcome.ok,
              phase: e.phase,
            ),
          );
        }

      default:
        rows.add(
          LogRow(
            key: 'e:${rows.length}',
            elapsedMs: ms,
            label: _label(e),
            detail: _detail(e),
            outcome: switch (e.phase) {
              pb.InferencePhase.INFERENCE_PHASE_PATH_REBUILD =>
                RowOutcome.failed,
              _ => RowOutcome.ok,
            },
            phase: e.phase,
          ),
        );
    }
  }

  return rows;
}

/// The leading verb for a non-hop, non-dial phase.
String _label(pb.InferenceEvent e) => switch (e.phase) {
  pb.InferencePhase.INFERENCE_PHASE_RESOLVED => 'resolved',
  pb.InferencePhase.INFERENCE_PHASE_DISCOVERY_START => 'discover',
  pb.InferencePhase.INFERENCE_PHASE_DISCOVERY_RESULT => 'discover',
  pb.InferencePhase.INFERENCE_PHASE_CIRCUIT_LOADED => 'circuit',
  pb.InferencePhase.INFERENCE_PHASE_CHAIN_PINNED => 'pinned',
  pb.InferencePhase.INFERENCE_PHASE_PATH_REBUILD => 'rebuild',
  pb.InferencePhase.INFERENCE_PHASE_TOKEN_SAMPLED =>
    e.isPrefill ? 'prefill' : 'token',
  pb.InferencePhase.INFERENCE_PHASE_COMPLETE => 'done',
  // A phase this build predates stays readable via the daemon's own text.
  _ => '',
};

/// The descriptive column for a non-hop, non-dial phase.
String _detail(pb.InferenceEvent e) {
  switch (e.phase) {
    case pb.InferencePhase.INFERENCE_PHASE_RESOLVED:
      return e.hasTotalBlocks() ? '${e.totalBlocks} blocks' : e.model;
    case pb.InferencePhase.INFERENCE_PHASE_DISCOVERY_START:
      return 'round ${e.hasAttempt() ? e.attempt : 1}';
    case pb.InferencePhase.INFERENCE_PHASE_DISCOVERY_RESULT:
      final n = e.hasPeerCount() ? e.peerCount : 0;
      final cov = e.hasCoveredBlocks() && e.hasTotalBlocks()
          ? ', ${e.coveredBlocks}/${e.totalBlocks} blocks'
          : '';
      return '→ $n peer${n == 1 ? '' : 's'}$cov';
    case pb.InferencePhase.INFERENCE_PHASE_CIRCUIT_LOADED:
      return e.circuitId;
    case pb.InferencePhase.INFERENCE_PHASE_CHAIN_PINNED:
      return '${e.hops.length} hop${e.hops.length == 1 ? '' : 's'}';
    case pb.InferencePhase.INFERENCE_PHASE_PATH_REBUILD:
      return 'path attempt ${e.hasAttempt() ? e.attempt : 2}';
    case pb.InferencePhase.INFERENCE_PHASE_TOKEN_SAMPLED:
      final ms = e.hasDurationMs() ? '  ${e.durationMs.round()}ms' : '';
      return '#${e.hasTokenIndex() ? e.tokenIndex : 0}$ms';
    case pb.InferencePhase.INFERENCE_PHASE_COMPLETE:
      final n = e.hasTokenIndex() ? e.tokenIndex : 0;
      return '$n tokens${e.message.isEmpty ? '' : ' (${e.message})'}';
    default:
      return e.message.isEmpty ? e.phase.name : e.message;
  }
}
