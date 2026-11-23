@Tags(['manual'])
library;

// Multi-turn context end to end: the GUI's chat code against a test-bed node
// serving the synthetic model, whose hops verify every prefilled token and
// report how many they hold. Excluded from the default suite (dart_test.yaml).
//
//   KWAAINET_GRPC_PORT=8095 \
//   KWAAINET_GRPC_TOKEN_FILE=<kwaaiai-env>/config/node-b/bed-grpc.token \
//   flutter test test/manual/chat_context_bed_test.dart --tags manual

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kwaainet_gui/src/chat/chat_message.dart';
import 'package:kwaainet_gui/src/chat/chat_state.dart';
import 'package:kwaainet_gui/src/chat/kwaai_rpc_client.dart';

/// What the hops should hold: a synthetic model's token ids are the bytes of
/// the conversation rendered as ChatML.
int chatmlBytes(List<(String, String)> turns) {
  final s = StringBuffer();
  for (final (role, content) in turns) {
    s.write('<|im_start|>$role\n$content<|im_end|>\n');
  }
  s.write('<|im_start|>assistant\n');
  return utf8.encode(s.toString()).length;
}

final _header = RegExp(
  r'^\[synthetic: (\d+) tokens of context verified across (\d+) hops\]',
);

/// The context the hops verified, from the answer's first piece.
int verifiedContext(ChatMessage answer) {
  expect(answer.error, isNull, reason: answer.error?.message);
  final m = _header.firstMatch(answer.text);
  expect(m, isNotNull, reason: 'no synthetic header in: ${answer.text}');
  expect(answer.text, isNot(contains('KV reset')));
  // ignore: avoid_print
  print('hops=${m!.group(2)} context=${m.group(1)}');
  return int.parse(m.group(1)!);
}

void main() {
  test(
    'a second turn reaches every hop with the first exchange',
    () async {
      final client = KwaaiRpcClient();
      final container = ProviderContainer(
        overrides: [kwaaiRpcClientProvider.overrideWithValue(client)],
      );
      addTearDown(() async {
        container.dispose();
        await client.close();
      });
      final chat = container.read(
        chatTranscriptProvider(ChatPath.shardRun).notifier,
      );
      List<ChatMessage> transcript() =>
          container.read(chatTranscriptProvider(ChatPath.shardRun));

      await chat.send('What is the capital of France?');
      final first = transcript()[1];
      expect(
        verifiedContext(first),
        chatmlBytes([('user', 'What is the capital of France?')]),
      );

      await chat.send('And of Italy?');
      expect(
        verifiedContext(transcript()[3]),
        chatmlBytes([
          ('user', 'What is the capital of France?'),
          ('assistant', first.text),
          ('user', 'And of Italy?'),
        ]),
      );

      // A new chat drops the context again.
      chat.newChat();
      await chat.send('And of Italy?');
      expect(
        verifiedContext(transcript()[1]),
        chatmlBytes([('user', 'And of Italy?')]),
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
