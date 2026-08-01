import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/ui/pages/blocks_tab.dart';

/// The staleness cue exists because the daemon suppresses block-coverage
/// updates that would say nothing new (see `HEARTBEAT` in
/// kwaai-cli/src/grpc_server.rs). Silence is therefore normal, and the
/// only thing separating "healthy and quiet" from "wedged" is that the
/// daemon still sends an unchanged snapshot every 60 s.
///
/// That makes these two constants a cross-repo contract rather than a
/// local style choice, which is what this test pins.
void main() {
  group('staleness threshold', () {
    test('clears the daemon heartbeat with margin', () {
      // The daemon's HEARTBEAT. If that constant moves, this test should
      // fail and staleAfter has to move with it.
      const daemonHeartbeat = Duration(seconds: 60);

      expect(
        staleAfter,
        greaterThan(daemonHeartbeat),
        reason: 'a threshold at or below the heartbeat would flag every '
            'healthy quiet period as stale',
      );

      // Enough slack to absorb a slow DHT round or a busy scheduler
      // without crying wolf, but still well inside the 360 s record TTL
      // so a genuinely wedged daemon is caught long before the data it
      // last reported could have expired.
      expect(
        staleAfter - daemonHeartbeat,
        greaterThanOrEqualTo(const Duration(seconds: 30)),
        reason: 'too little margin makes the cue flap on normal jitter',
      );
      expect(
        staleAfter,
        lessThan(const Duration(seconds: 360)),
        reason: 'past the DHT record TTL the cue would arrive too late '
            'to be useful',
      );
    });

    test('re-evaluates often enough to be responsive', () {
      // Nothing rebuilds the view while updates are suppressed, so the
      // tick is what makes the cue appear at all. It has to be fine
      // enough that the cue lands promptly once the threshold passes.
      expect(staleTick, lessThan(staleAfter));
      expect(staleTick.inSeconds, greaterThan(0));
    });
  });

  group('describeStaleness', () {
    test('rounds coarsely and never shows a bare number', () {
      expect(describeStaleness(const Duration(seconds: 45)), '45s');
      expect(describeStaleness(const Duration(minutes: 5)), '5m');
      expect(describeStaleness(const Duration(hours: 3)), '3h');
      expect(describeStaleness(const Duration(days: 2)), '2d');
    });

    test('falls back when no update has ever arrived', () {
      // Null means the subscription has produced nothing yet, which is a
      // different state from "arrived a long time ago" — it must not
      // render as "0s", which would read as perfectly fresh.
      expect(describeStaleness(null), 'a while');
    });

    test('switches units at the boundaries, not mid-range', () {
      // Just under two minutes still reads in seconds: "119s" is more
      // informative than "1m" while the cue is first appearing.
      expect(describeStaleness(const Duration(seconds: 119)), '119s');
      expect(describeStaleness(const Duration(seconds: 120)), '2m');
      expect(describeStaleness(const Duration(minutes: 59)), '59m');
      expect(describeStaleness(const Duration(minutes: 60)), '1h');
    });
  });
}
