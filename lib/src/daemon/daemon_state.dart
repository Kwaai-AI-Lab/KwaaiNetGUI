import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat/kwaai_rpc_client.dart';
import '../settings.dart';
import 'daemon_controller.dart';
import 'paths.dart';
import 'status_watcher.dart';

void _log(String msg) {
  stderr.writeln('[daemon-state] $msg');
}

/// Transient daemon lifecycle phase, tracked UI-side. The daemon's
/// [NodeStatus] only reports running/stopped — "starting"/"stopping" is the
/// gap between issuing a command and the watcher confirming the new state.
enum DaemonTransition { none, starting, stopping }

/// One-line error message surfaced when start/stop fails. Null when no error
/// is current.
typedef DaemonError = String?;

/// The single [DaemonController] instance. Provided by overriding this in the
/// [ProviderScope] at app start.
final daemonControllerProvider = Provider<DaemonController>((ref) {
  throw UnimplementedError(
    'daemonControllerProvider must be overridden with the app-wide '
    'DaemonController instance via ProviderScope.overrides.',
  );
});

/// The single [StatusWatcher] instance. Provided by overriding this in the
/// [ProviderScope] at app start.
final statusWatcherProvider = Provider<StatusWatcher>((ref) {
  throw UnimplementedError(
    'statusWatcherProvider must be overridden with the app-wide '
    'StatusWatcher instance via ProviderScope.overrides.',
  );
});

/// Live daemon status stream. Updates whenever the [StatusWatcher] emits.
final daemonStatusProvider = StreamProvider<NodeStatus>((ref) {
  return ref.watch(statusWatcherProvider).stream;
});

/// Whether a daemon is available to serve the data-bearing tabs.
///
/// Not the same question as [daemonStatusProvider]'s `running`, which is a
/// *local* fact: it reads this machine's PID file and status JSON. That is the
/// right check for the daemon this app manages, and the wrong one entirely
/// when [kGrpcPortEnvVar] names a daemon somewhere else — a containerised node
/// in the NAT test topology has no PID on this host, so every tab would report
/// "not running" while happily streaming its data.
///
/// With an explicit port the local PID is moot, so reachability is the honest
/// signal: the gRPC connection either stands up or it does not. This mirrors
/// `_openChannel`, which skips the Unix socket for the same reason.
final daemonAvailableProvider = Provider<bool>((ref) {
  if (grpcPortOverridden) {
    return ref.watch(kwaaiRpcConnectionProvider).valueOrNull ==
        RpcConnection.connected;
  }
  return ref.watch(daemonStatusProvider).valueOrNull?.running ?? false;
});

/// Version of the binary a *specific* [DaemonMode] resolves to, independent
/// of which mode is currently selected — so the settings picker can label
/// every option without the user having to select it first.
///
/// Always the on-disk `--version` probe: these describe candidate binaries,
/// not the running process. The running daemon's own version is
/// [daemonVersionProvider], which is shown separately.
final binaryVersionForModeProvider = FutureProvider.family<String?, DaemonMode>(
  (ref, mode) => ref.watch(daemonControllerProvider).binaryVersion(mode),
);

/// Version of the *running* daemon, from its own `StatusReply.version` over
/// gRPC — or null whenever no daemon-sourced answer exists (stopped, still
/// binding its socket, unreachable).
///
/// This is the honest answer whenever the running process differs from the
/// binary on disk: after an in-place upgrade, or when the location setting
/// was changed without a restart.
///
/// Null is meaningful, not merely "unknown": it tells the UI that the daemon
/// has not spoken, so the binary-location rows should keep showing their
/// on-disk versions ([binaryVersionForModeProvider]). Returning a disk-based
/// guess here instead would make the two indistinguishable and cause the
/// selected row to blink out mid-start.
final daemonVersionProvider = FutureProvider<String?>((ref) async {
  // Re-resolve whenever the daemon starts or stops so the displayed version
  // follows the daemon across a restart rather than going stale.
  final running = ref.watch(daemonStatusProvider).valueOrNull?.running ?? false;

  // …and again when the RPC channel itself becomes usable. `running` flips as
  // soon as the *process* exists, but the daemon binds its gRPC socket a
  // moment later; asking in that window fails. Without this the failed answer
  // would be cached until the next start/stop, leaving the version blank for
  // the daemon's whole lifetime. Watching connection state re-runs the probe
  // once the socket is actually up.
  final connected =
      ref.watch(kwaaiRpcConnectionProvider).valueOrNull ==
      RpcConnection.connected;

  if (running && connected) {
    // Whatever the daemon says — including null for a daemon older than
    // StatusReply.version. Deliberately NOT falling back to an on-disk probe
    // here: this value is presented as "the version of the process that is
    // running", and the binary the location setting points at is not
    // necessarily that process (the setting can be changed without a
    // restart). A disk reading shown in that slot is indistinguishable from
    // the daemon's own answer and quietly asserts something untrue.
    return ref.watch(kwaaiRpcClientProvider).daemonVersion();
  }

  // Not reachable → no daemon-sourced answer exists. Null rather than a disk
  // fallback, for the same reason: callers distinguish "the daemon said so"
  // from "we read a file", and the binary-location rows already show the
  // latter.
  return null;
});

/// The current transition phase (none/starting/stopping). Exposes start()
/// and stop() that drive both the daemon and this provider's state, and
/// auto-clear once the [daemonStatusProvider] confirms the target.
class DaemonTransitionNotifier extends Notifier<DaemonTransition> {
  DaemonError _lastError;

  /// Latest error message from a failed start/stop, or null. Consumers can
  /// watch [daemonErrorProvider] to read this reactively.
  DaemonError get lastError => _lastError;

  @override
  DaemonTransition build() {
    // Subscribe to the status stream so we can auto-clear the transition
    // once the daemon reaches the expected state. ref.listen cleans itself
    // up when the provider is disposed.
    ref.listen<AsyncValue<NodeStatus>>(daemonStatusProvider, (previous, next) {
      next.whenData((status) {
        if (state == DaemonTransition.starting && status.running) {
          _log('starting → confirmed running, clearing transition');
          state = DaemonTransition.none;
        } else if (state == DaemonTransition.stopping && !status.running) {
          _log('stopping → confirmed stopped, clearing transition');
          state = DaemonTransition.none;
        }
      });
    });
    return DaemonTransition.none;
  }

  /// How long a spawned daemon gets to report the gRPC port it bound before
  /// we assume the port we handed it was taken in the gap between our
  /// releasing it and its binding it. Generous: the child re-execs and brings
  /// up tokio before it binds.
  static const _grpcBindDeadline = Duration(seconds: 15);

  Future<void> start() async {
    _log('start() called');
    _lastError = null;
    ref.read(daemonErrorProvider.notifier).clear();
    state = DaemonTransition.starting;

    var r = await ref.read(daemonControllerProvider).start();

    // Only a daemon we just spawned has a port we chose. An external no-op or
    // an attach to a daemon already running has nothing to wait for.
    if (r.kind == DaemonStartKind.spawned && !await _awaitGrpcBind()) {
      _log('daemon did not report a gRPC port — retrying on a fresh one');
      await ref.read(daemonControllerProvider).stop();
      r = await ref.read(daemonControllerProvider).start();
      if (r.kind == DaemonStartKind.spawned && !await _awaitGrpcBind()) {
        _lastError =
            'Daemon started but never bound its gRPC port. Check the log: '
            '${KwaainetPaths.logsDir}.';
        ref.read(daemonErrorProvider.notifier).set(_lastError);
        state = DaemonTransition.none;
        return;
      }
    }

    if (!r.ok) {
      _log('start failed: ${r.error}');
      _lastError = r.error ?? 'start failed';
      ref.read(daemonErrorProvider.notifier).set(_lastError);
      state = DaemonTransition.none;
    }
  }

  /// Wait for the daemon to write `run/kwaainet.grpc`. Its presence means the
  /// listener is up — the daemon writes it only after a successful bind, and
  /// exits rather than carry on without a port it was given.
  Future<bool> _awaitGrpcBind() async {
    final deadline = DateTime.now().add(_grpcBindDeadline);
    while (DateTime.now().isBefore(deadline)) {
      if (File(KwaainetPaths.grpcPortFile).existsSync()) return true;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return false;
  }

  Future<void> stop() async {
    _log('stop() called');
    _lastError = null;
    ref.read(daemonErrorProvider.notifier).clear();
    state = DaemonTransition.stopping;
    final ok = await ref.read(daemonControllerProvider).stop();
    if (!ok) {
      _log('stop failed');
      _lastError = 'stop failed';
      ref.read(daemonErrorProvider.notifier).set(_lastError);
      state = DaemonTransition.none;
    }
  }
}

final daemonTransitionProvider =
    NotifierProvider<DaemonTransitionNotifier, DaemonTransition>(
      DaemonTransitionNotifier.new,
    );

/// Latest start/stop error, or null. Cleared on the next action.
class DaemonErrorNotifier extends Notifier<DaemonError> {
  @override
  DaemonError build() => null;

  void set(DaemonError v) => state = v;
  void clear() => state = null;
}

final daemonErrorProvider = NotifierProvider<DaemonErrorNotifier, DaemonError>(
  DaemonErrorNotifier.new,
);
