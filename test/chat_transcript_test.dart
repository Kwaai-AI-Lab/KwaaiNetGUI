import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/chat/chat_state.dart';
import 'package:kwaainet_gui/src/chat/kwaai_rpc_client.dart';

/// Test-only client that emits a fixed list of tokens with no delay.
class _StubClient extends KwaaiRpcClient {
  _StubClient(this.tokens);

  final List<String> tokens;

  @override
  Stream<String> chatStream(String prompt) async* {
    for (final t in tokens) {
      yield t;
    }
  }
}

/// Test-only client that throws mid-stream so we can verify error
/// handling preserves the assistant message.
class _ThrowingClient extends KwaaiRpcClient {
  @override
  Stream<String> chatStream(String prompt) async* {
    yield 'first ';
    throw StateError('boom');
  }
}

void main() {
  test('send appends user + assistant, streams tokens, clears streaming on done',
      () async {
    final container = ProviderContainer(
      overrides: [
        kwaaiRpcClientProvider.overrideWithValue(
          _StubClient(const ['hello ', 'there']),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(chatTranscriptProvider(ChatPath.shardRun).notifier).send('hi');

    final msgs = container.read(chatTranscriptProvider(ChatPath.shardRun));
    expect(msgs, hasLength(2));
    expect(msgs[0].role, 'user');
    expect(msgs[0].text, 'hi');
    expect(msgs[1].role, 'assistant');
    expect(msgs[1].text, 'hello there');
    expect(msgs[1].streaming, false);
    expect(container.read(chatStreamingProvider(ChatPath.shardRun)), false);
  });

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

    final send = container.read(chatTranscriptProvider(ChatPath.shardRun).notifier).send('hi');
    // Yield once so the StreamSubscription is wired up.
    await Future<void>.delayed(Duration.zero);
    expect(container.read(chatStreamingProvider(ChatPath.shardRun)), true);

    controller.add('a ');
    await Future<void>.delayed(Duration.zero);
    expect(container.read(chatTranscriptProvider(ChatPath.shardRun)).last.text, 'a ');

    controller.add('b');
    await controller.close();
    await send;

    expect(container.read(chatTranscriptProvider(ChatPath.shardRun)).last.text, 'a b');
    expect(container.read(chatStreamingProvider(ChatPath.shardRun)), false);
  });

  test('empty prompt is a no-op', () async {
    final container = ProviderContainer(
      overrides: [
        kwaaiRpcClientProvider.overrideWithValue(_StubClient(const ['x'])),
      ],
    );
    addTearDown(container.dispose);

    await container.read(chatTranscriptProvider(ChatPath.shardRun).notifier).send('   ');
    expect(container.read(chatTranscriptProvider(ChatPath.shardRun)), isEmpty);
  });

  test('stream error surfaces on assistant message and clears streaming',
      () async {
    final container = ProviderContainer(
      overrides: [
        kwaaiRpcClientProvider.overrideWithValue(_ThrowingClient()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(chatTranscriptProvider(ChatPath.shardRun).notifier).send('hi');
    final last = container.read(chatTranscriptProvider(ChatPath.shardRun)).last;
    expect(last.role, 'assistant');
    // Tokens that arrived before the error are preserved verbatim;
    // the error lands on the message's `error` field for the UI to
    // render in its distinct red badge.
    expect(last.text, 'first ');
    expect(last.error?.message, contains('boom'));
    expect(last.streaming, false);
  });

  // Token arrivals are coalesced into a ~66ms window to bound markdown
  // re-parses. The risk that introduces is a *lost tail*: tokens that
  // land inside an open window and are never flushed, so the visible
  // response is silently truncated. Each terminal path is covered
  // below — these fail if the flush is dropped from any of them.

  test('tokens arriving inside the throttle window survive stream close',
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

    final notifier =
        container.read(chatTranscriptProvider(ChatPath.shardRun).notifier);
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
  });

  test('tokens buffered in the throttle window survive a stream error',
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
    final last = container.read(chatTranscriptProvider(ChatPath.shardRun)).last;
    expect(last.text, 'first ');
    expect(last.streaming, false);
  });

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

    final notifier =
        container.read(chatTranscriptProvider(ChatPath.shardRun).notifier);
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

    final notifier =
        container.read(chatTranscriptProvider(ChatPath.shardRun).notifier);
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
}

class _ControlledClient extends KwaaiRpcClient {
  _ControlledClient(this.source);

  final Stream<String> source;

  @override
  Stream<String> chatStream(String prompt) => source;
}
