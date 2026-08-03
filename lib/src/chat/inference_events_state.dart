import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'generated/kwaai.pb.dart' as pb;

/// How many events one run keeps before the oldest are dropped.
///
/// A run emits roughly two events per hop per token, so a four-hop chain
/// answering with a couple of hundred tokens lands in the low thousands —
/// and `max_tokens` is only a default, so there is no upper bound to rely
/// on. This keeps a full default-length run visible while capping what a
/// long session can retain.
const kMaxInferenceEvents = 2000;

/// How many are discarded once the cap is hit.
///
/// Dropping a block at a time rather than one per arrival keeps the trim
/// amortised — removing a single element from the front of a list is O(n),
/// which at this list length would otherwise be paid on every event.
const _trimBatch = 256;

/// How long event arrivals are coalesced before the UI rebuilds.
///
/// Matches the chat transcript's throttle, and for the same reason: events
/// arrive in bursts, and rebuilding per event drops frames without making
/// anything more legible at human timescales.
const _bumpInterval = Duration(milliseconds: 66);

/// One hop of the route a run is using.
class InferenceHopView {
  const InferenceHopView({
    required this.peerId,
    required this.peerName,
    required this.blockStart,
    required this.blockEnd,
    required this.isSelf,
  });

  factory InferenceHopView.fromProto(pb.InferenceHop h) => InferenceHopView(
    peerId: h.peerId,
    peerName: h.peerName,
    blockStart: h.blockStart,
    blockEnd: h.blockEnd,
    isSelf: h.isSelf,
  );

  final String peerId;
  final String peerName;
  final int blockStart;
  final int blockEnd;
  final bool isSelf;
}

/// What a hop is currently doing, for the chain view's status dot.
enum HopStatus { pending, inFlight, ok, failed }

/// A run's telemetry: the route, per-hop live status, and the event log.
///
/// Immutable — the notifier replaces it wholesale so Riverpod's equality
/// check does the right thing.
class InferenceRunLog {
  const InferenceRunLog({
    this.events = const [],
    this.chain = const [],
    this.hopStatus = const {},
    this.hopMs = const {},
    this.running = false,
    this.sawAnyEvent = false,
    this.model = '',
    this.sessionId = '',
    this.totalBlocks = 0,
    this.droppedFromFront = 0,
    this.startedAt,
  });

  /// Most recent events, oldest first, capped at [kMaxInferenceEvents].
  final List<pb.InferenceEvent> events;

  /// The route as last pinned. Replaced wholesale on a rebuild.
  final List<InferenceHopView> chain;

  /// Live status per hop, keyed by `blockStart`.
  final Map<int, HopStatus> hopStatus;

  /// Most recent duration per hop, keyed by `blockStart`.
  final Map<int, double> hopMs;

  /// Whether a run is in flight. False once it completes or fails.
  final bool running;

  /// Whether any event has arrived for this run.
  ///
  /// This is what separates "the daemon is old and will never send events"
  /// from "the run is quiet": proto3 drops the unknown request field
  /// silently, so silence is the only signal an old daemon gives.
  final bool sawAnyEvent;

  final String model;

  /// The daemon's id for this run, shown once in the header.
  ///
  /// Constant for a whole run and identical to the id the serving peers
  /// log, so it is the handle for finding this run in another node's
  /// logs. Per-row it would be the same 20 characters on every line.
  final String sessionId;

  final int totalBlocks;

  /// How many events were dropped off the front to stay under the cap, so
  /// a reader can tell a trimmed log from a complete one.
  final int droppedFromFront;

  final DateTime? startedAt;

  InferenceRunLog copyWith({
    List<pb.InferenceEvent>? events,
    List<InferenceHopView>? chain,
    Map<int, HopStatus>? hopStatus,
    Map<int, double>? hopMs,
    bool? running,
    bool? sawAnyEvent,
    String? model,
    String? sessionId,
    int? totalBlocks,
    int? droppedFromFront,
    DateTime? startedAt,
  }) => InferenceRunLog(
    events: events ?? this.events,
    chain: chain ?? this.chain,
    hopStatus: hopStatus ?? this.hopStatus,
    hopMs: hopMs ?? this.hopMs,
    running: running ?? this.running,
    sawAnyEvent: sawAnyEvent ?? this.sawAnyEvent,
    model: model ?? this.model,
    sessionId: sessionId ?? this.sessionId,
    totalBlocks: totalBlocks ?? this.totalBlocks,
    droppedFromFront: droppedFromFront ?? this.droppedFromFront,
    startedAt: startedAt ?? this.startedAt,
  );
}

/// Telemetry for the *current* run.
///
/// Deliberately one run, cleared on each send: a per-message history would
/// mean the panel tracking transcript scroll position, which is a different
/// and much larger feature than watching what is happening now.
///
/// A [Notifier] rather than a [StreamProvider] because the lifecycle is
/// driven from [ChatTranscriptNotifier.send] — the provider does not own
/// the subscription and cannot start it on its own.
class InferenceEventsNotifier extends Notifier<InferenceRunLog> {
  StreamSubscription<pb.InferenceEvent>? _sub;
  Timer? _bumpTimer;

  // Mutated in place between bumps; published by [_bumpThrottled].
  List<pb.InferenceEvent> _events = [];
  List<InferenceHopView> _chain = [];
  Map<int, HopStatus> _hopStatus = {};
  Map<int, double> _hopMs = {};
  bool _sawAny = false;
  String _model = '';
  String _sessionId = '';
  int _totalBlocks = 0;
  int _dropped = 0;

  @override
  InferenceRunLog build() {
    ref.onDispose(() {
      _sub?.cancel();
      _bumpTimer?.cancel();
    });
    return const InferenceRunLog();
  }

  /// Begin a run: clears the previous one and marks this one in flight.
  void startRun() {
    _sub?.cancel();
    _sub = null;
    _bumpTimer?.cancel();
    _bumpTimer = null;
    _events = [];
    _chain = [];
    _hopStatus = {};
    _hopMs = {};
    _sawAny = false;
    _model = '';
    _sessionId = '';
    _totalBlocks = 0;
    _dropped = 0;
    state = InferenceRunLog(running: true, startedAt: DateTime.now());
  }

  /// Consume a run's event stream. Ends the run when it closes or errors.
  void ingest(Stream<pb.InferenceEvent> events) {
    _sub?.cancel();
    _sub = events.listen(
      _onEvent,
      // The stream carries the operation's failure too, and the panel
      // should stop showing "running" when that happens. The error text
      // itself is the chat transcript's to display, not ours.
      onError: (Object _, StackTrace _) => endRun(),
      onDone: endRun,
      cancelOnError: true,
    );
  }

  void _onEvent(pb.InferenceEvent e) {
    _sawAny = true;
    _events.add(e);

    // Latched from whichever event carries it first. Only hop-level events
    // set it — the run-level ones (resolve, discovery) happen before a
    // session exists — so this cannot be read from a fixed phase.
    if (_sessionId.isEmpty && e.sessionId.isNotEmpty) _sessionId = e.sessionId;
    if (_events.length > kMaxInferenceEvents) {
      _events.removeRange(0, _trimBatch);
      _dropped += _trimBatch;
    }

    switch (e.phase) {
      case pb.InferencePhase.INFERENCE_PHASE_RESOLVED:
        _model = e.model;
        if (e.hasTotalBlocks()) _totalBlocks = e.totalBlocks;
      case pb.InferencePhase.INFERENCE_PHASE_CHAIN_PINNED:
        _chain = e.hops.map(InferenceHopView.fromProto).toList();
        if (e.hasTotalBlocks()) _totalBlocks = e.totalBlocks;
        // A rebuilt route invalidates the old per-hop state: the same
        // block range may now be served by a different peer entirely.
        _hopStatus = {};
        _hopMs = {};
      case pb.InferencePhase.INFERENCE_PHASE_HOP_START:
        if (e.hasBlockStart()) _hopStatus[e.blockStart] = HopStatus.inFlight;
      case pb.InferencePhase.INFERENCE_PHASE_HOP_OK:
        if (e.hasBlockStart()) {
          _hopStatus[e.blockStart] = HopStatus.ok;
          if (e.hasDurationMs()) _hopMs[e.blockStart] = e.durationMs;
        }
      case pb.InferencePhase.INFERENCE_PHASE_HOP_FAILED:
        if (e.hasBlockStart()) _hopStatus[e.blockStart] = HopStatus.failed;
      default:
        break;
    }
    _bumpThrottled();
  }

  /// Mark the run finished, flushing anything still pending.
  void endRun() {
    _sub?.cancel();
    _sub = null;
    _publish(running: false);
    _bumpTimer?.cancel();
    _bumpTimer = null;
  }

  /// Clear everything — backs the transcript's "new chat".
  void reset() {
    _sub?.cancel();
    _sub = null;
    _bumpTimer?.cancel();
    _bumpTimer = null;
    _events = [];
    _chain = [];
    _hopStatus = {};
    _hopMs = {};
    _sawAny = false;
    _dropped = 0;
    state = const InferenceRunLog();
  }

  void _publish({bool? running}) {
    state = InferenceRunLog(
      // Copied on publish so the mutable working list is never handed to
      // the UI, which would otherwise see it change under a const-equal
      // reference and skip the rebuild.
      events: List.unmodifiable(_events),
      chain: List.unmodifiable(_chain),
      hopStatus: Map.unmodifiable(_hopStatus),
      hopMs: Map.unmodifiable(_hopMs),
      running: running ?? state.running,
      sawAnyEvent: _sawAny,
      model: _model,
      sessionId: _sessionId,
      totalBlocks: _totalBlocks,
      droppedFromFront: _dropped,
      startedAt: state.startedAt,
    );
  }

  /// Publish immediately on the first event of a quiet period, then
  /// collapse the rest of the burst into one trailing rebuild.
  void _bumpThrottled() {
    if (_bumpTimer != null) return; // a rebuild is already pending
    _publish();
    _bumpTimer = Timer(_bumpInterval, () {
      _bumpTimer = null;
      _publish();
    });
  }
}

final inferenceEventsProvider =
    NotifierProvider<InferenceEventsNotifier, InferenceRunLog>(
      InferenceEventsNotifier.new,
    );
