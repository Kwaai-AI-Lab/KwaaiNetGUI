@Tags(['manual'])
library;

// Soak the Peers subscription the way the tab uses it, to catch a stall that
// only appears after the first render.
//
//   flutter test test/manual/peers_soak_test.dart --tags manual --run-skipped
//
// Two shapes of failure this is looking for:
//   1. the feed going silent — updates stop arriving but the op never errors;
//   2. subscribe/cancel churn wedging the session, which is what repeatedly
//      entering and leaving the tab does.

import 'package:flutter_test/flutter_test.dart';
import 'package:kwaainet_gui/src/chat/generated/kwaai.pb.dart' as pb;
import 'package:kwaainet_gui/src/chat/kwaai_rpc_client.dart';
import 'package:kwaainet_gui/src/chat/session_client.dart';

void main() {
  test('the feed keeps flowing past the heartbeat', () async {
    final client = KwaaiRpcClient();
    addTearDown(client.close);

    final arrivals = <DateTime>[];
    Object? error;
    final sub = client.networkStream(intervalSecs: 5).listen(
      (_) => arrivals.add(DateTime.now()),
      onError: (Object e) => error = e,
    );
    addTearDown(sub.cancel);

    // Past the 60s heartbeat, so a wedged feed is unambiguous: even with
    // nothing changing, the daemon owes us an unchanged snapshot.
    await Future<void>.delayed(const Duration(seconds: 75));

    if (error is SessionOpError && (error! as SessionOpError).code == 6) {
      // ignore: avoid_print
      print('daemon is on the Go path — soak not applicable');
      return;
    }
    expect(error, isNull);
    // ignore: avoid_print
    print('arrivals: ${arrivals.length} over 75s');
    expect(
      arrivals,
      isNotEmpty,
      reason: 'no update at all in 75s — the feed never started',
    );
    expect(
      arrivals.length,
      greaterThanOrEqualTo(2),
      reason: 'only one update in 75s: the heartbeat never fired, so the '
          'subscription is wedged after its first snapshot',
    );
  }, timeout: const Timeout(Duration(seconds: 150)));

  test('repeated subscribe/cancel does not wedge the session', () async {
    final client = KwaaiRpcClient();
    addTearDown(client.close);

    // Entering and leaving the tab ten times. autoDispose cancels the
    // daemon-side op each time, so this exercises the cancel path hard.
    for (var i = 0; i < 10; i++) {
      pb.NetworkUpdate? got;
      Object? err;
      final sub = client.networkStream(intervalSecs: 5).listen(
        (u) => got ??= u,
        onError: (Object e) => err = e,
      );
      await Future<void>.delayed(const Duration(seconds: 2));
      await sub.cancel();

      if (err is SessionOpError && (err! as SessionOpError).code == 6) {
        // ignore: avoid_print
        print('daemon is on the Go path — churn test not applicable');
        return;
      }
      expect(
        got,
        isNotNull,
        reason: 'cycle $i produced no update — the session stopped serving '
            'after $i subscribe/cancel rounds',
      );
    }

    // And the session is still usable for other work afterwards.
    expect(await client.daemonVersion(), isNotNull);
  }, timeout: const Timeout(Duration(seconds: 150)));
}
