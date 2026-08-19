import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/daemon/config_file.dart';

/// `enable_upnp` decides whether the node asks its router to map a port, which
/// in turn decides whether it is publicly reachable or falls back to relays.
/// Carrying it wrongly through an edit would silently flip that, so the
/// copyWith semantics are worth pinning.
ConfigSnapshot _snapshot({bool enableUpnp = true}) => ConfigSnapshot(
  model: '',
  shardingEnabled: true,
  storageEnabled: true,
  storageCapacityGb: null,
  port: null,
  publicIp: '',
  initialPeers: const [],
  forcePrivate: false,
  enableUpnp: enableUpnp,
  healthEnabled: true,
  healthEndpoint: '',
);

void main() {
  group('enableUpnp', () {
    test('survives an unrelated edit', () {
      // The bug this guards against: a copyWith that drops the field would
      // silently re-enable port mapping the next time any other setting
      // changed, moving the node from NATed back to publicly reachable.
      final off = _snapshot(enableUpnp: false);
      expect(off.copyWith(port: 9000).enableUpnp, isFalse);
      expect(off.copyWith(forcePrivate: true).enableUpnp, isFalse);
    });

    test('copyWith leaves it alone when not passed', () {
      expect(_snapshot(enableUpnp: false).copyWith().enableUpnp, isFalse);
      expect(_snapshot().copyWith().enableUpnp, isTrue);
    });

    test('can be toggled explicitly in both directions', () {
      expect(_snapshot().copyWith(enableUpnp: false).enableUpnp, isFalse);
      expect(
        _snapshot(enableUpnp: false).copyWith(enableUpnp: true).enableUpnp,
        isTrue,
      );
    });
  });
}
