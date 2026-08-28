import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart';

import '../daemon/paths.dart';
import 'generated/kwaai.pb.dart' as pb;
import 'generated/kwaai.pbgrpc.dart' as pbgrpc;
import 'session_client.dart';

void _log(String msg) {
  stderr.writeln('[rpc] $msg');
}

/// Default TCP port the daemon binds — mirrors
/// `kwaai_cli::grpc_server::DEFAULT_GRPC_TCP_PORT` on the Rust side.
const int kDefaultGrpcPort = 8093;

/// Environment variable naming the port to reach the daemon on.
const String kGrpcPortEnvVar = 'KWAAINET_GRPC_PORT';

/// Longest usable Unix socket path. macOS caps `sun_path` at 104 bytes
/// including the terminator; Linux is 108. Take the smaller.
const int kMaxUnixSocketPathBytes = 103;

/// TCP port naming a daemon this app does *not* manage, from
/// [kGrpcPortEnvVar]. Null when no override is set.
///
/// This is only for the case where the daemon isn't local: kwaaiai-env's NAT
/// test topology publishes each containerised node's gRPC on its own host
/// port, and pointing the GUI at one is how you inspect that node's swarm
/// state. The port of a daemon *this* app started is instance state, not an
/// environment constant — see [NodeStatus.grpcPort].
int? get envGrpcPort => grpcPortOverridden
    ? parseGrpcPort(Platform.environment[kGrpcPortEnvVar])
    : null;

/// Whether the daemon we talk to is one this app does not manage.
///
/// Load-bearing on POSIX, where the client prefers the Unix socket and only
/// falls back to TCP: a local daemon's socket would otherwise always win and
/// the port override would silently do nothing. Setting the port means "talk
/// to *that* daemon", so it has to skip the socket.
///
/// Deliberately NOT true merely because a locally-spawned daemon is on a
/// non-default port. Every caller is asking "is this daemon foreign?", and a
/// sandboxed instance's own daemon is not.
bool get grpcPortOverridden =>
    isGrpcPortOverridden(Platform.environment[kGrpcPortEnvVar]);

/// [raw] as a port, or [kDefaultGrpcPort] if it is absent or unusable.
///
/// Falls back rather than throwing: a typo should not take out every RPC in
/// the app, including against a local daemon that is running perfectly well.
/// The log line says which port was actually used, so a silent fallback is
/// still traceable.
///
/// Split from [grpcPort] so it is testable — Dart cannot mutate
/// `Platform.environment` in-process.
int parseGrpcPort(String? raw) {
  if (raw == null || raw.isEmpty) return kDefaultGrpcPort;
  final parsed = int.tryParse(raw.trim());
  // 0 is "any port" when binding but meaningless when connecting, so it is
  // rejected alongside genuinely out-of-range values.
  if (parsed == null || parsed < 1 || parsed > 65535) {
    _log('ignoring invalid $kGrpcPortEnvVar="$raw"');
    return kDefaultGrpcPort;
  }
  return parsed;
}

/// Whether [raw] represents a deliberate override.
///
/// True even when [parseGrpcPort] rejects the value: the user asked for a
/// non-local daemon, so silently answering from the *local Unix socket* would
/// be a worse response to a typo than falling back to the default TCP port,
/// which at least keeps the transport they asked for.
bool isGrpcPortOverridden(String? raw) => raw != null && raw.isNotEmpty;

/// High-level connection state the GUI gates UI on. The grpc-dart
/// package's own ConnectionState has more states (idle vs ready vs
/// transientFailure); collapsing them down keeps callers from caring
/// about the difference between "haven't tried yet" and "trying now".
enum RpcConnection {
  /// We're attempting to open or re-open the channel.
  connecting,

  /// The channel reached `ready` and a probe call has succeeded.
  connected,

  /// No usable channel right now (daemon down, socket gone, refused).
  disconnected,
}

/// Thin wrapper around the daemon's gRPC `KwaaiNet` service. Maintains
/// a single channel + a state stream so the rest of the app can gate
/// UI on real connectivity (not just whether the daemon's PID is
/// alive — those can diverge during startup, restart, or when the
/// daemon's been killed but the listener socket is stale).
///
/// Transport selection: prefer the daemon's Unix socket when it exists
/// (no port collisions, FS-level ACL), fall back to loopback TCP.
class KwaaiRpcClient {
  KwaaiRpcClient() {
    // Start the keep-alive probe loop straight away so the connection
    // state stream has a value to publish before anyone subscribes.
    _startProbeLoop();
  }

  ClientChannel? _channel;
  pbgrpc.KwaaiNetClient? _stub;
  SessionClient? _session;

  /// Human-readable transport descriptor for the currently-open channel,
  /// remembered so close/error logs can name what we just lost.
  String? _connectionPath;

  Timer? _probeTimer;
  RpcConnection _lastState = RpcConnection.connecting;
  bool _probingEnabled = true;

  /// True while a probe is in flight. Serialises probes so a periodic
  /// tick can't fire a second `session.ping()` while the previous one
  /// is still inside its 2s timeout — that overlap can wedge
  /// grpc-dart's channel state machine when the daemon goes away.
  bool _probeInFlight = false;

  /// Resolves when a channel-shutdown sequence (begun by
  /// [_resetChannel] or [setProbingEnabled(false)]) finishes.
  /// `_probe` awaits this before reopening so we never have an old
  /// channel mid-shutdown while a new one is being dialed.
  Future<void>? _pendingReset;

  final _stateController = StreamController<RpcConnection>.broadcast();

  /// Broadcasts the *current* high-level connection state. Late
  /// subscribers immediately receive the most recent value.
  Stream<RpcConnection> get connectionState async* {
    yield _lastState;
    yield* _stateController.stream;
  }

  // ---------------------------------------------------------------------
  // Probe loop — re-checks connectivity every few seconds even when no
  // chat is in flight, so the UI knows to re-enable as soon as the
  // daemon comes back up (and to disable when it goes away).
  // ---------------------------------------------------------------------

  static const _probeInterval = Duration(seconds: 3);

  void _startProbeLoop() {
    // Fire the first probe immediately so initial UI doesn't spend
    // _probeInterval seconds in "connecting".
    scheduleMicrotask(_probe);
    _probeTimer = Timer.periodic(_probeInterval, (_) => _probe());
  }

  /// Toggle the periodic Ping probe. Used by the GUI to suppress probes
  /// while the daemon is known-stopped (no point spamming connect-refused
  /// every 3 s when we already know there's no listener). Re-enable as
  /// soon as the daemon starts so the channel comes up promptly.
  void setProbingEnabled(bool enabled) {
    if (enabled == _probingEnabled) return;
    _probingEnabled = enabled;
    if (enabled) {
      // Fire one probe immediately so the UI doesn't wait for the next
      // periodic tick to learn the daemon is reachable.
      scheduleMicrotask(_probe);
    } else {
      // Drop any cached channel so we don't sit on a closed socket; the
      // next enabled probe will open a fresh one. Track the in-flight
      // shutdown so a concurrent probe waits for it instead of racing.
      _publish(RpcConnection.disconnected);
      // No channel to tear down? Don't even create a future — bare
      // setProbingEnabled(false) at startup (before any probe has
      // opened anything) would otherwise stash a future whose only
      // wait point is grpc-dart's shutdown of a never-opened channel,
      // which can stall and deadlock every subsequent probe behind it.
      if (_channel != null) {
        _pendingReset = _resetChannel(silent: true);
      }
    }
  }

  Future<void> _probe() async {
    if (!_probingEnabled) return;
    if (_probeInFlight) return; // a previous probe is still running
    // If we already have a stub and the underlying connection is
    // happy, skip — connection state changes only happen on
    // teardown or via the probe itself.
    if (_stub != null && _lastState == RpcConnection.connected) return;
    _probeInFlight = true;
    try {
      // Wait for any in-flight channel teardown to complete before
      // opening a new one — overlapping shutdown + dial wedges
      // grpc-dart's connection state machine. Bounded: a stuck
      // shutdown must never permanently block the probe loop, so
      // we cap the wait and proceed regardless.
      final pending = _pendingReset;
      if (pending != null) {
        await pending.timeout(const Duration(seconds: 1), onTimeout: () {});
        _pendingReset = null;
      }
      final session = await _sessionOrInit();
      await session.ping().timeout(const Duration(seconds: 2));
      _publish(RpcConnection.connected);
    } catch (_) {
      _publish(RpcConnection.disconnected);
      // Drop the dead channel so the next probe tries a fresh
      // _openChannel — important when the daemon was restarted and
      // the unix socket inode changed. Track the shutdown so the
      // *next* probe waits for it.
      _pendingReset = _resetChannel(silent: true);
    } finally {
      _probeInFlight = false;
    }
  }

  void _publish(RpcConnection s) {
    if (s == _lastState) return;
    _lastState = s;
    _stateController.add(s);
    _log('state → ${s.name}');
  }

  // ---------------------------------------------------------------------
  // Channel management
  // ---------------------------------------------------------------------

  Future<pbgrpc.KwaaiNetClient> _client() async {
    final existing = _stub;
    if (existing != null) return existing;

    final channel = await _openChannel();
    _channel = channel;
    // Intentionally NOT subscribing to channel.onConnectionStateChanged
    // here: the channel transitions through connecting/transientFailure
    // on routine HTTP/2 housekeeping (idle timeouts, keep-alives) and
    // overriding our probe's "connected" verdict with those flickers
    // produces a connecting/disconnected loop in the UI even when
    // pings are succeeding. The periodic ping probe is the only
    // source of truth.
    final stub = pbgrpc.KwaaiNetClient(channel);
    _stub = stub;
    return stub;
  }

  /// Lazily build (or reuse) the [SessionClient] backed by the current
  /// stub. The session owns one bidi rpc; every operation (ping, chat,
  /// status, …) multiplexes through it.
  Future<SessionClient> _sessionOrInit() async {
    final existing = _session;
    if (existing != null) return existing;
    final s = SessionClient(await _client());
    _session = s;
    return s;
  }

  Future<ClientChannel> _openChannel() async {
    // An explicit port names a specific daemon, so the Unix socket must not
    // pre-empt it — that socket belongs to whatever is running locally, which
    // is precisely what the override exists to bypass.
    if ((Platform.isMacOS || Platform.isLinux) && !grpcPortOverridden) {
      final sockPath = unixSocketPath;
      // sun_path is 104 bytes on macOS. A deep checkout can push a sandboxed
      // socket past it, and the daemon's bind then fails — say so, rather than
      // letting the TCP fallback look like "the daemon isn't up yet".
      if (utf8.encode(sockPath).length > kMaxUnixSocketPathBytes) {
        _log('socket path too long for this platform, using TCP: $sockPath');
      } else if (await File(sockPath).exists()) {
        _connectionPath = 'unix://$sockPath';
        _log('opening Unix socket: $sockPath');
        return ClientChannel(
          InternetAddress(sockPath, type: InternetAddressType.unix),
          port: 0,
          options: const ChannelOptions(
            credentials: ChannelCredentials.insecure(),
          ),
        );
      } else {
        _log('Unix socket not found, falling back to TCP');
      }
    }
    final port = _tcpPort;
    _connectionPath = 'tcp://127.0.0.1:$port';
    _log('opening TCP: 127.0.0.1:$port');
    return ClientChannel(
      '127.0.0.1',
      port: port,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );
  }

  // ---------------------------------------------------------------------
  // Chat
  // ---------------------------------------------------------------------

  /// Default chat path. Maps to `kwaainet shard run <prompt>` — runs
  /// inference distributed across the discovered block-server mesh.
  /// Yields each token's text as it arrives; completes when the daemon
  /// emits Done. Stream errors on operation-level failures (e.g.
  /// SessionOpError) or on session/channel teardown.
  Stream<String> chatStream(String prompt) async* {
    final session = await _sessionOrInit();
    try {
      yield* session.shardRun(prompt);
    } catch (e) {
      // A session-level failure (channel drop, server hang-up) means
      // the cached session + channel are useless; flush them so the
      // next call reopens.
      await _resetChannel();
      rethrow;
    }
  }

  /// As [chatStream], but reports the daemon-side operation id through
  /// [onOperationId] as soon as the request frame goes out, so the
  /// caller can [cancelOperation] it mid-flight.
  ///
  /// The id arrives via callback rather than as a return value because
  /// the session has to be opened asynchronously first — a caller
  /// awaiting an id before subscribing would deadlock, since the
  /// request isn't sent until the stream is listened to.
  Stream<String> chatStreamCancellable(
    String prompt, {
    required void Function(int? operationId) onOperationId,
  }) async* {
    final session = await _sessionOrInit();
    final op = session.shardRunOp(prompt);
    onOperationId(op.id);
    try {
      yield* op.tokens;
    } catch (e) {
      await _resetChannel();
      rethrow;
    }
  }

  /// As [generateLocal], with the operation id reported for cancellation.
  Stream<String> generateLocalCancellable(
    String prompt, {
    required void Function(int? operationId) onOperationId,
  }) async* {
    final session = await _sessionOrInit();
    final op = session.generateOp(prompt);
    onOperationId(op.id);
    try {
      yield* op.tokens;
    } catch (e) {
      await _resetChannel();
      rethrow;
    }
  }

  /// Ask the daemon to abort an in-flight operation. Best-effort: the
  /// stream is torn down locally regardless, so a failure to deliver
  /// the Cancel frame must not surface as a user-facing error.
  Future<void> cancelOperation(int operationId) async {
    try {
      final session = _session;
      if (session == null) return;
      await session.cancel(operationId);
    } catch (e) {
      // Nothing actionable: the user already sees generation stopped.
      _log('cancel of op $operationId failed (ignored): $e');
    }
  }

  /// Single-node local inference. Maps to `kwaainet generate <prompt>`
  /// — used by the Developer tab for direct fallback / dev runs
  /// against the local InferenceEngine.
  Stream<String> generateLocal(String prompt) async* {
    final session = await _sessionOrInit();
    try {
      yield* session.generate(prompt);
    } catch (e) {
      await _resetChannel();
      rethrow;
    }
  }

  /// Live model block-coverage feed. The daemon pushes one update per
  /// [intervalSecs]; the daemon-side operation is cancelled when the
  /// listener unsubscribes. Errors on session/channel teardown — callers
  /// (the coverage provider) resubscribe when connectivity returns, so
  /// like [daemonVersion] this doesn't reset the channel itself.
  Stream<pb.BlockCoverageUpdate> blockCoverageStream({
    int intervalSecs = 5,
  }) async* {
    final session = await _sessionOrInit();
    final op = session.blockCoverageSubscribe(intervalSecs: intervalSecs);
    try {
      yield* op.updates;
    } finally {
      final id = op.id;
      if (id != null) {
        await cancelOperation(id);
      }
    }
  }

  /// Live VPK storage-node feed. The daemon runs a discovery round every
  /// [intervalSecs], each pushing two updates (registry, then resolved
  /// reachability); the daemon-side operation is cancelled when the
  /// listener unsubscribes. Errors on session/channel teardown — the
  /// storage provider resubscribes when connectivity returns, so like
  /// [blockCoverageStream] this doesn't reset the channel itself.
  Stream<pb.StorageUpdate> storageDiscoveryStream({
    int intervalSecs = 30,
  }) async* {
    final session = await _sessionOrInit();
    final op = session.storageDiscoverySubscribe(intervalSecs: intervalSecs);
    try {
      yield* op.updates;
    } finally {
      final id = op.id;
      if (id != null) {
        await cancelOperation(id);
      }
    }
  }

  /// Live local-p2p feed: connections, DHT routing table and this node's own
  /// reachability. The daemon samples every [intervalSecs] and additionally
  /// pushes immediately on a reachability change; the daemon-side operation is
  /// cancelled when the listener unsubscribes.
  ///
  /// Errors with SessionOpError(code=UNIMPLEMENTED) when the daemon is running
  /// the Go p2p stack, which cannot supply this view. As with the two streams
  /// above, this doesn't reset the channel — the provider resubscribes when
  /// connectivity returns.
  Stream<pb.NetworkUpdate> networkStream({int intervalSecs = 5}) async* {
    final session = await _sessionOrInit();
    final op = session.networkSubscribe(intervalSecs: intervalSecs);
    try {
      yield* op.updates;
    } finally {
      final id = op.id;
      if (id != null) {
        await cancelOperation(id);
      }
    }
  }

  /// Version of the *running* daemon, read from `StatusReply.version`.
  ///
  /// Returns null when the daemon isn't reachable, or when it predates the
  /// field (proto3 decodes the absent field as ""). Null means "the running
  /// daemon did not tell us" and is reported as such — callers must not
  /// substitute an on-disk reading, which describes a binary that may not be
  /// the running process.
  ///
  /// Unlike [chatStream] this doesn't reset the channel on failure — an
  /// unreachable daemon is the normal stopped case, not a sign the cached
  /// channel has gone bad, and the probe loop already owns reconnection.
  Future<String?> daemonVersion() async {
    try {
      final session = await _sessionOrInit();
      final reply = await session.status().timeout(const Duration(seconds: 2));
      return reply.version.isEmpty ? null : reply.version;
    } catch (e) {
      _log('daemonVersion failed: $e');
      return null;
    }
  }

  /// Dial a peer by id, resolving its address through the DHT.
  ///
  /// Returns null when the session itself could not be reached; otherwise the
  /// daemon's reply, whose `error` carries a failed dial.
  Future<pb.ConnectReply?> connectPeer(String peerId) async {
    try {
      final session = await _sessionOrInit();
      return await session.connect(peerId).timeout(const Duration(seconds: 30));
    } catch (e) {
      _log('connectPeer($peerId) failed: $e');
      return null;
    }
  }

  /// The transport the current channel uses, or null when there is none.
  /// Exposed so tests can assert that changing [tcpPort] drops the channel —
  /// without that, the probe keeps dialling a port the daemon has left.
  @visibleForTesting
  String? get debugConnectionPath => _connectionPath;

  Future<void> _resetChannel({bool silent = false}) async {
    final ch = _channel;
    final path = _connectionPath;
    final s = _session;
    _channel = null;
    _stub = null;
    _session = null;
    _connectionPath = null;
    if (s != null) {
      await s.close();
    }
    if (ch != null) {
      if (!silent) _log('connection closed (${path ?? "unknown"})');
      try {
        await ch.shutdown();
      } catch (_) {}
    }
  }

  /// Seeded from [envGrpcPort] so a foreign daemon named on the environment
  /// is still dialled where it lives — nothing updates this port in that case,
  /// because the status stream describes a daemon on this host and that one
  /// is somewhere else.
  int _tcpPort = envGrpcPort ?? kDefaultGrpcPort;

  /// The TCP port to dial when the Unix socket isn't used.
  ///
  /// Instance state, not a constant: a daemon this app spawned takes a port we
  /// allocated, and it changes across a restart. Resetting the channel is the
  /// point — without it the probe keeps pinging the dead port forever, because
  /// [_probe] short-circuits on the channel it already has.
  set tcpPort(int value) {
    if (value == _tcpPort) return;
    _log('gRPC TCP port $_tcpPort → $value, resetting channel');
    _tcpPort = value;
    unawaited(_resetChannel(silent: true));
  }

  /// Best-effort Unix socket path matching the daemon's bind location
  /// (`kwaai_cli::grpc_server::unix_socket_path` on the Rust side).
  static String get unixSocketPath =>
      '${KwaainetPaths.runDir}${Platform.pathSeparator}kwaai.sock';

  Future<void> close() async {
    _probeTimer?.cancel();
    _probeTimer = null;
    await _resetChannel(silent: true);
    await _stateController.close();
  }
}

final kwaaiRpcClientProvider = Provider<KwaaiRpcClient>((ref) {
  final client = KwaaiRpcClient();
  ref.onDispose(client.close);
  return client;
});

/// Live connection state — drives the main page's enable/disable.
final kwaaiRpcConnectionProvider = StreamProvider<RpcConnection>((ref) {
  return ref.watch(kwaaiRpcClientProvider).connectionState;
});
