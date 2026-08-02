import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings.dart';
import 'chat_message.dart';
import 'inference_events_state.dart';
import 'kwaai_rpc_client.dart';
import 'session_client.dart';

void _log(String msg) {
  stderr.writeln('[chat] ${_elide(msg)}');
}

/// Keep log lines readable: long chat bodies get the middle elided so
/// you see the leading prompt and the tail of the response without
/// burying the console. Threshold sized for one-screen visibility.
String _elide(String s, {int maxLen = 240, int headTail = 110}) {
  final flat = s.replaceAll('\n', ' ');
  if (flat.length <= maxLen) return flat;
  final head = flat.substring(0, headTail);
  final tail = flat.substring(flat.length - headTail);
  return '$head … [${flat.length} chars] … $tail';
}

/// Which gRPC method drives a given transcript. Each path keeps its
/// own message history + in-flight subscription, so the main chat
/// (shard_run) and the Developer tab (generate) don't share state.
enum ChatPath {
  /// `kwaainet shard run` — distributed inference across the mesh.
  shardRun,

  /// `kwaainet generate` — single-node local inference.
  generateLocal,
}

/// Append-only transcript of messages for one [ChatPath]. Tokens
/// streamed from the daemon mutate the last (assistant) message in
/// place — `_bump()` triggers UI rebuilds without copying the list
/// per token.
class ChatTranscriptNotifier
    extends FamilyNotifier<List<ChatMessage>, ChatPath> {
  StreamSubscription<String>? _sub;
  Timer? _bumpTimer;

  /// Daemon-side id of the in-flight operation, used to tell the daemon
  /// to stop generating. Null when nothing is in flight, or when the
  /// session was closed before the request went out.
  int? _operationId;

  ChatPath get _path => arg;

  /// How long token arrivals are coalesced before the UI rebuilds.
  ///
  /// Assistant text renders as markdown, and each rebuild re-parses the
  /// whole message — so bumping per token makes the cost grow with the
  /// square of the response length and drops frames on long answers.
  /// At this interval the stream still reads as continuous to the eye
  /// while parses stay bounded at ~15/sec regardless of token rate.
  static const _bumpInterval = Duration(milliseconds: 66);

  @override
  List<ChatMessage> build(ChatPath arg) {
    ref.onDispose(() {
      _sub?.cancel();
      _bumpTimer?.cancel();
    });
    return [];
  }

  /// Send [prompt] and stream the response into a new assistant message.
  /// Returns when the stream completes.
  Future<void> send(String prompt) async {
    if (prompt.trim().isEmpty) return;
    if (_sub != null) return; // ignore overlapping sends
    _log('[${_path.name}] > $prompt');
    final user = ChatMessage(role: 'user', text: prompt);
    final assistant = ChatMessage(role: 'assistant', text: '', streaming: true);
    state = [...state, user, assistant];
    final client = ref.read(kwaaiRpcClientProvider);
    _operationId = null;
    void captureId(int? id) => _operationId = id;

    // Only the distributed path has a route to narrate, and only ask the
    // daemon for the detail when the panel is actually open — producing it
    // is real work on its side.
    final wantEvents =
        _path == ChatPath.shardRun &&
        ref.read(inferencePanelEnabledProvider);
    final eventsNotifier = ref.read(inferenceEventsProvider.notifier);
    if (wantEvents) eventsNotifier.startRun();

    final stream = switch (_path) {
      ChatPath.shardRun => client.chatStreamCancellable(
        prompt,
        onOperationId: captureId,
        onEvents: wantEvents ? eventsNotifier.ingest : null,
      ),
      ChatPath.generateLocal => client.generateLocalCancellable(
        prompt,
        onOperationId: captureId,
      ),
    };
    final completer = Completer<void>();
    _sub = stream.listen(
      (token) {
        assistant.text += token;
        _bumpThrottled();
      },
      onError: (e, _) {
        // Log any tokens that streamed in before the error too — without
        // this you can't tell from the log whether the daemon produced
        // a partial response or failed before emitting anything.
        if (assistant.text.isNotEmpty) {
          _log('[${_path.name}] < (partial) ${assistant.text}');
        }
        _log('[${_path.name}] < [error] $e');
        // Preserve the structured (code, message) when it's a
        // SessionOpError; fall back to a 0/UNKNOWN with the toString
        // for any other thrown type (transport hiccups, asserts, etc).
        //
        // A user-requested stop never lands here: [cancel] drops the
        // subscription synchronously, so the daemon's CANCELLED
        // acknowledgement is delivered to a dead subscription and this
        // handler is not called. That's what keeps a deliberate stop
        // from raising the error bar. An *unsolicited* CANCELLED (the
        // daemon aborting on its own, subscription still live) does
        // arrive here and is surfaced normally, which is correct.
        assistant.error = e is SessionOpError
            ? ChatError(code: e.code, message: e.message)
            : ChatError(code: 0, message: e.toString());
        assistant.streaming = false;
        _flushBump();
        _sub = null;
        _operationId = null;
        if (!completer.isCompleted) completer.complete();
      },
      onDone: () {
        _log('[${_path.name}] < ${assistant.text}');
        assistant.streaming = false;
        _flushBump();
        _sub = null;
        // Stream finished on its own: there is nothing left to cancel,
        // so drop the id to keep a later stop from targeting a
        // completed (or recycled) operation.
        _operationId = null;
        if (!completer.isCompleted) completer.complete();
      },
      cancelOnError: true,
    );
    return completer.future;
  }

  /// Stop the in-flight response.
  ///
  /// Tells the daemon to abort the operation *and* tears the local
  /// stream down. The daemon-side Cancel is what actually stops
  /// generation — dropping only the subscription would leave it
  /// producing tokens into a channel nobody reads, burning local and
  /// mesh capacity until it hit the token cap.
  ///
  /// Local teardown does not wait on the daemon: the UI stops
  /// immediately, and the Cancel frame is best-effort.
  void cancel() {
    final opId = _operationId;
    if (opId != null) {
      _log('[${_path.name}] stopping op $opId');
      unawaited(ref.read(kwaaiRpcClientProvider).cancelOperation(opId));
      _operationId = null;
    }
    _sub?.cancel();
    _sub = null;
    if (state.isNotEmpty && state.last.streaming) {
      state.last.streaming = false;
    }
    // Unconditional: a pending bump must be cleared even when the last
    // message wasn't mid-stream, so it can't fire after teardown.
    _flushBump();
    // Dropping the token subscription does not close the event stream, so
    // end the run explicitly or the panel keeps claiming it is live.
    if (_path == ChatPath.shardRun) {
      ref.read(inferenceEventsProvider.notifier).endRun();
    }
  }

  /// Drop the transcript and abort any in-flight stream. Backs the
  /// composer's "new chat" affordance — the next [send] starts a
  /// fresh conversation from the daemon's perspective too, since we
  /// don't replay history.
  void newChat() {
    // Same reasoning as [cancel]: abandoning the transcript must also
    // stop the daemon, or a discarded response keeps generating.
    final opId = _operationId;
    if (opId != null) {
      unawaited(ref.read(kwaaiRpcClientProvider).cancelOperation(opId));
      _operationId = null;
    }
    _sub?.cancel();
    _sub = null;
    // Drop any pending rebuild before clearing — otherwise it fires
    // against the emptied transcript a frame later.
    _bumpTimer?.cancel();
    _bumpTimer = null;
    state = [];
    // The panel describes the transcript we just discarded, so clear it
    // too rather than leaving a finished run's route on screen.
    if (_path == ChatPath.shardRun) {
      ref.read(inferenceEventsProvider.notifier).reset();
    }
  }

  /// Trigger a rebuild without changing the list reference — copying
  /// the list is cheap and only happens on each token tick.
  void _bump() => state = List.of(state);

  /// Coalescing [_bump] for the token-arrival path.
  ///
  /// The first token of a quiet period renders immediately (so the
  /// response starts appearing with no perceptible lag) and any further
  /// tokens inside the window collapse into a single trailing rebuild.
  void _bumpThrottled() {
    if (_bumpTimer != null) return; // a rebuild is already pending
    _bump();
    _bumpTimer = Timer(_bumpInterval, () {
      _bumpTimer = null;
      // Only needed if tokens actually arrived during the window; a
      // redundant bump is cheap, and skipping it would risk dropping
      // the tail of a burst.
      _bump();
    });
  }

  /// Cancel any pending throttled rebuild and render current text now.
  /// Every terminal path (done, error, cancel) must call this — otherwise
  /// the last tokens of a response stay stuck in the pending window.
  void _flushBump() {
    _bumpTimer?.cancel();
    _bumpTimer = null;
    _bump();
  }
}

final chatTranscriptProvider =
    NotifierProvider.family<
      ChatTranscriptNotifier,
      List<ChatMessage>,
      ChatPath
    >(ChatTranscriptNotifier.new);

/// True when there's an in-flight assistant stream on the given path.
final chatStreamingProvider = Provider.family<bool, ChatPath>((ref, path) {
  final msgs = ref.watch(chatTranscriptProvider(path));
  return msgs.isNotEmpty && msgs.last.streaming;
});
