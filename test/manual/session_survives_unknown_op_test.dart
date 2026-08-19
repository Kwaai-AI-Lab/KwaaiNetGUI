@Tags(['manual'])
library;

// The load-bearing degradation property: an operation the daemon cannot serve
// must not tear down the shared Session stream.
//
//   flutter test test/manual/session_survives_unknown_op_test.dart \
//     --tags manual --run-skipped
//
// Chat, Sharding, VPK and Peers all multiplex over one Session. If an
// unsupported operation killed it, they would all die together — a blank tab
// would become a dead app. This asserts the opposite by driving a failing
// Network op and then using the *same* session for another operation.

import 'package:flutter_test/flutter_test.dart';
import 'package:kwaainet_gui/src/chat/kwaai_rpc_client.dart';
import 'package:kwaainet_gui/src/chat/session_client.dart';

void main() {
  test(
    'a rejected network op leaves the session usable',
    () async {
      final client = KwaaiRpcClient();
      addTearDown(client.close);

      // Drive the Network op to whatever conclusion this daemon reaches.
      Object? networkError;
      var networkUpdates = 0;
      final sub = client
          .networkStream(intervalSecs: 5)
          .listen(
            (_) => networkUpdates++,
            onError: (Object e) => networkError = e,
          );
      addTearDown(sub.cancel);

      await Future<void>.delayed(const Duration(seconds: 6));

      if (networkError == null) {
        // ignore: avoid_print
        print(
          'daemon serves the network op ($networkUpdates update(s)) — the '
          'degradation path is not exercised here, but the session check below '
          'still applies',
        );
      } else {
        final e = networkError!;
        // ignore: avoid_print
        print(
          'network op rejected: '
          '${e is SessionOpError ? "code=${e.code} ${e.message}" : e}',
        );
      }

      // The real assertion: the same client, over the same Session, can still
      // do other work. `daemonVersion` runs a Status operation end to end.
      final version = await client.daemonVersion();
      expect(
        version,
        isNotNull,
        reason:
            'the Session died with the rejected operation — every other '
            'tab would have gone down with it',
      );
      // ignore: avoid_print
      print('session still usable — daemon version: $version');

      // And a second time, to rule out a session that limps once and then dies.
      expect(await client.daemonVersion(), isNotNull);
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
