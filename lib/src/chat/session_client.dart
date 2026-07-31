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
  Stream<String> shardRun(String prompt, {String role = 'user'}) {
    return _tokensFromFrames(_open((id) => pb.ClientFrame()
      ..id = Int64(id)
      ..shardRun = (pb.ShardRunRequest()
        ..role = role
        ..content = prompt)));
  }

  /// `kwaainet generate <PROMPT>` — single-node local inference. Used
  /// by the Developer tab to drive the local InferenceEngine directly.
  Stream<String> generate(String prompt, {String role = 'user'}) {
    return _tokensFromFrames(_open((id) => pb.ClientFrame()
      ..id = Int64(id)
      ..generate = (pb.GenerateRequest()
        ..role = role
        ..content = prompt)));
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

  Stream<String> _tokensFromFrames(Stream<pb.ServerFrame> frames) {
    return watchdogged<pb.ServerFrame, String>(
      frames,
      extract: (f) {
        if (f.whichBody() != pb.ServerFrame_Body.token) return null;
        final t = f.token;
        return t.text.isEmpty ? null : t.text;
      },
    );
  }

  /// Allocate an id, build the ClientFrame, send it, register a router,
  /// return the per-id stream.
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
/// request dead. Generous: the daemon may still be loading a model, resolving
/// peers, or queueing behind another request.
const kFirstFrameTimeout = Duration(seconds: 90);

/// How long to tolerate silence *after* the stream has started producing.
/// Once tokens are flowing a long gap means the far end stopped — a healthy
/// generation does not pause this long between tokens.
const kStallTimeout = Duration(seconds: 45);

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
/// The deadline is [kFirstFrameTimeout] until the first element arrives and
/// [kStallTimeout] thereafter — "never started" and "stopped mid-answer"
/// warrant different patience.
Stream<Out> watchdogged<In, Out>(
  Stream<In> source, {
  required Out? Function(In) extract,
  Duration firstTimeout = kFirstFrameTimeout,
  Duration stallTimeout = kStallTimeout,
}) {
  final out = StreamController<Out>();
  StreamSubscription<In>? sub;
  Timer? watchdog;
  var sawElement = false;

  void fail() {
    final waited = sawElement ? stallTimeout : firstTimeout;
    out.addError(
      SessionOpError(
        // UNAVAILABLE — the same code the daemon uses for a lost service, so
        // this renders through the existing "lost connection" copy.
        code: 3,
        message: sawElement
            ? 'The daemon stopped responding mid-answer '
                  '(no data for ${waited.inSeconds}s).'
            : 'The daemon did not respond within ${waited.inSeconds}s.',
      ),
    );
    sub?.cancel();
    out.close();
  }

  void arm() {
    watchdog?.cancel();
    watchdog = Timer(sawElement ? stallTimeout : firstTimeout, fail);
  }

  out.onListen = () {
    arm();
    sub = source.listen(
      (e) {
        sawElement = true;
        arm();
        final mapped = extract(e);
        if (mapped != null) out.add(mapped);
      },
      onError: (Object e, StackTrace st) {
        watchdog?.cancel();
        out.addError(e, st);
        out.close();
      },
      onDone: () {
        watchdog?.cancel();
        out.close();
      },
    );
  };
  out.onCancel = () async {
    watchdog?.cancel();
    await sub?.cancel();
  };
  return out.stream;
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
