@Tags(['manual'])
library;

// The max response tokens setting end to end: the GUI's chat code against a
// test-bed node serving the synthetic model, which answers one "#<id> " piece
// per generated token. Excluded from the default suite (dart_test.yaml).
//
//   KWAAINET_GRPC_PORT=8095 \
//   KWAAINET_GRPC_TOKEN_FILE=<kwaaiai-env>/config/node-b/bed-grpc.token \
//   flutter test test/manual/max_tokens_bed_test.dart --tags manual --run-skipped

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kwaainet_gui/src/chat/chat_state.dart';
import 'package:kwaainet_gui/src/chat/kwaai_rpc_client.dart';
import 'package:kwaainet_gui/src/chat/session_client.dart';
import 'package:kwaainet_gui/src/settings.dart';

final _token = RegExp(r'#\d+ ');

void main() {
  late KwaaiRpcClient client;
  late ProviderContainer container;

  setUp(() {
    client = KwaaiRpcClient();
    container = ProviderContainer(
      overrides: [kwaaiRpcClientProvider.overrideWithValue(client)],
    );
  });

  tearDown(() async {
    container.dispose();
    await client.close();
  });

  /// Send one message with [maxTokens] set and count the answer's tokens.
  Future<int> answerLength(int? maxTokens) async {
    container.read(maxTokensProvider.notifier).state = maxTokens;
    final chat = container.read(
      chatTranscriptProvider(ChatPath.shardRun).notifier,
    );
    chat.newChat();
    await chat.send('How long is this answer?');
    final answer = container.read(chatTranscriptProvider(ChatPath.shardRun))[1];
    expect(answer.error, isNull, reason: answer.error?.message);
    final n = _token.allMatches(answer.text).length;
    // ignore: avoid_print
    print('maxTokens=$maxTokens -> $n tokens');
    return n;
  }

  test('the setting caps the answer, and unset is the default', () async {
    expect(await answerLength(7), 7);
    expect(await answerLength(null), defaultMaxTokens);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('the node refuses 0', () async {
    final stream = client.chatStreamCancellable(
      'hi',
      onOperationId: (_) {},
      maxTokens: 0,
    );
    await expectLater(
      stream.drain<void>(),
      throwsA(
        isA<SessionOpError>()
            .having((e) => e.code, 'code', 1)
            .having((e) => e.message, 'message', contains('max_tokens')),
      ),
    );
  }, timeout: const Timeout(Duration(minutes: 1)));
}
