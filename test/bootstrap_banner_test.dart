import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/daemon/bootstrap_health.dart';

BootstrapHealth health({
  int total = 2,
  int reachable = 0,
  Duration? downFor = const Duration(minutes: 5),
}) => BootstrapHealth(total: total, reachable: reachable, downFor: downFor);

void main() {
  group('showBootstrapDownBanner', () {
    test('shows when no configured bootstrap is reachable', () {
      expect(showBootstrapDownBanner(health()), isTrue);
    });

    test('hides while the daemon is unreachable — not this banner\'s story', () {
      expect(showBootstrapDownBanner(null), isFalse);
    });

    test('hides when any bootstrap is reachable', () {
      expect(showBootstrapDownBanner(health(reachable: 1)), isFalse);
      expect(showBootstrapDownBanner(health(reachable: 2)), isFalse);
    });

    test('total 0 means unknowable, not healthy — stays silent', () {
      // Old daemon, Go p2p path, or entries without a /p2p component.
      expect(showBootstrapDownBanner(health(total: 0)), isFalse);
    });

    test('grace period: silent until the down state has persisted', () {
      expect(showBootstrapDownBanner(health(downFor: Duration.zero)), isFalse);
      expect(
        showBootstrapDownBanner(
          health(downFor: bootstrapDownGrace - const Duration(seconds: 1)),
        ),
        isFalse,
      );
      expect(
        showBootstrapDownBanner(health(downFor: bootstrapDownGrace)),
        isTrue,
      );
    });
  });

  group('bootstrapDownMessage', () {
    test('shows reachable of total', () {
      expect(
        bootstrapDownMessage(health(total: 3)),
        '0 of 3 bootstrap peers reachable — '
        'this node cannot join the network.',
      );
    });

    test('singular form for a single configured peer', () {
      expect(
        bootstrapDownMessage(health(total: 1)),
        '0 of 1 bootstrap peer reachable — '
        'this node cannot join the network.',
      );
    });
  });
}
