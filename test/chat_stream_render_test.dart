import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/chat/chat_state.dart';
import 'package:kwaainet_gui/src/chat/generated/kwaai.pb.dart' as pb;
import 'package:kwaainet_gui/src/chat/kwaai_rpc_client.dart';
import 'package:kwaainet_gui/src/chat/session_client.dart';

/// Token throttling exists to bound markdown re-parses, and its failure
/// mode is a *lost tail*: buffered tokens that never reach a frame, so
/// the user sees a silently truncated answer.
///
/// State-level tests can't catch that — messages are mutated in place,
/// so reading the provider shows the full text whether or not a rebuild
/// ever happened. These tests watch the widget tree instead, which is
/// the thing the throttle actually governs.
/// Overriding `chatStream` alone is not enough — `send` uses the
/// cancellable entry point, and a stub that misses it falls through to
/// the real socket and talks to whatever daemon is running locally.
class _ControlledClient extends KwaaiRpcClient {
  _ControlledClient(this.source);

  final Stream<String> source;

  @override
  Stream<String> chatStream(String prompt) => source;

  @override
  Stream<String> chatStreamCancellable(
    String prompt, {
    required void Function(int? operationId) onOperationId,
    void Function(Stream<pb.InferenceEvent>)? onEvents,
    void Function(Stream<SessionSlowNotice>)? onSlow,
  }) {
    onOperationId(1);
    return source;
  }

  @override
  Future<void> cancelOperation(int operationId) async {}
}

/// Builds a container wired to [source], with the client's keep-alive
/// probe shut down.
///
/// `KwaaiRpcClient`'s constructor starts a periodic probe against the
/// real daemon socket. There's nothing to probe here, and `testWidgets`
/// fails any test that ends with a live timer — so the probe is stopped
/// up front via [KwaaiRpcClient.close], which cancels it. (Plain `test`
/// tolerates stray timers, which is why the state-level transcript
/// tests don't need this.) `chatStream` is overridden to return the
/// caller's stream, so a closed client still drives the transcript.
ProviderContainer _containerFor(Stream<String> source) {
  final client = _ControlledClient(source);
  // Fire-and-forget: cancels the probe timer synchronously before
  // awaiting channel teardown, which is all this needs.
  unawaited(client.close());
  final container = ProviderContainer(
    overrides: [kwaaiRpcClientProvider.overrideWithValue(client)],
  );
  addTearDown(container.dispose);
  return container;
}

/// Minimal harness: renders the streaming assistant text and counts how
/// many times it rebuilt.
class _Probe extends ConsumerWidget {
  const _Probe({required this.onBuild});

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final msgs = ref.watch(chatTranscriptProvider(ChatPath.shardRun));
    onBuild();
    final text = msgs.isEmpty ? '' : msgs.last.text;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(text, key: const Key('assistant')),
    );
  }
}

String _rendered(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('assistant'))).data ?? '';

void main() {
  testWidgets('buffered tokens reach the frame when the stream closes',
      (tester) async {
    final controller = StreamController<String>();
    final container = _containerFor(controller.stream);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _Probe(onBuild: () {}),
      ),
    );

    final notifier =
        container.read(chatTranscriptProvider(ChatPath.shardRun).notifier);
    final send = notifier.send('hi');
    // Yield so the StreamSubscription is wired up before tokens are
    // added; tokens added beforehand are dropped and the test would be
    // asserting against an empty stream.
    await tester.idle();
    await tester.pump();

    controller.add('Hello ');
    await tester.idle();
    await tester.pump();
    expect(_rendered(tester), 'Hello ');

    // These arrive while the throttle window is open, so they are not
    // rendered yet — the close must flush them into a frame.
    controller.add('there ');
    controller.add('world');
    await tester.idle();
    await tester.pump();
    expect(_rendered(tester), 'Hello ',
        reason: 'mid-window tokens should still be coalesced');

    await controller.close();
    await send;
    await tester.idle();
    await tester.pump();
    expect(_rendered(tester), 'Hello there world');
  });

  testWidgets('cancel flushes buffered tokens into a frame', (tester) async {
    final controller = StreamController<String>();
    final container = _containerFor(controller.stream);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _Probe(onBuild: () {}),
      ),
    );

    final notifier =
        container.read(chatTranscriptProvider(ChatPath.shardRun).notifier);
    unawaited(notifier.send('hi'));
    await tester.idle();
    await tester.pump();

    controller.add('partial ');
    await tester.idle();
    await tester.pump();
    controller.add('tail');
    await tester.idle(); // deliver the token; throttle window still open
    await tester.pump();

    notifier.cancel();
    await tester.pump();
    expect(_rendered(tester), 'partial tail');
  });

  testWidgets('a token burst is coalesced into far fewer rebuilds',
      (tester) async {
    final controller = StreamController<String>();
    final container = _containerFor(controller.stream);

    var builds = 0;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _Probe(onBuild: () => builds++),
      ),
    );

    final notifier =
        container.read(chatTranscriptProvider(ChatPath.shardRun).notifier);
    final send = notifier.send('hi');
    // Yield so the StreamSubscription is wired up before tokens are
    // added; tokens added beforehand are dropped and the test would be
    // asserting against an empty stream.
    await tester.idle();
    await tester.pump();
    builds = 0;

    // 200 tokens with no delay — the pathological case the throttle is
    // for. Without it this would be ~200 markdown re-parses.
    for (var i = 0; i < 200; i++) {
      controller.add('tok ');
    }
    await tester.idle();
    await tester.pump();
    await controller.close();
    await send;
    await tester.idle();
    await tester.pump();

    expect(builds, lessThan(10),
        reason: '200 tokens should coalesce into a handful of rebuilds');
    // Coalescing must not cost content: every token still lands.
    expect(_rendered(tester), 'tok ' * 200);
  });
}
