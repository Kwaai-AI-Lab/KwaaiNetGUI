import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/chat/chat_state.dart';
import 'package:kwaainet_gui/src/chat/generated/kwaai.pb.dart' as pb;
import 'package:kwaainet_gui/src/chat/kwaai_rpc_client.dart';
import 'package:kwaainet_gui/src/chat/session_client.dart';

/// Base for test clients.
///
/// Overriding only `chatStream` is not enough: `send` uses the
/// *cancellable* entry points, so a stub that misses them falls through
/// to the real implementation and opens a socket to whatever daemon
/// happens to be running on the developer's machine. Routing every
/// entry point through one [tokenStream] keeps that from silently
/// happening again.
abstract class _FakeClient extends KwaaiRpcClient {
  /// `KwaaiRpcClient`'s constructor starts a keep-alive probe that opens
  /// the real daemon socket. Gate it off so tests never touch a live
  /// daemon (and don't depend on whether one is running).
  ///
  /// `setProbingEnabled(false)` rather than `close()`: close() also
  /// closes the connection-state controller, and the constructor has
  /// already scheduled a first probe that would then publish into it.
  _FakeClient() {
    setProbingEnabled(false);
  }

  /// Operation ids passed to [cancelOperation], in call order — lets a
  /// test assert the daemon was actually told to stop.
  final List<int> cancelledOps = [];

  /// Id handed to callers via `onOperationId`. Non-null so cancellation
  /// has something to target.
  int get operationId => 42;

  Stream<String> tokenStream(String prompt);

  @override
  Stream<String> chatStream(String prompt) => tokenStream(prompt);

  @override
  Stream<String> generateLocal(String prompt) => tokenStream(prompt);

  @override
  Stream<String> chatStreamCancellable(
    String prompt, {
    required void Function(int? operationId) onOperationId,
    void Function(Stream<pb.InferenceEvent>)? onEvents,
    void Function(Stream<SessionSlowNotice>)? onSlow,
  }) {
    onOperationId(operationId);
    return tokenStream(prompt);
  }

  @override
  Stream<String> generateLocalCancellable(
    String prompt, {
    required void Function(int? operationId) onOperationId,
    void Function(Stream<SessionSlowNotice>)? onSlow,
  }) {
    onOperationId(operationId);
    return tokenStream(prompt);
  }

  @override
  Future<void> cancelOperation(int operationId) async {
    cancelledOps.add(operationId);
  }
}

/// Test-only client that emits a fixed list of tokens with no delay.
class _StubClient extends _FakeClient {
  _StubClient(this.tokens);

  final List<String> tokens;

  @override
  Stream<String> tokenStream(String prompt) async* {
    for (final t in tokens) {
      yield t;
    }
  }
}

/// Mimics the daemon's answer to a Cancel: a token, then
/// `Error{code=CANCELLED}` on the operation's stream.
///
/// Used from both directions — after a user stop (where the error is an
/// expected acknowledgement) and unsolicited (where it's a real
/// failure the user must see).
class _CancellingClient extends _FakeClient {
  final _controller = StreamController<String>();

  /// Emits the daemon's CANCELLED for the in-flight operation. Driven
  /// by the test rather than a timer so the error can be delivered at a
  /// precise point relative to the local stop.
  void emitCancelled() {
    _controller.addError(SessionOpError(code: 4, message: 'cancelled'));
  }

  @override
  Stream<String> tokenStream(String prompt) {
    scheduleMicrotask(() => _controller.add('partial '));
    return _controller.stream;
  }

  /// The real client tears down the local subscription immediately and
  /// the daemon's acknowledgement races in behind it. Emitting from
  /// here reproduces that ordering: the error arrives as a *response
  /// to* the Cancel frame.
  @override
  Future<void> cancelOperation(int operationId) async {
    await super.cancelOperation(operationId);
    emitCancelled();
  }
}

/// Test-only client that throws mid-stream so we can verify error
/// handling preserves the assistant message.
class _ThrowingClient extends _FakeClient {
  @override
  Stream<String> tokenStream(String prompt) async* {
    yield 'first ';
    throw StateError('boom');
  }
}

/// Emits slow notices but no tokens — the long-prefill case that used to
/// surface as "Lost connection to the service".
class _SlowClient extends _FakeClient {
  final slow = StreamController<SessionSlowNotice>.broadcast();
  final _tokens = StreamController<String>();

  @override
  Stream<String> tokenStream(String prompt) => _tokens.stream;

  @override
  Stream<String> chatStreamCancellable(
    String prompt, {
    required void Function(int? operationId) onOperationId,
    void Function(Stream<pb.InferenceEvent>)? onEvents,
    void Function(Stream<SessionSlowNotice>)? onSlow,
  }) {
    onOperationId(operationId);
    onSlow?.call(slow.stream);
    return _tokens.stream;
  }

  void finish() {
    _tokens.close();
  }
}

void main() {
  test(
    'send appends user + assistant, streams tokens, clears streaming on done',
    () async {
      final container = ProviderContainer(
        overrides: [
          kwaaiRpcClientProvider.overrideWithValue(
            _StubClient(const ['hello ', 'there']),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(chatTranscriptProvider(ChatPath.shardRun).notifier)
          .send('hi');

      final msgs = container.read(chatTranscriptProvider(ChatPath.shardRun));
      expect(msgs, hasLength(2));
      expect(msgs[0].role, 'user');
      expect(msgs[0].text, 'hi');
      expect(msgs[1].role, 'assistant');
      expect(msgs[1].text, 'hello there');
      expect(msgs[1].streaming, false);
      expect(container.read(chatStreamingProvider(ChatPath.shardRun)), false);
    },
  );

  test('streaming is true while tokens are arriving', () async {
    final controller = StreamController<String>();
    final container = ProviderContainer(
      overrides: [
        kwaaiRpcClientProvider.overrideWithValue(
          _ControlledClient(controller.stream),
        ),
      ],
    );
    addTearDown(container.dispose);

    final send = container
        .read(chatTranscriptProvider(ChatPath.shardRun).notifier)
        .send('hi');
    // Yield once so the StreamSubscription is wired up.
    await Future<void>.delayed(Duration.zero);
    expect(container.read(chatStreamingProvider(ChatPath.shardRun)), true);

    controller.add('a ');
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(chatTranscriptProvider(ChatPath.shardRun)).last.text,
      'a ',
    );

    controller.add('b');
    await controller.close();
    await send;

    expect(
      container.read(chatTranscriptProvider(ChatPath.shardRun)).last.text,
      'a b',
    );
    expect(container.read(chatStreamingProvider(ChatPath.shardRun)), false);
  });

  test('empty prompt is a no-op', () async {
    final container = ProviderContainer(
      overrides: [
        kwaaiRpcClientProvider.overrideWithValue(_StubClient(const ['x'])),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(chatTranscriptProvider(ChatPath.shardRun).notifier)
        .send('   ');
    expect(container.read(chatTranscriptProvider(ChatPath.shardRun)), isEmpty);
  });

  test(
    'stream error surfaces on assistant message and clears streaming',
    () async {
      final container = ProviderContainer(
        overrides: [
          kwaaiRpcClientProvider.overrideWithValue(_ThrowingClient()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(chatTranscriptProvider(ChatPath.shardRun).notifier)
          .send('hi');
      final last = container
          .read(chatTranscriptProvider(ChatPath.shardRun))
          .last;
      expect(last.role, 'assistant');
      // Tokens that arrived before the error are preserved verbatim;
      // the error lands on the message's `error` field for the UI to
      // render in its distinct red badge.
      expect(last.text, 'first ');
      expect(last.error?.message, contains('boom'));
      expect(last.streaming, false);
    },
  );

  // Token arrivals are coalesced into a ~66ms window to bound markdown
  // re-parses. The risk that introduces is a *lost tail*: tokens that
  // land inside an open window and are never flushed, so the visible
  // response is silently truncated. Each terminal path is covered
  // below — these fail if the flush is dropped from any of them.

  test(
    'tokens arriving inside the throttle window survive stream close',
    () async {
      final controller = StreamController<String>();
      final container = ProviderContainer(
        overrides: [
          kwaaiRpcClientProvider.overrideWithValue(
            _ControlledClient(controller.stream),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        chatTranscriptProvider(ChatPath.shardRun).notifier,
      );
      final send = notifier.send('hi');
      await Future<void>.delayed(Duration.zero);

      // First token opens the throttle window and renders immediately.
      controller.add('a');
      await Future<void>.delayed(Duration.zero);

      // These land while the window is still open, so they are not
      // individually rendered — closing the stream must flush them.
      controller.add('b');
      controller.add('c');
      await controller.close();
      await send;

      expect(
        container.read(chatTranscriptProvider(ChatPath.shardRun)).last.text,
        'abc',
      );
    },
  );

  test(
    'tokens buffered in the throttle window survive a stream error',
    () async {
      final container = ProviderContainer(
        overrides: [
          kwaaiRpcClientProvider.overrideWithValue(_ThrowingClient()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(chatTranscriptProvider(ChatPath.shardRun).notifier)
          .send('hi');

      // The partial token preceding the throw must still be visible, so a
      // truncated answer shows what it managed to produce.
      final last = container
          .read(chatTranscriptProvider(ChatPath.shardRun))
          .last;
      expect(last.text, 'first ');
      expect(last.streaming, false);
    },
  );

  test('cancel flushes buffered tokens and clears streaming', () async {
    final controller = StreamController<String>();
    final container = ProviderContainer(
      overrides: [
        kwaaiRpcClientProvider.overrideWithValue(
          _ControlledClient(controller.stream),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(
      chatTranscriptProvider(ChatPath.shardRun).notifier,
    );
    unawaited(notifier.send('hi'));
    await Future<void>.delayed(Duration.zero);

    controller.add('partial ');
    await Future<void>.delayed(Duration.zero);
    // Must yield again so this token is actually delivered to the
    // subscription — `add` is asynchronous, and cancelling in the same
    // synchronous block would drop it before it ever reached the
    // notifier, testing nothing. It lands inside the still-open
    // throttle window, which is the case we care about.
    controller.add('tail');
    await Future<void>.delayed(Duration.zero);
    notifier.cancel();

    final last = container.read(chatTranscriptProvider(ChatPath.shardRun)).last;
    expect(last.text, 'partial tail');
    expect(last.streaming, false);
    expect(container.read(chatStreamingProvider(ChatPath.shardRun)), false);
  });

  // Stopping must reach the *daemon*, not just drop the local
  // subscription — otherwise generation continues into a channel
  // nobody reads until it hits the token cap.

  test('cancel tells the daemon to abort the operation', () async {
    final controller = StreamController<String>();
    final client = _ControlledClient(controller.stream);
    final container = ProviderContainer(
      overrides: [kwaaiRpcClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(
      chatTranscriptProvider(ChatPath.shardRun).notifier,
    );
    unawaited(notifier.send('hi'));
    await Future<void>.delayed(Duration.zero);
    controller.add('partial');
    await Future<void>.delayed(Duration.zero);

    notifier.cancel();
    await Future<void>.delayed(Duration.zero);

    expect(
      client.cancelledOps,
      [client.operationId],
      reason: 'the daemon should be told to stop the in-flight op',
    );
  });

  test('newChat also stops an in-flight daemon operation', () async {
    final controller = StreamController<String>();
    final client = _ControlledClient(controller.stream);
    final container = ProviderContainer(
      overrides: [kwaaiRpcClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(
      chatTranscriptProvider(ChatPath.shardRun).notifier,
    );
    unawaited(notifier.send('hi'));
    await Future<void>.delayed(Duration.zero);
    controller.add('partial');
    await Future<void>.delayed(Duration.zero);

    notifier.newChat();
    await Future<void>.delayed(Duration.zero);

    expect(
      client.cancelledOps,
      [client.operationId],
      reason: 'abandoning a transcript should not leave the daemon running',
    );
  });

  test('a completed stream is not cancelled afterwards', () async {
    final client = _StubClient(const ['done']);
    final container = ProviderContainer(
      overrides: [kwaaiRpcClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(
      chatTranscriptProvider(ChatPath.shardRun).notifier,
    );
    await notifier.send('hi');

    // The op finished on its own; a later stop must not target a
    // completed (or since-recycled) operation id.
    notifier.cancel();
    await Future<void>.delayed(Duration.zero);
    expect(client.cancelledOps, isEmpty);
  });

  test(
    'a user-requested stop keeps partial text and raises no error',
    () async {
      final client = _CancellingClient();
      final container = ProviderContainer(
        overrides: [kwaaiRpcClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        chatTranscriptProvider(ChatPath.shardRun).notifier,
      );
      unawaited(notifier.send('hi'));
      await Future<void>.delayed(Duration.zero);
      // Stop: sends the Cancel, and the stub answers with CANCELLED the
      // way the daemon does.
      notifier.cancel();
      await Future<void>.delayed(Duration.zero);

      final last = container
          .read(chatTranscriptProvider(ChatPath.shardRun))
          .last;
      // Stopping is deliberate, so the daemon's CANCELLED acknowledgement
      // must not surface as a failure. This works because cancel() drops
      // the subscription synchronously, so the acknowledgement lands on a
      // dead subscription and onError never runs — assert the observable
      // outcome rather than the mechanism.
      expect(last.text, 'partial ');
      expect(last.error, isNull, reason: 'a deliberate stop is not a failure');
      expect(last.streaming, false);
    },
  );

  test('an unsolicited CANCELLED is still surfaced as an error', () async {
    final client = _CancellingClient();
    final container = ProviderContainer(
      overrides: [kwaaiRpcClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(
      chatTranscriptProvider(ChatPath.shardRun).notifier,
    );
    unawaited(notifier.send('hi'));
    await Future<void>.delayed(Duration.zero);

    // No cancel() call: a CANCELLED arriving on its own means the
    // daemon aborted the op for its own reasons, which the user needs
    // to see.
    client.emitCancelled();
    await Future<void>.delayed(Duration.zero);

    final last = container.read(chatTranscriptProvider(ChatPath.shardRun)).last;
    expect(
      last.error?.code,
      4,
      reason: 'a daemon-initiated abort is a real failure',
    );
    expect(last.text, 'partial ');
  });

  test('newChat clears the transcript with a bump still pending', () async {
    final controller = StreamController<String>();
    final container = ProviderContainer(
      overrides: [
        kwaaiRpcClientProvider.overrideWithValue(
          _ControlledClient(controller.stream),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(
      chatTranscriptProvider(ChatPath.shardRun).notifier,
    );
    unawaited(notifier.send('hi'));
    await Future<void>.delayed(Duration.zero);
    controller.add('a');
    await Future<void>.delayed(Duration.zero);
    controller.add('b'); // opens a pending window

    notifier.newChat();
    expect(container.read(chatTranscriptProvider(ChatPath.shardRun)), isEmpty);

    // Outlive the throttle window: a stale timer firing here would
    // resurrect the cleared transcript.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(container.read(chatTranscriptProvider(ChatPath.shardRun)), isEmpty);
  });

  test('a slow run raises a notice, not an error', () async {
    final client = _SlowClient();
    final container = ProviderContainer(
      overrides: [kwaaiRpcClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(
      chatTranscriptProvider(ChatPath.shardRun).notifier,
    );
    unawaited(notifier.send('hi'));
    await Future<void>.delayed(Duration.zero);

    client.slow.add(
      const SessionSlowNotice(elapsed: Duration(seconds: 45), active: true),
    );
    await Future<void>.delayed(Duration.zero);

    final notice = container.read(chatSlowNoticeProvider(ChatPath.shardRun));
    expect(notice, isNotNull);
    expect(notice!.elapsed.inSeconds, 45);
    expect(notice.active, isTrue);
    // The whole point: a slow run is not a failed one.
    expect(
      container.read(chatTranscriptProvider(ChatPath.shardRun)).last.error,
      isNull,
    );

    client.finish();
  });

  test('the notice clears when the run ends', () async {
    final client = _SlowClient();
    final container = ProviderContainer(
      overrides: [kwaaiRpcClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(
      chatTranscriptProvider(ChatPath.shardRun).notifier,
    );
    final send = notifier.send('hi');
    await Future<void>.delayed(Duration.zero);
    client.slow.add(
      const SessionSlowNotice(elapsed: Duration(seconds: 45), active: true),
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(chatSlowNoticeProvider(ChatPath.shardRun)),
      isNotNull,
    );

    client.finish();
    await send;
    expect(
      container.read(chatSlowNoticeProvider(ChatPath.shardRun)),
      isNull,
      reason: 'a "still working" bar must not outlive the work',
    );
  });

  test('cancelling clears the notice', () async {
    final client = _SlowClient();
    final container = ProviderContainer(
      overrides: [kwaaiRpcClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(
      chatTranscriptProvider(ChatPath.shardRun).notifier,
    );
    unawaited(notifier.send('hi'));
    await Future<void>.delayed(Duration.zero);
    client.slow.add(
      const SessionSlowNotice(elapsed: Duration(seconds: 45), active: true),
    );
    await Future<void>.delayed(Duration.zero);

    notifier.cancel();
    expect(container.read(chatSlowNoticeProvider(ChatPath.shardRun)), isNull);
    client.finish();
  });
}

class _ControlledClient extends _FakeClient {
  _ControlledClient(this.source);

  final Stream<String> source;

  @override
  Stream<String> tokenStream(String prompt) => source;
}
