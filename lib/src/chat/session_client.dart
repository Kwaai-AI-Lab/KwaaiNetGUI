import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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

  // Writers waiting for the paused outbound stream to resume.
  Completer<void>? _writable;

  /// Opens the bidi stream if not already open. Idempotent.
  void ensureOpen() {
    if (_outbound != null || _closed) return;
    final out = StreamController<pb.ClientFrame>(
      onListen: _wakeWriters,
      onResume: _wakeWriters,
    );
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
        router.addError(
          SessionOpError(
            code: frame.error.code.value,
            message: frame.error.message,
          ),
        );
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
    _wakeWriters();
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
    final frames = _open(
      (id) => pb.ClientFrame()
        ..id = Int64(id)
        ..ping = pb.PingRequest(),
    );
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
    final frames = _open(
      (id) => pb.ClientFrame()
        ..id = Int64(id)
        ..status = pb.StatusRequest(),
    );
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

  /// `connect` — dial a peer we know of but hold no connection to.
  ///
  /// The daemon resolves the bare peer id through the DHT, so no address is
  /// needed. Returns the reply rather than throwing on a failed dial: "could
  /// not reach that peer" is an ordinary outcome here, not an error in the
  /// operation.
  Future<pb.ConnectReply> connect(String peerId) async {
    final frames = _open(
      (id) => pb.ClientFrame()
        ..id = Int64(id)
        ..connect = (pb.ConnectRequest()..peerId = peerId),
    );
    pb.ConnectReply? reply;
    await for (final f in frames) {
      if (f.whichBody() == pb.ServerFrame_Body.connect) {
        reply = f.connect;
      }
    }
    if (reply == null) {
      throw SessionOpError(code: 0, message: 'connect returned no reply');
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
  }) => _openOp(
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
  SessionOperation generateOp(String prompt, {String role = 'user'}) => _openOp(
    (id) => pb.ClientFrame()
      ..id = Int64(id)
      ..generate = (pb.GenerateRequest()
        ..role = role
        ..content = prompt),
  );

  /// `kwaainet shard chain` — one-shot block-coverage snapshot: which
  /// peers serve which blocks of the model, per the DHT.
  Future<pb.BlockCoverageUpdate> blockCoverage() async {
    final frames = _open(
      (id) => pb.ClientFrame()
        ..id = Int64(id)
        ..blockCoverage = pb.BlockCoverageRequest(),
    );
    pb.BlockCoverageUpdate? reply;
    await for (final f in frames) {
      if (f.whichBody() == pb.ServerFrame_Body.blockCoverage) {
        reply = f.blockCoverage;
      }
    }
    if (reply == null) {
      throw SessionOpError(
        code: 0,
        message: 'blockCoverage returned no update',
      );
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
    _outbound!.add(
      pb.ClientFrame()
        ..id = Int64(id)
        ..blockCoverage = (pb.BlockCoverageRequest()
          ..subscribe = true
          ..intervalSecs = intervalSecs),
    );
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
  /// block-coverage feed. [skipProbes] drops the dials and the second update.
  StorageDiscoveryOperation storageDiscoverySubscribe({
    int intervalSecs = 30,
    bool skipProbes = false,
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
    _outbound!.add(
      pb.ClientFrame()
        ..id = Int64(id)
        ..storageDiscovery = (pb.StorageDiscoveryRequest()
          ..subscribe = true
          ..intervalSecs = intervalSecs
          ..skipProbes = skipProbes),
    );
    // As with block coverage, no silence watchdog: a subscription is
    // legitimately quiet while the daemon's p2p layer comes up, and
    // session-end errors already propagate through the router.
    final updates = controller.stream
        .where((f) => f.whichBody() == pb.ServerFrame_Body.storage)
        .map((f) => f.storage);
    return StorageDiscoveryOperation(id: id, updates: updates);
  }

  /// Subscribe to local p2p state: connections, DHT routing table and this
  /// node's own reachability.
  ///
  /// Unlike the two subscriptions above, updates are not purely periodic — a
  /// reachability change is pushed as it happens. `NetworkUpdate.reason` says
  /// which it was, so a caller can react to a NAT transition immediately while
  /// treating peer-table churn as routine.
  ///
  /// Requires the daemon to be running the native p2p stack; otherwise the
  /// stream errors with SessionOpError(code=UNIMPLEMENTED).
  NetworkOperation networkSubscribe({int intervalSecs = 5}) {
    ensureOpen();
    if (_closed || _outbound == null) {
      return NetworkOperation(
        id: null,
        updates: Stream<pb.NetworkUpdate>.error(
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
    _outbound!.add(
      pb.ClientFrame()
        ..id = Int64(id)
        ..network = (pb.NetworkRequest()
          ..subscribe = true
          ..intervalSecs = intervalSecs),
    );
    // No silence watchdog, for the same reason as the other two: the daemon
    // heartbeats an unchanged snapshot, so genuine silence is already
    // distinguishable, and session-end errors propagate through the router.
    final updates = controller.stream
        .where((f) => f.whichBody() == pb.ServerFrame_Body.network)
        .map((f) => f.network);
    return NetworkOperation(id: id, updates: updates);
  }

  /// `dht_records` — one-shot listing of this node's own hivemind store.
  /// [includeValues] requires [keyIds]; the daemon rejects it otherwise.
  Future<pb.DhtRecordsReply> dhtRecords({
    bool includeValues = false,
    List<String> keyIds = const [],
  }) async {
    final frames = _open(
      (id) => pb.ClientFrame()
        ..id = Int64(id)
        ..dhtRecords = (pb.DhtRecordsRequest()
          ..includeValues = includeValues
          ..keyIds.addAll(keyIds)),
    );
    pb.DhtRecordsReply? reply;
    await for (final f in frames) {
      if (f.whichBody() == pb.ServerFrame_Body.dhtRecords) {
        reply = f.dhtRecords;
      }
    }
    if (reply == null) {
      throw SessionOpError(code: 0, message: 'dhtRecords returned no reply');
    }
    return reply;
  }

  /// `kwaainet rag status` — the knowledge bases this daemon holds.
  ///
  /// An empty `kbs` list means RAG is compiled in but nothing has been
  /// initialised yet. A daemon built without the `rag` feature answers
  /// UNIMPLEMENTED instead — and so does one too old to know the frame at
  /// all, since an unknown body is not a body it can act on. The two are
  /// indistinguishable on the wire and mean the same thing to a user, so
  /// callers treat both as "this daemon can't do RAG".
  Future<pb.RagStatusUpdate> ragStatus() async {
    final frames = _open(
      (id) => pb.ClientFrame()
        ..id = Int64(id)
        ..ragStatus = pb.RagStatusRequest(),
    );
    pb.RagStatusUpdate? reply;
    await for (final f in frames) {
      if (f.whichBody() == pb.ServerFrame_Body.ragStatus) {
        reply = f.ragStatus;
      }
    }
    if (reply == null) {
      throw SessionOpError(code: 0, message: 'ragStatus returned no update');
    }
    return reply;
  }

  /// `kwaainet rag init` — create a knowledge base.
  ///
  /// Empty [kb] means "default". Empty [embedModel] means the daemon's
  /// default for a new KB and the current model for an existing one, so the
  /// reply is what the KB actually became. Init on an existing KB keeps its
  /// documents.
  ///
  /// Errors with UNAVAILABLE when Ollama isn't reachable or the embedding
  /// model is missing, INVALID_ARGUMENT when [embedModel] would change the
  /// model of a KB holding documents, and UNIMPLEMENTED for a remote KB.
  /// Their messages are written for a user, so callers should show them.
  Future<pb.RagInitReply> ragInit({
    String kb = '',
    String embedModel = '',
  }) async {
    final frames = _open(
      (id) => pb.ClientFrame()
        ..id = Int64(id)
        ..ragInit = (pb.RagInitRequest()
          ..kb = kb
          ..embedModel = embedModel),
    );
    pb.RagInitReply? reply;
    await for (final f in frames) {
      if (f.whichBody() == pb.ServerFrame_Body.ragInit) {
        reply = f.ragInit;
      }
    }
    if (reply == null) {
      throw SessionOpError(code: 0, message: 'ragInit returned no reply');
    }
    return reply;
  }

  /// `kwaainet rag query` — retrieve chunks for [text].
  ///
  /// [topK] 0 means the server default (20) and [minScore] 0 keeps
  /// everything, so the defaults here send neither and let the daemon
  /// decide. Errors with NOT_FOUND when the KB was never initialised.
  Future<pb.RagQueryReply> ragQuery({
    required String text,
    String kb = '',
    int topK = 0,
    double minScore = 0,
  }) async {
    final frames = _open(
      (id) => pb.ClientFrame()
        ..id = Int64(id)
        ..ragQuery = (pb.RagQueryRequest()
          ..kb = kb
          ..text = text
          ..topK = topK
          ..minScore = minScore),
    );
    pb.RagQueryReply? reply;
    await for (final f in frames) {
      if (f.whichBody() == pb.ServerFrame_Body.ragQuery) {
        reply = f.ragQuery;
      }
    }
    if (reply == null) {
      throw SessionOpError(code: 0, message: 'ragQuery returned no reply');
    }
    return reply;
  }

  /// `kwaainet rag delete` — remove [docName] and every chunk it produced.
  ///
  /// [docName] is a `RagDoc.name` from `RagKb.documents`, not a path: the
  /// daemon deletes what it recorded at ingest, so a caller passes back
  /// what a status reply gave it.
  ///
  /// Errors with NOT_FOUND both when the KB was never initialised and when
  /// it simply doesn't hold that document — the daemon deliberately does
  /// not treat a missing document as a successful no-op, so a stale list
  /// row can't report a delete that never happened.
  Future<pb.RagDeleteReply> ragDelete({
    required String docName,
    String kb = '',
  }) async {
    final frames = _open(
      (id) => pb.ClientFrame()
        ..id = Int64(id)
        ..ragDelete = (pb.RagDeleteRequest()
          ..kb = kb
          ..docName = docName),
    );
    pb.RagDeleteReply? reply;
    await for (final f in frames) {
      if (f.whichBody() == pb.ServerFrame_Body.ragDelete) {
        reply = f.ragDelete;
      }
    }
    if (reply == null) {
      throw SessionOpError(code: 0, message: 'ragDelete returned no reply');
    }
    return reply;
  }

  /// `kwaainet rag ingest` — upload [file] into the KB, embedding as it goes.
  ///
  /// The bytes travel over the session: a RagIngest frame announcing
  /// [docName] (default: the file's basename, whose extension picks the
  /// daemon's parser) and the size, then the file as rag_ingest_data pieces
  /// of at most [pieceBytes] under the same id. The file is streamed, never
  /// held whole in memory: at most [maxUnackedPieces] pieces go unacknowledged
  /// by the daemon's per-piece RECEIVING progress before the read pauses.
  ///
  /// Unlike the other three ops this is long-running and reports as it
  /// works, so it returns an operation rather than a bare Future: progress
  /// frames arrive on [RagIngestOperation.progress] and the terminal reply
  /// completes [RagIngestOperation.done]. Both come off the same router, so
  /// a caller may ignore progress entirely and still get the reply. A read
  /// failure mid-upload cancels the op and completes [done] with that error.
  /// An empty file, or one over [kRagIngestMaxBytes], fails without sending.
  ///
  /// [maxUnackedPieces] exists for tests and may only lower the daemon's 8.
  RagIngestOperation ragIngest({
    required File file,
    String kb = '',
    String? docName,
    int pieceBytes = kRagIngestPieceBytes,
    int maxUnackedPieces = kRagIngestMaxUnackedPieces,
  }) {
    ensureOpen();
    if (_closed || _outbound == null) {
      final ended = SessionEndedError(
        kind: SessionEndKind.localClose,
        reason: 'session not open',
      );
      return _failedIngest(ended);
    }
    final int size;
    try {
      size = file.lengthSync();
    } on FileSystemException catch (e) {
      return _failedIngest(e);
    }
    if (size == 0) return _failedIngest(RagFileRejected('The file is empty.'));
    if (size > kRagIngestMaxBytes) {
      return _failedIngest(
        RagFileRejected('Files over 256 MB can\'t be added.'),
      );
    }
    final id = _nextId++;
    final controller = StreamController<pb.ServerFrame>();
    _routers[id] = controller;
    final out = _outbound!;
    out.add(
      pb.ClientFrame()
        ..id = Int64(id)
        ..ragIngest = (pb.RagIngestRequest()
          ..kb = kb
          ..docName = (docName == null || docName.isEmpty)
              ? _basename(file.path)
              : docName
          ..size = Int64(size)),
    );

    // One router feeding two consumers, as in [_openOp]: the router is
    // single-subscription so it cannot be listened to twice. A plain
    // controller (not broadcast) buffers until the caller subscribes, so
    // early progress on a fast local ingest isn't dropped in the gap
    // between this returning and the UI listening.
    final progress = StreamController<pb.RagProgress>();
    final done = Completer<pb.RagIngestReply>();

    // Pieces the daemon has acknowledged, one RECEIVING frame each, in order.
    var acked = 0;
    var cancelled = false;
    Completer<void>? ackWaiter;
    void wakeUploader() {
      final w = ackWaiter;
      ackWaiter = null;
      w?.complete();
    }

    controller.stream.listen(
      (f) {
        switch (f.whichBody()) {
          case pb.ServerFrame_Body.ragProgress:
            final p = f.ragProgress;
            if (p.phase == pb.RagProgress_RagPhase.RAG_PHASE_RECEIVING) {
              acked++;
              wakeUploader();
            }
            if (!progress.isClosed) progress.add(p);
          case pb.ServerFrame_Body.ragIngest:
            if (!done.isCompleted) done.complete(f.ragIngest);
          default:
            break;
        }
      },
      onError: (Object e, StackTrace st) {
        // The error goes to the Future, which is what a caller awaits;
        // progress merely closes. Sending it to both would surface the
        // same failure twice, and an unhandled error on a progress
        // stream nobody listened to would escape as an uncaught async
        // error.
        if (!done.isCompleted) done.completeError(e, st);
        if (!progress.isClosed) progress.close();
      },
      onDone: () {
        if (!progress.isClosed) progress.close();
        // Done without a terminal reply: the daemon ended the operation
        // without saying what it did. Better a clear error than a Future
        // that never settles and a spinner that never stops.
        if (!done.isCompleted) {
          done.completeError(
            SessionOpError(code: 0, message: 'ragIngest returned no reply'),
          );
        }
      },
    );

    // Stops on any end of the op: daemon reply/error, a cancel, or teardown.
    bool stopped() =>
        cancelled || done.isCompleted || !identical(_outbound, out);
    // Wake a window wait on any end too, so it can see stopped() and return.
    done.future.then(
      (_) => wakeUploader(),
      onError: (Object _) => wakeUploader(),
    );
    // Never above the daemon's buffer: a ninth unacked piece fails the ingest.
    final window = maxUnackedPieces.clamp(1, kRagIngestMaxUnackedPieces);
    Future<void> room(int sent) async {
      while (!stopped() && sent - acked >= window) {
        await (ackWaiter ??= Completer<void>()).future;
      }
    }

    unawaited(
      _uploadIngestData(
        id,
        out,
        file,
        size,
        pieceBytes,
        stopped,
        room,
      ).catchError((Object e, StackTrace st) {
        if (stopped()) return;
        done.completeError(e, st);
        if (!progress.isClosed) progress.close();
        // Tell the daemon to stop waiting for bytes that will never come.
        unawaited(cancel(id).catchError((Object _) {}));
      }),
    );

    return RagIngestOperation(
      id: id,
      progress: progress.stream,
      done: done.future,
      onCancel: () async {
        if (cancelled || done.isCompleted) return;
        // Stop sending now; [done] settles with the daemon's CANCELLED.
        cancelled = true;
        wakeUploader();
        await cancel(id);
      },
    );
  }

  RagIngestOperation _failedIngest(Object error) => RagIngestOperation(
    id: null,
    progress: const Stream<pb.RagProgress>.empty(),
    done: Future<pb.RagIngestReply>.error(error),
  );

  /// Send [file] as rag_ingest_data frames under [id], pausing the read until
  /// [room] admits each piece. Throws if the read fails or the file's length
  /// no longer matches the announced [size].
  Future<void> _uploadIngestData(
    int id,
    StreamController<pb.ClientFrame> out,
    File file,
    int size,
    int pieceBytes,
    bool Function() stopped,
    Future<void> Function(int sentPieces) room,
  ) async {
    var sent = 0;
    var pieces = 0;
    // Leaving the loop early cancels openRead's subscription: the read stops.
    await for (final piece in ragPieces(file.openRead(), pieceBytes)) {
      await room(pieces);
      if (stopped()) return;
      sent += piece.length;
      if (sent > size) {
        throw FileSystemException('file grew during upload', file.path);
      }
      out.add(
        pb.ClientFrame()
          ..id = Int64(id)
          ..ragIngestData = (pb.RagIngestData()..data = piece),
      );
      pieces++;
      await _outboundWritable();
    }
    if (!stopped() && sent != size) {
      throw FileSystemException('file shrank during upload', file.path);
    }
  }

  /// Completes once the outbound stream can take more: on resume while it is
  /// paused (e.g. the rpc not yet listening), else after one event-loop turn.
  Future<void> _outboundWritable() {
    final out = _outbound;
    if (out == null || !out.isPaused) {
      return Future<void>.delayed(Duration.zero);
    }
    return (_writable ??= Completer<void>()).future;
  }

  void _wakeWriters() {
    final w = _writable;
    _writable = null;
    w?.complete();
  }

  /// Cancel an in-flight operation. The target operation's stream will
  /// error with SessionOpError(code=CANCELLED).
  Future<void> cancel(int operationId) async {
    final frames = _open(
      (id) => pb.ClientFrame()
        ..id = Int64(id)
        ..cancel = (pb.Cancel()..targetId = Int64(operationId)),
    );
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
        tokens: _tokensFromFrames(
          controller.stream,
          onSlow: emitSlow,
        ).transform(_closeOnDone(slow)),
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
    final tee = controller.stream.listen(
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
    // The token side ending (stop, watchdog, done) ends the run: release
    // the router and close events, or the panel waits on a wedged daemon.
    frames.onCancel = () {
      tee.cancel();
      if (!events.isClosed) events.close();
    };

    return SessionOperation(
      id: id,
      tokens: _tokensFromFrames(
        frames.stream,
        onSlow: emitSlow,
      ).transform(_closeOnDone(slow)),
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

/// Size of each rag_ingest_data piece; well under the daemon's 4 MiB frame cap.
const kRagIngestPieceBytes = 256 * 1024;

/// Most upload pieces in flight unacknowledged: the daemon buffers 8, and a
/// ninth fails the ingest. grpc-dart hides HTTP/2 flow control, so this also
/// bounds memory.
const kRagIngestMaxUnackedPieces = 8;

/// Largest document the daemon accepts.
const kRagIngestMaxBytes = 256 * 1024 * 1024;

/// Regroup [source]'s chunks into pieces of exactly [size] bytes (the last
/// may be shorter). Pull-driven: the source pauses while a piece is pending.
Stream<Uint8List> ragPieces(Stream<List<int>> source, int size) async* {
  final buf = BytesBuilder(copy: false);
  await for (final chunk in source) {
    buf.add(chunk);
    if (buf.length < size) continue;
    final bytes = buf.takeBytes();
    var off = 0;
    for (; off + size <= bytes.length; off += size) {
      yield Uint8List.sublistView(bytes, off, off + size);
    }
    if (off < bytes.length) buf.add(Uint8List.sublistView(bytes, off));
  }
  if (buf.isNotEmpty) yield buf.takeBytes();
}

String _basename(String path) => path.split(RegExp(r'[/\\]')).last;

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

/// An in-flight network subscription: its update stream plus the server
/// operation id needed to [SessionClient.cancel] it. Same id semantics as
/// [SessionOperation] — null means no frame was ever sent.
class NetworkOperation {
  NetworkOperation({required this.id, required this.updates});

  final int? id;
  final Stream<pb.NetworkUpdate> updates;
}

/// An in-flight RAG ingest: its progress feed, the terminal reply, and the
/// server operation id needed to [SessionClient.cancel] it. Same id
/// semantics as [SessionOperation] — null means no frame was ever sent.
///
/// Unlike the subscription operations this exposes a Future as well as a
/// Stream, because an ingest has a definite result (how much was stored)
/// rather than running until cancelled. [progress] is optional detail;
/// [done] is the outcome and carries any error.
class RagIngestOperation {
  RagIngestOperation({
    required this.id,
    required this.progress,
    required this.done,
    this.onCancel,
  });

  final int? id;

  /// What [cancel] runs; null for an op that never sent anything.
  final Future<void> Function()? onCancel;

  /// Stop uploading and send a Cancel for [id]; [done] then fails CANCELLED.
  Future<void> cancel() async => onCancel?.call();

  /// Phase/counter updates while the ingest runs. Closes when the
  /// operation ends, however it ends. Safe to ignore.
  final Stream<pb.RagProgress> progress;

  /// Chunks stored and vectors uploaded, or an error — including
  /// SessionOpError(code=UNAVAILABLE) when Ollama went away mid-ingest.
  final Future<pb.RagIngestReply> done;
}

/// A file the daemon would refuse, rejected before anything is sent.
class RagFileRejected implements Exception {
  RagFileRejected(this.message);

  final String message;

  @override
  String toString() => message;
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
