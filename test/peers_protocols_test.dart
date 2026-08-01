import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/ui/pages/peers_tab.dart';

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
        '/libp2p/circuit/relay/0.2.0/hop',
        '/libp2p/circuit/relay/0.2.0/stop',
        '/libp2p/dcutr',
      ];

      for (final id in seenOnTheWire) {
        expect(
          protocolDescriptions.containsKey(id),
          isTrue,
          reason: '$id is advertised on the live network but has no description',
        );
        expect(
          describeProtocol(id),
          isNot(id),
          reason: '$id should render as prose, not as its own id',
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

    test('DCUtR is named, since the view uses that name elsewhere', () {
      // The PATH column labels an upgraded connection "DCUtR"; the protocol
      // description should use the same word rather than "hole punching", so
      // the two read as the same thing.
      expect(describeProtocol('/libp2p/dcutr'), contains('DCUtR'));
    });
  });
}
