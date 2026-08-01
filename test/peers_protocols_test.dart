import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/p2p/protocols.dart';

/// Protocol ids are stable, versioned identifiers, so describing them from a
/// lookup table is exact rather than a heuristic. These tests pin the ids this
/// build claims to know — if a daemon renames one, the description silently
/// stops applying and the id shows through instead, which is the failure mode
/// worth catching early.
void main() {
  group('describeProtocol', () {
    test('describes every protocol a live node actually advertises', () {
      // Captured verbatim from a running node's identify events: the union of
      // what the bootstraps, a p2pd peer and a native KwaaiNet peer advertise.
      // Every one must be described, or the panel shows a raw id to the user.
      const seenOnTheWire = [
        '/ipfs/id/1.0.0',
        '/ipfs/id/push/1.0.0',
        '/ipfs/kad/1.0.0',
        '/ipfs/ping/1.0.0',
        '/kwaai/inference-mux/1.0.0',
        '/kwaai/inference/1.0.0',
        '/kwaai/ollama-proxy/1.0.0',
        '/kwaai/p2p/hello/1.0.0',
        '/kwaai/shard-proxy/1.0.0',
        '/libp2p/autonat/1.0.0',
        '/libp2p/circuit/relay/0.1.0',
        '/libp2p/circuit/relay/0.2.0/hop',
        '/libp2p/circuit/relay/0.2.0/stop',
        '/libp2p/dcutr',
        // Namespaced under /p2p/ rather than /ipfs/ — an older p2pd peer
        // advertises this, and it slipped through the first version of the
        // table because /ipfs/id/+ does not reach it.
        '/p2p/id/delta/1.0.0',
      ];

      for (final id in seenOnTheWire) {
        // Assert through describeProtocol rather than containsKey: keys are
        // wildcard patterns, so an exact-key check would say "missing" for
        // every id the table describes by family.
        expect(
          describeProtocol(id),
          isNot(id),
          reason: '$id is advertised on the live network but falls through to '
              'its raw id — no description matches it',
        );
      }
    });

    test('falls back to the id when the protocol is unknown', () {
      // A peer running something this build has never heard of is worth
      // seeing. Dropping it would hide a capability; guessing at it would be
      // worse than showing the id.
      expect(
        describeProtocol('/some/future/protocol/9.0.0'),
        '/some/future/protocol/9.0.0',
      );
      expect(describeProtocol(''), '');
    });

    test('descriptions are prose, not restated ids', () {
      for (final entry in protocolDescriptions.entries) {
        expect(
          entry.value,
          isNot(startsWith('/')),
          reason: '${entry.key} is described by something that looks like an id',
        );
        expect(
          entry.value.trim(),
          isNotEmpty,
          reason: '${entry.key} has an empty description',
        );
      }
    });

    test('the relay hop/stop distinction survives', () {
      // These two are the pair most worth telling apart: hop means the peer
      // will relay *for* others, stop means it can be reached *through* one.
      // Collapsing them into "circuit relay" would lose which is which.
      final hop = describeProtocol('/libp2p/circuit/relay/0.2.0/hop');
      final stop = describeProtocol('/libp2p/circuit/relay/0.2.0/stop');
      expect(hop, isNot(stop));
      expect(hop.toLowerCase(), contains('relay'));
      expect(stop.toLowerCase(), contains('relay'));
    });

    test('a version bump keeps its description', () {
      // The reason for wildcards at all: an exact table silently degrades to
      // raw ids the moment a peer upgrades, which is exactly when you are
      // looking at the page.
      expect(
        describeProtocol('/ipfs/kad/2.0.0'),
        describeProtocol('/ipfs/kad/1.0.0'),
      );
      expect(
        describeProtocol('/kwaai/inference/3.1.4'),
        describeProtocol('/kwaai/inference/1.0.0'),
      );
    });

    test('a wildcard matches one segment, not many', () {
      // `+` is MQTT's single-level wildcard. If it spanned segments,
      // /ipfs/kad/+ would swallow /ipfs/kad/1.0.0/extra — and, worse,
      // /libp2p/circuit/relay/+ would swallow both hop and stop.
      expect(
        describeProtocol('/ipfs/kad/1.0.0/extra'),
        '/ipfs/kad/1.0.0/extra',
      );
      // Nor should it match a *missing* segment.
      expect(describeProtocol('/ipfs/kad'), '/ipfs/kad');
    });

    test('relay hop and stop stay apart across versions', () {
      // The case that forced per-segment matching: the version sits before the
      // discriminator, so a prefix match would merge these two opposite roles.
      final hop = describeProtocol('/libp2p/circuit/relay/0.3.0/hop');
      final stop = describeProtocol('/libp2p/circuit/relay/0.3.0/stop');
      expect(hop, isNot(stop));
      expect(hop, contains('hop'));
      expect(stop, contains('stop'));
    });

    test('an exact key beats a wildcard one', () {
      // Circuit relay v1 has no hop/stop suffix and is described on its own
      // terms, not as a version of the v2 family.
      expect(
        describeProtocol('/libp2p/circuit/relay/0.1.0'),
        contains('legacy'),
      );
    });

    test('sibling paths of different depth do not collide', () {
      // /ipfs/id/+ and /ipfs/id/push/+ differ only in length, which is what
      // segment-count matching relies on to tell them apart.
      expect(describeProtocol('/ipfs/id/1.0.0'), contains('Identify —'));
      expect(describeProtocol('/ipfs/id/push/1.0.0'), contains('push'));
    });

    test('DCUtR is named, since the view uses that name elsewhere', () {
      // The PATH column labels an upgraded connection "DCUtR"; the protocol
      // description should use the same word rather than "hole punching", so
      // the two read as the same thing.
      expect(describeProtocol('/libp2p/dcutr'), contains('DCUtR'));
    });
  });
}
