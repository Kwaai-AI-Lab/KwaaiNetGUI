import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/daemon/config_file.dart';

/// `enable_upnp` decides whether the node asks its router to map a port, which
/// in turn decides whether it is publicly reachable or falls back to relays.
/// Carrying it wrongly through an edit would silently flip that, so the
/// copyWith semantics are worth pinning.
ConfigSnapshot _snapshot({
  bool enableUpnp = true,
  bool enableQuic = false,
  Ipv6Mode ipv6 = Ipv6Mode.auto,
  int? maxConnections,
}) => ConfigSnapshot(
  model: '',
  shardingEnabled: true,
  storageEnabled: true,
  storageCapacityGb: null,
  port: null,
  publicIp: '',
  initialPeers: const [],
  forcePrivate: false,
  enableUpnp: enableUpnp,
  enableQuic: enableQuic,
  ipv6: ipv6,
  maxConnections: maxConnections,
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

  group('enableQuic', () {
    // Same copyWith trap as enableUpnp: a dropped field would silently
    // re-enable QUIC on a network the user turned it off for.
    test('survives an unrelated edit', () {
      final off = _snapshot(enableQuic: false);
      expect(off.copyWith(port: 9000).enableQuic, isFalse);
      expect(off.copyWith(enableUpnp: false).enableQuic, isFalse);
    });

    test('can be toggled explicitly in both directions', () {
      expect(
        _snapshot(enableQuic: true).copyWith(enableQuic: false).enableQuic,
        isFalse,
      );
      expect(_snapshot().copyWith(enableQuic: true).enableQuic, isTrue);
    });

    // The daemon has `#[serde(default)]` on the key, so a config without it
    // runs TCP-only. Defaulting to true here showed QUIC on and wrote
    // `enable_quic: true` on the next Apply.
    test('defaults off, matching the daemon', () {
      expect(ConfigFile.defaults.enableQuic, isNull, reason: 'unset');
      expect(ConfigFile.defaults.enableQuicEffective, isFalse);
    });
  });

  group('ipv6', () {
    // Same copyWith trap as the switches, and a worse failure: silently
    // re-arming "auto" on a node the user pinned to IPv6-only.
    test('survives an unrelated edit', () {
      final on = _snapshot(ipv6: Ipv6Mode.on);
      expect(on.copyWith(port: 9000).ipv6, Ipv6Mode.on);
      expect(on.copyWith(enableQuic: true).ipv6, Ipv6Mode.on);
    });

    test('can be changed explicitly in each direction', () {
      expect(_snapshot().copyWith(ipv6: Ipv6Mode.off).ipv6, Ipv6Mode.off);
      expect(
        _snapshot(ipv6: Ipv6Mode.off).copyWith(ipv6: Ipv6Mode.on).ipv6,
        Ipv6Mode.on,
      );
      expect(
        _snapshot(ipv6: Ipv6Mode.on).copyWith(ipv6: Ipv6Mode.auto).ipv6,
        Ipv6Mode.auto,
      );
    });

    // An unreadable value must not be louder than an absent one: both are
    // auto, which is what the daemon does with a key it cannot parse.
    test('fromYaml reads every spelling, and auto for the rest', () {
      expect(Ipv6Mode.fromYaml(true), Ipv6Mode.on);
      expect(Ipv6Mode.fromYaml(false), Ipv6Mode.off);
      expect(Ipv6Mode.fromYaml('true'), Ipv6Mode.on);
      expect(Ipv6Mode.fromYaml('false'), Ipv6Mode.off);
      expect(Ipv6Mode.fromYaml('TRUE'), Ipv6Mode.on);
      expect(Ipv6Mode.fromYaml('auto'), Ipv6Mode.auto);
      expect(Ipv6Mode.fromYaml('Auto'), Ipv6Mode.auto);
      expect(Ipv6Mode.fromYaml(null), Ipv6Mode.auto);
      expect(Ipv6Mode.fromYaml(42), Ipv6Mode.auto);
    });

    // A chosen "auto" is written as the daemon spells it; only an unset
    // snapshot (ipv6 null) removes the key.
    test('yamlValue writes bools, and auto as a string', () {
      expect(Ipv6Mode.on.yamlValue, isTrue);
      expect(Ipv6Mode.off.yamlValue, isFalse);
      expect(Ipv6Mode.auto.yamlValue, 'auto');
    });

    test('is unset when the file has no key', () {
      expect(ConfigFile.defaults.ipv6, isNull);
    });
  });

  group('maxConnections', () {
    test('null means unset, so the daemon default applies', () {
      expect(_snapshot().maxConnections, isNull);
    });

    test('survives an unrelated edit', () {
      final capped = _snapshot(maxConnections: 400);
      expect(capped.copyWith(port: 9000).maxConnections, 400);
      expect(capped.copyWith(enableQuic: false).maxConnections, 400);
    });

    test('can be raised explicitly', () {
      expect(_snapshot().copyWith(maxConnections: 800).maxConnections, 800);
    });
  });
}
