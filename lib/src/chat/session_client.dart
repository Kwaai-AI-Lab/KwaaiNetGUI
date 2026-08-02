import 'dart:async';
import 'dart:io';

import 'package:fixnum/fixnum.dart';

import 'generated/kwaai.pb.dart' as pb;
import 'generated/kwaai.pbgrpc.dart' as pbgrpc;

void _log(String msg) {
  stderr.writeln('[session] $msg');
}

/// Why a Session ended. The client treats all of these as "session
/// gone; reconnect on next operation".
enum SessionEndKind { localClose, remoteClose, transportError }

/// Multiplexed bidi session to the daemon. Owns a single open
/// `Session(...)` rpc and routes inbound `ServerFrame`s back to whichever
/// caller is awaiting them (by id). One [SessionClient] per gRPC
/// channel.
///
/// Operation entry points (`ping`, `status`, `generate`, `shardRun`,
/// `cancel`) allocate an id, send the corresponding ClientFrame, and
/// return a Future/Stream that completes/errors based on the per-id
/// ServerFrames the server emits. The stream completes on Done; it
/// errors on Error (or on session-end).
class SessionClient {
  SessionClient(this._stub);

  final pbgrpc.KwaaiNetClient _stub;

  // Outbound side of the bidi stream — a controller we write ClientFrames
  // into, which gets piped into the rpc as the request stream.
  StreamController<pb.ClientFrame>? _outbound;

  // Subscription to inbound ServerFrames; demuxes by id into per-op
  // controllers.
  StreamSubscription<pb.ServerFrame>? _inboundSub;

  // Per-operation routers. Each operation id maps to a controller its
  // caller listens on. Removed on Done/Error/session-end.
  final Map<int, StreamController<pb.ServerFrame>> _routers = {};

  // Monotonic id allocator. Starts at 1; 0 is reserved so missing-tag
  // values are obvious.
  int _nextId = 1;

  bool _closed = false;

  /// Opens the bidi stream if not already open. Idempotent.
  void ensureOpen() {
    if (_outbound != null || _closed) return;
    final out = StreamController<pb.ClientFrame>();
    _outbound = out;
    final inbound = _stub.session(out.stream);
    _log('opened Session stream');
    _inboundSub = inbound.listen(
      _handleFrame,
      onError: (Object e, StackTrace? _) {
        _log('Session inbound error: $e');
        _teardown(SessionEndKind.transportError, e.toString());
      },
      onDone: () {
        _log('Session inbound closed by server');
        _teardown(SessionEndKind.remoteClose, 'server closed Session');
      },
      cancelOnError: true,
    );
  }

  void _handleFrame(pb.ServerFrame frame) {
    final id = frame.id.toInt();
    final router = _routers[id];
    if (router == null) {
      _log('drop frame for unknown id=$id (body=${frame.whichBody()})');
      return;
    }
    router.add(frame);
    switch (frame.whichBody()) {
      case pb.ServerFrame_Body.done:
        router.close();
        _routers.remove(id);
      case pb.ServerFrame_Body.error:
        router.addError(SessionOpError(
          code: frame.error.code.value,
          message: frame.error.message,
        ));
        router.close();
        _routers.remove(id);
      default:
        break;
    }
  }

  void _teardown(SessionEndKind kind, String reason) {
    if (_closed) return;
    _closed = true;
    final routers = _routers.values.toList(growable: false);
    _routers.clear();
    for (final r in routers) {
      if (!r.isClosed) {
        r.addError(SessionEndedError(kind: kind, reason: reason));
        r.close();
      }
    }
    _outbound?.close();
    _outbound = null;
    _inboundSub?.cancel();
    _inboundSub = null;
  }

  /// Manual close — used on channel reset or app shutdown.
  Future<void> close() async =>
      _teardown(SessionEndKind.localClose, 'client close');

  // -------------------------------------------------------------------
  // Per-operation entry points
  // -------------------------------------------------------------------

  /// `ping` — cheap liveness probe; server emits Pong then Done.
  Future<pb.PingReply> ping() async {
    final frames = _open((id) => pb.ClientFrame()
      ..id = Int64(id)
      ..ping = pb.PingRequest());
    pb.PingReply? reply;
    await for (final f in frames) {
      if (f.whichBody() == pb.ServerFrame_Body.pong) {
        reply = f.pong;
      }
    }
    if (reply == null) {
      throw SessionOpError(code: 0, message: 'ping returned no Pong');
    }
    return reply;
  }

  /// `status` — daemon-side state snapshot.
  Future<pb.StatusReply> status() async {
    final frames = _open((id) => pb.ClientFrame()
      ..id = Int64(id)
      ..status = pb.StatusRequest());
    pb.StatusReply? reply;
    await for (final f in frames) {
      if (f.whichBody() == pb.ServerFrame_Body.status) {
        reply = f.status;
      }
    }
    if (reply == null) {
      throw SessionOpError(code: 0, message: 'status returned no reply');
    }
    return reply;
  }

  /// `kwaainet shard run <PROMPT>` — distributed inference. Default
  /// path used by the GUI's main chat.
  Stream<String> shardRun(String prompt, {String role = 'user'}) =>
      shardRunOp(prompt, role: role).tokens;

  /// As [shardRun], but also exposes the operation id so the caller can
  /// [cancel] it. Stopping generation needs the id, and `_open` would
  /// otherwise allocate and discard it.
  ///
  /// Set [events] to also receive [SessionOperation.events] — the daemon's
  /// account of which peers served which blocks. It is off by default
  /// because the daemon does real work to produce it, so it is only worth
  /// asking for when something is going to display it.
  SessionOperation shardRunOp(
    String prompt, {
    String role = 'user',
    bool events = false,
  }) =>
      _openOp(
        (id) => pb.ClientFrame()
          ..id = Int64(id)
          ..shardRun = (pb.ShardRunRequest()
            ..role = role
            ..content = prompt
            ..events = events),
        withEvents: events,
      );

  /// `kwaainet generate <PROMPT>` — single-node local inference. Used
  /// by the Developer tab to drive the local InferenceEngine directly.
  Stream<String> generate(String prompt, {String role = 'user'}) =>
      generateOp(prompt, role: role).tokens;

  /// As [generate], but exposes the operation id for cancellation.
  SessionOperation generateOp(String prompt, {String role = 'user'}) =>
      _openOp((id) => pb.ClientFrame()
        ..id = Int64(id)
        ..generate = (pb.GenerateRequest()
          ..role = role
          ..content = prompt));

  /// `kwaainet shard chain` — one-shot block-coverage snapshot: which
  /// peers serve which blocks of the model, per the DHT.
  Future<pb.BlockCoverageUpdate> blockCoverage() async {
    final frames = _open((id) => pb.ClientFrame()
      ..id = Int64(id)
      ..blockCoverage = pb.BlockCoverageRequest());
    pb.BlockCoverageUpdate? reply;
    await for (final f in frames) {
      if (f.whichBody() == pb.ServerFrame_Body.blockCoverage) {
        reply = f.blockCoverage;
      }
    }
    if (reply == null) {
      throw SessionOpError(code: 0, message: 'blockCoverage returned no update');
    }
    return reply;
  }

  /// Live block-coverage feed. The daemon pushes a fresh update every
  /// [intervalSecs] until the operation is [cancel]led (or the session
  /// ends). The returned operation's id is what [cancel] needs.
  BlockCoverageOperation blockCoverageSubscribe({int intervalSecs = 5}) {
    ensureOpen();
    if (_closed || _outbound == null) {
      return BlockCoverageOperation(
        id: null,
        updates: Stream<pb.BlockCoverageUpdate>.error(
          SessionEndedError(
            kind: SessionEndKind.localClose,
            reason: 'session not open',
          ),
        ),
      );
    }
    final id = _nextId++;
    final controller = StreamController<pb.ServerFrame>();
    _routers[id] = controller;
    _outbound!.add(pb.ClientFrame()
      ..id = Int64(id)
      ..blockCoverage = (pb.BlockCoverageRequest()
        ..subscribe = true
        ..intervalSecs = intervalSecs));
    // No silence watchdog here: a subscription is legitimately quiet
    // while the daemon's p2p layer is still coming up, and session-end
    // errors already propagate through the router.
    final updates = controller.stream
        .where((f) => f.whichBody() == pb.ServerFrame_Body.blockCoverage)
        .map((f) => f.blockCoverage);
    return BlockCoverageOperation(id: id, updates: updates);
  }

  /// Live VPK storage-node feed. Each discovery round pushes two updates
  /// — the DHT registry with `probesPending` set, then the same peers
  /// with reachability resolved — repeating every [intervalSecs] until
  /// the operation is [cancel]led (or the session ends).
  ///
  /// The default cadence matches the daemon's: a round dials every
  /// advertised node, so this is deliberately far slower than the
  /// block-coverage feed.
  StorageDiscoveryOperation storageDiscoverySubscribe({
    int intervalSecs = 30,
  }) {
    ensureOpen();
    if (_closed || _outbound == null) {
      return StorageDiscoveryOperation(
        id: null,
        updates: Stream<pb.StorageUpdate>.error(
          SessionEndedError(
            kind: SessionEndKind.localClose,
            reason: 'session not open',
          ),
        ),
      );
    }
    final id = _nextId++;
    final controller = StreamController<pb.ServerFrame>();
    _routers[id] = controller;
    _outbound!.add(pb.ClientFrame()
      ..id = Int64(id)
      ..storageDiscovery = (pb.StorageDiscoveryRequest()
        ..subscribe = true
        ..intervalSecs = intervalSecs));
    // As with block coverage, no silence watchdog: a subscription is
    // legitimately quiet while the daemon's p2p layer comes up, and
    // session-end errors already propagate through the router.
    final updates = controller.stream
        .where((f) => f.whichBody() == pb.ServerFrame_Body.storage)
        .map((f) => f.storage);
    return StorageDiscoveryOperation(id: id, updates: updates);
  }

  /// Cancel an in-flight operation. The target operation's stream will
  /// error with SessionOpError(code=CANCELLED).
  Future<void> cancel(int operationId) async {
    final frames = _open((id) => pb.ClientFrame()
      ..id = Int64(id)
      ..cancel = (pb.Cancel()..targetId = Int64(operationId)));
    await frames.drain<void>();
  }

  // -------------------------------------------------------------------
  // Internals
  // -------------------------------------------------------------------

  /// Closes [notices] when the stream it transforms ends, however it ends.
  ///
  /// The notice controller outlives the watchdog that feeds it, so without
  /// this a caller listening for notices would never see `onDone` and any
  /// "still working" indicator would stay up after the answer arrived.
  StreamTransformer<String, String> _closeOnDone(
    StreamController<SessionSlowNotice> notices,
  ) {
    return StreamTransformer<String, String>.fromHandlers(
      handleDone: (sink) {
        if (!notices.isClosed) notices.close();
        sink.close();
      },
      handleError: (e, st, sink) {
        if (!notices.isClosed) notices.close();
        sink.addError(e, st);
      },
    );
  }

  Stream<String> _tokensFromFrames(
    Stream<pb.ServerFrame> frames, {
    void Function(SessionSlowNotice)? onSlow,
  }) {
    return watchdogged<pb.ServerFrame, String>(
      frames,
      extract: (f) {
        if (f.whichBody() != pb.ServerFrame_Body.token) return null;
        final t = f.token;
        return t.text.isEmpty ? null : t.text;
      },
      // Any frame proves the daemon is alive, but only a token is the
      // answer actually arriving — which is what the slow notice is
      // waiting on, and what silences it.
      counts: (f) => f.whichBody() == pb.ServerFrame_Body.token,
      onSlow: onSlow,
    );
  }

  /// Allocate an id, build the ClientFrame, send it, register a router,
  /// return the per-id stream.
  /// As [_open], but keeps the allocated operation id so the caller can
  /// cancel the operation server-side.
  ///
  /// With [withEvents], the operation's frames feed two streams instead of
  /// one — see the tee below.
  SessionOperation _openOp(
    pb.ClientFrame Function(int id) build, {
    bool withEvents = false,
  }) {
    ensureOpen();
    if (_closed || _outbound == null) {
      // No frame was sent, so there is no server-side operation to
      // cancel — `id` is null rather than a fabricated number that
      // would cancel an unrelated (or future) operation if used.
      return SessionOperation(
        id: null,
        tokens: Stream<String>.error(
          SessionEndedError(
            kind: SessionEndKind.localClose,
            reason: 'session not open',
          ),
        ),
        events: const Stream<pb.InferenceEvent>.empty(),
        slow: const Stream<SessionSlowNotice>.empty(),
      );
    }
    final id = _nextId++;
    final controller = StreamController<pb.ServerFrame>();
    _routers[id] = controller;
    _outbound!.add(build(id));

    // Broadcast, unlike the frame sinks: notices are ticks with no value
    // once missed, so there is nothing to buffer for a late listener — and
    // a caller that ignores them entirely must not stall the timer.
    final slow = StreamController<SessionSlowNotice>.broadcast();
    void emitSlow(SessionSlowNotice n) {
      if (!slow.isClosed) slow.add(n);
    }

    if (!withEvents) {
      return SessionOperation(
        id: id,
        tokens: _tokensFromFrames(controller.stream, onSlow: emitSlow)
            .transform(_closeOnDone(slow)),
        events: const Stream<pb.InferenceEvent>.empty(),
        slow: slow.stream,
      );
    }

    // One router, two consumers. The router is single-subscription (see
    // [_handleFrame]), so it cannot simply be listened to twice; instead
    // subscribe once here and fan each frame out.
    //
    // Both sinks are plain controllers rather than broadcast ones, and
    // that matters: a plain controller buffers while it has no listener,
    // so nothing is lost in the window between this method returning and
    // the caller subscribing. A broadcast controller would drop those
    // first frames, which on a fast local daemon is exactly the chain
    // discovery a caller most wants to see.
    final frames = StreamController<pb.ServerFrame>();
    final events = StreamController<pb.InferenceEvent>();
    controller.stream.listen(
      (f) {
        if (f.whichBody() == pb.ServerFrame_Body.inferenceEvent) {
          if (!events.isClosed) events.add(f.inferenceEvent);
        }
        // Forward every frame, not just tokens: the token pipeline's
        // watchdog treats any frame as proof the daemon is alive.
        if (!frames.isClosed) frames.add(f);
      },
      // Errors go to *both* sinks. Sending them only downstream of the
      // tokens would leave anything watching events waiting forever on a
      // run that has already failed.
      onError: (Object e, StackTrace st) {
        if (!events.isClosed) {
          events.addError(e, st);
          events.close();
        }
        if (!frames.isClosed) {
          frames.addError(e, st);
          frames.close();
        }
      },
      onDone: () {
        if (!events.isClosed) events.close();
        if (!frames.isClosed) frames.close();
      },
    );

    return SessionOperation(
      id: id,
      tokens: _tokensFromFrames(frames.stream, onSlow: emitSlow)
          .transform(_closeOnDone(slow)),
      events: events.stream,
      slow: slow.stream,
    );
  }

  Stream<pb.ServerFrame> _open(pb.ClientFrame Function(int id) build) {
    ensureOpen();
    if (_closed || _outbound == null) {
      return Stream<pb.ServerFrame>.error(
        SessionEndedError(
          kind: SessionEndKind.localClose,
          reason: 'session not open',
        ),
      );
    }
    final id = _nextId++;
    final controller = StreamController<pb.ServerFrame>();
    _routers[id] = controller;
    _outbound!.add(build(id));
    return controller.stream;
  }
}

/// How long to wait for the daemon's *first* frame before declaring the
/// request dead.
///
/// Deliberately long. Without telemetry the daemon says nothing at all while
/// it resolves peers and runs prefill, and on a distributed model that is
/// routinely minutes — a 90s cap here killed healthy runs a few seconds
/// before their first token. This is a backstop for a wedged daemon, not a
/// bound on how long a real answer may take, so the user is told the run is
/// slow (see [kSlowNotice]) and left to decide.
const kFirstFrameTimeout = Duration(minutes: 10);

/// How long to tolerate silence *after* the stream has started producing.
/// Once tokens are flowing a long gap means the far end stopped — a healthy
/// generation does not pause this long between tokens.
///
/// This is a *silence* deadline, not a slowness one: it measures the gap
/// since the last frame of any kind, so a run that keeps reporting progress
/// never trips it however long it takes.
const kStallTimeout = Duration(minutes: 10);

/// How long a run may go without producing anything before the user is told
/// it is taking a while.
///
/// A notice, not a failure — mesh prefill on a large model genuinely runs
/// into minutes, and the run is often healthy. The user decides whether to
/// wait or cancel.
const kSlowNotice = Duration(seconds: 30);

/// How often the "still working" notice refreshes its elapsed time.
const kSlowNoticeTick = Duration(seconds: 5);

/// Progress report from a long-running operation that has not failed.
///
/// Distinct from [SessionOpError] precisely because it is not an error: it
/// carries how long the operation has been running and whether the daemon is
/// still visibly doing work, so the UI can inform without alarming.
class SessionSlowNotice {
  const SessionSlowNotice({required this.elapsed, required this.active});

  /// Time since the operation started.
  final Duration elapsed;

  /// Whether the daemon has reported activity (progress events) recently.
  ///
  /// True means the run is demonstrably alive and merely slow. False means
  /// nothing has arrived — it may still be healthy, since a daemon without
  /// telemetry says nothing during prefill, but there is no evidence either
  /// way.
  final bool active;
}

/// Wraps [source] in a silence watchdog, mapping each element through
/// [extract] (null = consume the element without emitting).
///
/// The daemon can stop sending without closing the stream or reporting an
/// error — a killed peer, a severed session, a hang inside inference. gRPC
/// won't notice: the HTTP/2 stream stays open, so `onDone`/`onError` never
/// fire and a UI waiting on it spins forever.
///
/// There is no daemon-side heartbeat to lean on (the proto has no keepalive
/// frame) and the daemon is under active development, so this deliberately
/// trusts nothing about the far end: any gap longer than the deadline becomes
/// an ordinary operation error the UI already knows how to display. The timer
/// resets on *every* element, so a slow-but-alive stream is never killed.
///
/// The deadline measures *silence*, not slowness. Any element — a token or a
/// progress event — resets it, so an operation that keeps reporting is never
/// killed no matter how long it takes. Distributed prefill on a large model
/// genuinely runs into minutes, and failing such a run threw away work that
/// was about to succeed.
///
/// [kFirstFrameTimeout] applies until the first element arrives and
/// [kStallTimeout] thereafter, both generous: they exist to eventually
/// release a wedged operation, not to bound how long a healthy one may take.
///
/// [counts] marks the elements that represent real output (tokens), as
/// opposed to mere liveness (progress events). It drives [onSlow], which
/// reports how long output has been awaited so the UI can say the run is
/// taking a while — a notice, not a failure. The user cancels if they want
/// to stop; nothing here decides that for them.
Stream<Out> watchdogged<In, Out>(
  Stream<In> source, {
  required Out? Function(In) extract,
  bool Function(In)? counts,
  void Function(SessionSlowNotice)? onSlow,
  Duration firstTimeout = kFirstFrameTimeout,
  Duration stallTimeout = kStallTimeout,
  Duration slowAfter = kSlowNotice,
  Duration slowTick = kSlowNoticeTick,
}) {
  final out = StreamController<Out>();
  StreamSubscription<In>? sub;
  Timer? watchdog;
  Timer? slowTimer;
  var sawElement = false;
  var sawOutput = false;
  final started = Stopwatch();
  // When the last frame of any kind arrived, which is what "the daemon is
  // still working" means — as opposed to output, which may lag far behind.
  var lastFrame = Duration.zero;

  void fail() {
    final waited = sawElement ? stallTimeout : firstTimeout;
    out.addError(
      SessionOpError(
        // UNAVAILABLE — the same code the daemon uses for a lost service, so
        // this renders through the existing "lost connection" copy.
        code: 3,
        message: sawElement
            ? 'The daemon stopped responding mid-answer '
                  '(nothing for ${waited.inMinutes} min).'
            : 'The daemon did not respond within ${waited.inMinutes} min.',
      ),
    );
    sub?.cancel();
    out.close();
  }

  void arm() {
    watchdog?.cancel();
    watchdog = Timer(sawElement ? stallTimeout : firstTimeout, fail);
  }

  void stopSlowNotices() {
    slowTimer?.cancel();
    slowTimer = null;
  }

  void emitSlow() {
    if (onSlow == null || sawOutput) return;
    onSlow(
      SessionSlowNotice(
        elapsed: started.elapsed,
        // Recent frames are the evidence. Allow a window rather than a
        // strict "since the last tick" so a run reporting every few
        // seconds doesn't flicker between active and not.
        active: started.elapsed - lastFrame < slowAfter,
      ),
    );
  }

  void startSlowNotices() {
    if (onSlow == null) return;
    stopSlowNotices();
    slowTimer = Timer(slowAfter, () {
      emitSlow();
      slowTimer = Timer.periodic(slowTick, (_) {
        if (sawOutput) {
          stopSlowNotices();
          return;
        }
        emitSlow();
      });
    });
  }

  out.onListen = () {
    started.start();
    arm();
    startSlowNotices();
    sub = source.listen(
      (e) {
        sawElement = true;
        lastFrame = started.elapsed;
        arm();
        // Real output ends the notices: once tokens flow the user can see
        // for themselves that it is working.
        if (counts?.call(e) ?? true) {
          sawOutput = true;
          stopSlowNotices();
        }
        final mapped = extract(e);
        if (mapped != null) out.add(mapped);
      },
      onError: (Object e, StackTrace st) {
        watchdog?.cancel();
        stopSlowNotices();
        out.addError(e, st);
        out.close();
      },
      onDone: () {
        watchdog?.cancel();
        stopSlowNotices();
        out.close();
      },
    );
  };
  out.onCancel = () async {
    watchdog?.cancel();
    stopSlowNotices();
    await sub?.cancel();
  };
  return out.stream;
}

/// An in-flight streaming operation: its token stream plus the server
/// operation id needed to [SessionClient.cancel] it.
///
/// The id is what makes a *real* stop possible — without it the client
/// can only drop its own subscription while the daemon keeps generating
/// into a channel nobody reads.
class SessionOperation {
  SessionOperation({
    required this.id,
    required this.tokens,
    this.events = const Stream<pb.InferenceEvent>.empty(),
    this.slow = const Stream<SessionSlowNotice>.empty(),
  });

  /// Server-side operation id, or null when the session was already
  /// closed and no frame was ever sent. Null means "nothing to cancel";
  /// callers must not substitute a placeholder, which would abort an
  /// unrelated operation.
  final int? id;

  final Stream<String> tokens;

  /// The daemon's running account of how this operation is being served —
  /// chain discovery, the pinned route, per-block peer dispatch.
  ///
  /// Empty unless the operation asked for events, and empty against a
  /// daemon too old to send them: proto3 drops the unknown request field
  /// silently, so "no events" and "not supported" look identical here and
  /// have to be told apart further up. Interleaved with [tokens] and
  /// closed by the same terminator.
  final Stream<pb.InferenceEvent> events;

  /// Periodic notices while the operation is slow to produce output.
  ///
  /// Not errors — the operation is still running, and on a distributed
  /// model a first token legitimately takes minutes. Emission starts after
  /// [kSlowNotice], repeats every [kSlowNoticeTick], and stops for good at
  /// the first token. Broadcast, so ignoring it is free.
  final Stream<SessionSlowNotice> slow;
}

/// An in-flight block-coverage subscription: its update stream plus the
/// server operation id needed to [SessionClient.cancel] it. Same id
/// semantics as [SessionOperation] — null means no frame was ever sent.
class BlockCoverageOperation {
  BlockCoverageOperation({required this.id, required this.updates});

  final int? id;
  final Stream<pb.BlockCoverageUpdate> updates;
}

/// An in-flight storage-discovery subscription: its update stream plus
/// the server operation id needed to [SessionClient.cancel] it. Same id
/// semantics as [SessionOperation] — null means no frame was ever sent.
class StorageDiscoveryOperation {
  StorageDiscoveryOperation({required this.id, required this.updates});

  final int? id;
  final Stream<pb.StorageUpdate> updates;
}

/// Thrown into a per-op stream when the server emits Error for that id.
class SessionOpError implements Exception {
  SessionOpError({required this.code, required this.message});
  final int code;
  final String message;
  @override
  String toString() => 'SessionOpError(code=$code, message=$message)';
}

/// Thrown into all in-flight per-op streams when the Session itself
/// ends (channel went away, server hung up, client closed).
class SessionEndedError implements Exception {
  SessionEndedError({required this.kind, required this.reason});
  final SessionEndKind kind;
  final String reason;
  @override
  String toString() => 'SessionEndedError(${kind.name}: $reason)';
}
