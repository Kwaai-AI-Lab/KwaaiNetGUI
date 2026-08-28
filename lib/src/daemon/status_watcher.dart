import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'daemon_controller.dart';
import 'paths.dart';

void _log(String msg) {
  stderr.writeln('[status-watcher] $msg');
}

/// Parse `run/kwaainet.grpc`. Null for anything that isn't a usable port, so
/// a truncated or half-written file falls back to the default rather than
/// sending the client at port 0.
int? parseGrpcPortFile(String raw) {
  final n = int.tryParse(raw.trim());
  if (n == null || n <= 0 || n > 65535) return null;
  return n;
}

class NodeStatus {
  NodeStatus({
    required this.running,
    this.pid,
    this.uptimeSecs,
    this.cpuPercent,
    this.memoryMb,
    this.memoryPercent,
    this.connections,
    this.threads,
    this.startedAt,
    this.grpcPort,
    this.source = 'pid',
  });

  final bool running;
  final int? pid;
  final int? uptimeSecs;
  final double? cpuPercent;
  final double? memoryMb;
  final double? memoryPercent;
  final int? connections;
  final int? threads;
  final int? startedAt;

  /// The gRPC TCP port the running daemon bound, from `run/kwaainet.grpc`.
  /// Null when the daemon has not written it yet, or is too old to.
  final int? grpcPort;

  /// Where the data came from: 'pid' (live PID probe only), 'status'
  /// (kwaainet.status JSON), or 'none' (nothing running).
  final String source;

  static NodeStatus stopped() => NodeStatus(running: false, source: 'none');

  NodeStatus withGrpcPort(int? port) => NodeStatus(
    running: running,
    pid: pid,
    uptimeSecs: uptimeSecs,
    cpuPercent: cpuPercent,
    memoryMb: memoryMb,
    memoryPercent: memoryPercent,
    connections: connections,
    threads: threads,
    startedAt: startedAt,
    grpcPort: port,
    source: source,
  );

  static NodeStatus? fromJson(Map<String, dynamic> j) {
    try {
      return NodeStatus(
        running: j['running'] as bool? ?? false,
        pid: (j['pid'] as num?)?.toInt(),
        uptimeSecs: (j['uptime_secs'] as num?)?.toInt(),
        cpuPercent: (j['cpu_percent'] as num?)?.toDouble(),
        memoryMb: (j['memory_mb'] as num?)?.toDouble(),
        memoryPercent: (j['memory_percent'] as num?)?.toDouble(),
        connections: (j['connections'] as num?)?.toInt(),
        threads: (j['threads'] as num?)?.toInt(),
        startedAt: (j['started_at'] as num?)?.toInt(),
        source: 'status',
      );
    } catch (_) {
      return null;
    }
  }
}

class StatusWatcher {
  StatusWatcher({
    required this.daemon,
    this.interval = const Duration(seconds: 2),
  });

  final DaemonController daemon;
  final Duration interval;
  final _controller = StreamController<NodeStatus>.broadcast();
  Timer? _timer;
  bool _lastRunning = false;

  Stream<NodeStatus> get stream => _controller.stream;

  void start() {
    if (_timer != null) return;
    _log('starting (polling every ${interval.inSeconds}s)');
    _poll();
    _timer = Timer.periodic(interval, (_) => _poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> dispose() async {
    stop();
    await _controller.close();
  }

  Future<void> _poll() async {
    final pid = daemon.readPid();
    final alive = pid != null && await daemon.isAlive();

    if (!alive) {
      if (_lastRunning) {
        _log('daemon no longer running (was pid ${pid ?? '?'})');
        _lastRunning = false;
      }
      _controller.add(NodeStatus.stopped());
      return;
    }

    // Read alongside the pid, so the port is only ever published for a daemon
    // we have just confirmed alive — a stale file from a killed daemon names
    // a port that is free for anything to take.
    final grpcPort = _readGrpcPort();

    final fromFile = _readStatusFile();
    if (fromFile != null && fromFile.running) {
      if (!_lastRunning) {
        _log(
          'daemon running (pid ${fromFile.pid ?? pid}) — status JSON present',
        );
        _lastRunning = true;
      }
      _controller.add(fromFile.withGrpcPort(grpcPort));
      return;
    }

    final fallback = NodeStatus(
      running: true,
      pid: pid,
      grpcPort: grpcPort,
      source: 'pid',
    );
    if (!_lastRunning) {
      _log('daemon running (pid $pid) — no status JSON yet, using PID-only');
      _lastRunning = true;
    }
    _controller.add(fallback);
  }

  int? _readGrpcPort() {
    final f = File(KwaainetPaths.grpcPortFile);
    if (!f.existsSync()) return null;
    try {
      return parseGrpcPortFile(f.readAsStringSync());
    } catch (_) {
      return null;
    }
  }

  NodeStatus? _readStatusFile() {
    final f = File(KwaainetPaths.statusFile);
    if (!f.existsSync()) return null;
    try {
      final text = f.readAsStringSync();
      if (text.trim().isEmpty) return null;
      return NodeStatus.fromJson(json.decode(text) as Map<String, dynamic>);
    } catch (e) {
      _log('failed to parse status file: $e');
      return null;
    }
  }
}
