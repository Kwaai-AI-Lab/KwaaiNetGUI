import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat/generated/kwaai.pb.dart' as pb;
import '../chat/kwaai_rpc_client.dart';
import '../chat/session_client.dart';

/// `Error.Code.UNIMPLEMENTED` from kwaai.proto.
///
/// Answered by a daemon built without the `rag` feature — and equally by
/// one too old to know the RAG frames at all, since an unknown body is one
/// it cannot act on. Both mean "this daemon can't do RAG", which is why the
/// UI doesn't try to tell them apart.
const kRagUnimplemented = 6;

/// `Error.Code.NOT_FOUND` — the named KB was never initialised.
const kRagNotFound = 2;

/// `Error.Code.UNAVAILABLE` — Ollama unreachable, or the embedding model is
/// missing. The daemon's message names the remedy, so it is shown verbatim.
const kRagUnavailable = 3;

/// The knowledge bases this daemon holds.
///
/// `rag_status` is unary, not a subscription, so this is a FutureProvider
/// that re-runs on demand rather than a stream: KBs change only when *this*
/// app ingests or initialises, so there is nothing to push and polling
/// would query the daemon for no reason. Callers invalidate it after an op
/// that changes the answer.
///
/// Gated on the connection like the other daemon views, so it re-runs when
/// the daemon goes away and comes back. Errors are deliberately not caught
/// here: the tab distinguishes UNIMPLEMENTED (RAG unavailable) from an
/// ordinary failure, and swallowing them would erase that.
final ragStatusProvider = FutureProvider.autoDispose<pb.RagStatusUpdate>((
  ref,
) async {
  final client = ref.watch(kwaaiRpcClientProvider);
  final conn = ref.watch(kwaaiRpcConnectionProvider).valueOrNull;
  if (conn != RpcConnection.connected) {
    // An empty status would read as "no KBs, initialise one"; the daemon's
    // PID can be alive while the RPC is still (re)connecting.
    throw const RagNotConnected();
  }
  return client.ragStatus();
});

/// [ragStatusProvider]'s error while the RPC connection is not up.
class RagNotConnected implements Exception {
  const RagNotConnected();

  @override
  String toString() => 'Not connected to the daemon.';
}

/// Name of the KB the RAG tab is showing, or null for "pick the default".
///
/// Null rather than eagerly "default" because the sensible choice depends
/// on what the daemon reports — see [selectKb], which resolves it against
/// the actual list.
final selectedKbProvider = StateProvider.autoDispose<String?>((ref) => null);

/// Resolve which KB to show, given the selection and what exists.
///
/// Prefers the explicit selection, then a KB literally named "default",
/// then the first one. Returns null only when there are no KBs at all.
/// Kept pure and public so the choice is testable without a daemon.
String? selectKb(List<pb.RagKb> kbs, String? selected) {
  if (kbs.isEmpty) return null;
  if (selected != null && kbs.any((k) => k.name == selected)) {
    return selected;
  }
  for (final k in kbs) {
    if (k.name == 'default') return k.name;
  }
  return kbs.first.name;
}

/// Where an ingest job has got to.
///
/// `queued` is distinct from `running` because files are ingested one at a
/// time: dropping ten files should show nine waiting rather than ten
/// pretending to work.
enum RagJobStatus { queued, running, done, failed }

/// One file's journey through ingest, as the UI needs to render it.
class RagIngestJob {
  const RagIngestJob({
    required this.path,
    required this.name,
    required this.kb,
    this.status = RagJobStatus.queued,
    this.phase = pb.RagProgress_RagPhase.RAG_PHASE_UNSPECIFIED,
    this.done = 0,
    this.total = 0,
    this.detail = '',
    this.chunksIngested = 0,
    this.vectorsUploaded = 0,
    this.error,
  });

  /// Local file the GUI uploads; also the job's identity in the queue.
  final String path;

  /// Basename, for display.
  final String name;

  /// KB this file is destined for, fixed when the job was queued.
  ///
  /// Carried per job rather than per drain pass: the user can change the
  /// selected KB while an ingest is running, and a job must land where it
  /// was dropped rather than wherever the dropdown happens to point when
  /// its turn comes round.
  final String kb;

  final RagJobStatus status;

  /// Latest phase reported. EXTRACTING carries no counts (both 0) — it is
  /// one indivisible step — so a progress bar must fall back to
  /// indeterminate rather than rendering 0/0 as "nothing done".
  final pb.RagProgress_RagPhase phase;
  final int done;
  final int total;
  final String detail;

  final int chunksIngested;
  final int vectorsUploaded;

  /// User-facing failure text, set only when [status] is failed.
  final String? error;

  /// Fraction complete for this phase, or null when it has no meaningful
  /// subdivision — which the caller should render as an indeterminate bar.
  double? get fraction {
    if (total <= 0) return null;
    return (done / total).clamp(0.0, 1.0);
  }

  RagIngestJob copyWith({
    RagJobStatus? status,
    pb.RagProgress_RagPhase? phase,
    int? done,
    int? total,
    String? detail,
    int? chunksIngested,
    int? vectorsUploaded,
    String? error,
  }) {
    return RagIngestJob(
      path: path,
      name: name,
      kb: kb,
      status: status ?? this.status,
      phase: phase ?? this.phase,
      done: done ?? this.done,
      total: total ?? this.total,
      detail: detail ?? this.detail,
      chunksIngested: chunksIngested ?? this.chunksIngested,
      vectorsUploaded: vectorsUploaded ?? this.vectorsUploaded,
      error: error ?? this.error,
    );
  }
}

/// The ingest queue for the RAG tab.
///
/// Files run one at a time rather than in parallel: each embeds through
/// Ollama, so concurrency would contend on the same model and make every
/// file slower while muddling whose progress is whose.
class RagIngestQueue extends StateNotifier<List<RagIngestJob>> {
  RagIngestQueue(this._ref) : super(const []);

  final Ref _ref;
  bool _draining = false;

  /// Queue [paths] for ingest into [kb] and start draining if idle.
  ///
  /// The KB is stamped onto each job here rather than passed to the drain
  /// loop. Enqueuing while a drain is already running is the common case —
  /// a second drop lands mid-ingest — and that call returns immediately,
  /// leaving the *original* loop to pick the new jobs up. Were the KB the
  /// loop's, those jobs would be ingested into whichever KB started the
  /// drain instead of the one they were dropped into.
  void enqueue(Iterable<String> paths, {required String kb}) {
    final added = [
      for (final p in paths) RagIngestJob(path: p, name: basename(p), kb: kb),
    ];
    if (added.isEmpty) return;
    state = [...state, ...added];
    _drain();
  }

  /// Drop finished rows, keeping anything still queued or running.
  void clearFinished() {
    state = state
        .where(
          (j) =>
              j.status == RagJobStatus.queued ||
              j.status == RagJobStatus.running,
        )
        .toList(growable: false);
  }

  void _update(String path, RagIngestJob Function(RagIngestJob) f) {
    // The drain loop outlives an autoDispose teardown (leaving the tab,
    // toggling RAG off mid-ingest); late progress just has nowhere to go.
    if (!mounted) return;
    state = [
      for (final j in state)
        if (j.path == path) f(j) else j,
    ];
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (mounted) {
        final next = state
            .where((j) => j.status == RagJobStatus.queued)
            .firstOrNull;
        if (next == null) break;
        await _run(next);
        if (!mounted) break;
        // Each file changes the KB's document list, so refresh as we go
        // rather than only at the end — a long queue should show its
        // documents appearing.
        _ref.invalidate(ragStatusProvider);
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> _run(RagIngestJob job) async {
    _update(job.path, (j) => j.copyWith(status: RagJobStatus.running));
    final client = _ref.read(kwaaiRpcClientProvider);
    try {
      final op = await client.ragIngest(file: File(job.path), kb: job.kb);
      final sub = op.progress.listen((p) {
        _update(
          job.path,
          (j) => j.copyWith(
            phase: p.phase,
            done: p.done,
            total: p.total,
            detail: p.detail,
          ),
        );
      });
      try {
        final reply = await op.done;
        _update(
          job.path,
          (j) => j.copyWith(
            status: RagJobStatus.done,
            chunksIngested: reply.chunksIngested,
            vectorsUploaded: reply.vectorsUploaded,
          ),
        );
      } finally {
        await sub.cancel();
      }
    } catch (e) {
      _update(
        job.path,
        (j) => j.copyWith(status: RagJobStatus.failed, error: ragErrorText(e)),
      );
    }
  }
}

final ragIngestQueueProvider =
    StateNotifierProvider.autoDispose<RagIngestQueue, List<RagIngestJob>>(
      (ref) => RagIngestQueue(ref),
    );

/// Basename of a path, for either separator.
///
/// Written by hand rather than pulled from `package:path` so this file has
/// no dependency beyond the daemon layer; drops come in with whichever
/// separator the source platform uses.
String basename(String path) {
  final cut = path.lastIndexOf(RegExp(r'[/\\]'));
  return cut < 0 ? path : path.substring(cut + 1);
}

/// User-facing text for a failed RAG operation.
///
/// Switches on the structured proto code rather than matching message text,
/// as the chat error bar does. UNAVAILABLE is the exception worth noting:
/// the daemon's message there names the actual remedy ("start Ollama", "pull
/// nomic-embed-text"), so it is surfaced verbatim instead of being replaced
/// with a generic line.
String ragErrorText(Object error) {
  if (error is SessionOpError) {
    switch (error.code) {
      case 1: // INVALID_ARGUMENT
        return error.message.isEmpty ? 'Invalid request.' : error.message;
      case kRagNotFound:
        return 'That knowledge base does not exist yet.';
      case kRagUnavailable:
        return error.message.isEmpty
            ? 'The embedding service is unavailable. Is Ollama running?'
            : error.message;
      case 4: // CANCELLED
        return 'Cancelled.';
      case kRagUnimplemented:
        // Also a remote KB's answer to init/ingest, which the message names.
        return error.message.isEmpty
            ? 'This daemon was built without RAG support.'
            : error.message;
      default:
        return error.message.isEmpty ? 'Something went wrong.' : error.message;
    }
  }
  if (error is SessionEndedError) {
    return 'Lost the connection to the daemon.';
  }
  if (error is RagFileRejected) return error.message;
  return error.toString();
}

/// Whether [error] means "this daemon has no RAG at all", as opposed to a
/// RAG operation that merely failed.
bool isRagUnavailable(Object? error) =>
    error is SessionOpError && error.code == kRagUnimplemented;

/// Extensions the daemon's document extractor understands.
///
/// Mirrors `supported_extensions()` in kwaai-rag's `document.rs`. Kept in
/// sync by hand: the list is short and stable, and the alternative is
/// shipping it over the wire for a filter the user barely sees. A file the
/// daemon can't parse fails its own ingest with a clear message, so this is
/// a convenience for the picker, not a correctness boundary.
const kRagSupportedExtensions = <String>[
  'txt',
  'md',
  'rst',
  'csv',
  'json',
  'yaml',
  'toml',
  'pdf',
  'docx',
  'doc',
];

/// Whether [path] looks like something the daemon can extract text from.
///
/// Used to filter dropped files, where the OS offers no extension filter of
/// its own. Case-insensitive; a file with no extension is rejected, since
/// the extractor keys entirely off the extension.
bool isSupportedRagFile(String path) {
  final name = basename(path);
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return false;
  return kRagSupportedExtensions.contains(
    name.substring(dot + 1).toLowerCase(),
  );
}
