import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/ui/pages/peers_tab.dart';

/// Peers report the address they observe us at, and for an outbound connection
/// that carries the connection's ephemeral source port. On a busy node the same
/// public IP therefore arrives a dozen times over, once per port — a wall of
/// near-identical lines conveying one fact.
void main() {
  group('summariseObservedAddrs', () {
    test('collapses the real-world case to one line per host', () {
      // Verbatim from a live node with 15 connections: two genuine addresses
      // (the listening port and a relay path) buried under nine ephemeral ones.
      final summary = summariseObservedAddrs([
        '/ip4/98.232.246.19/tcp/8080',
        '/ip4/18.219.43.67/tcp/8000/p2p/QmQhRuheeCLEsVD3RsnknM75gPDDqxAb8DhnWgro7KhaJc/p2p-circuit',
        '/ip4/98.232.246.19/tcp/50769',
        '/ip4/98.232.246.19/tcp/64529',
        '/ip4/98.232.246.19/tcp/53328',
        '/ip4/98.232.246.19/tcp/53446',
        '/ip4/98.232.246.19/tcp/50364',
        '/ip4/98.232.246.19/tcp/53441',
        '/ip4/98.232.246.19/tcp/50748',
        '/ip4/98.232.246.19/tcp/53477',
        '/ip4/98.232.246.19/tcp/64534',
        '/ip4/98.232.246.19/tcp/53482',
        '/ip4/98.232.246.19/tcp/53325',
      ]);

      // Eleven same-host lines become one; the relay path survives intact.
      expect(summary, hasLength(2));
      expect(summary.first, startsWith('/ip4/98.232.246.19/tcp/8080'));
      expect(summary.first, contains('more ephemeral ports'));
      expect(summary.last, contains('/p2p-circuit'));
    });

    test('leaves a single observation exactly as it is', () {
      // The common case for a quiet node: nothing to summarise, so nothing is
      // added. A bare address must not grow a "(+0 more)" suffix.
      expect(summariseObservedAddrs(['/ip4/203.0.113.7/tcp/8080']), [
        '/ip4/203.0.113.7/tcp/8080',
      ]);
    });

    test('keeps distinct hosts apart', () {
      // A dual-stack or multi-homed node genuinely has more than one public
      // address, and collapsing those together would hide a real fact.
      final summary = summariseObservedAddrs([
        '/ip4/203.0.113.7/tcp/8080',
        '/ip4/198.51.100.4/tcp/8080',
        '/ip4/203.0.113.7/tcp/51000',
      ]);

      expect(summary, hasLength(2));
      expect(summary.any((s) => s.startsWith('/ip4/203.0.113.7/')), isTrue);
      expect(summary.any((s) => s.startsWith('/ip4/198.51.100.4/')), isTrue);
    });

    test('reports the lowest port first', () {
      // The listening port is almost always below the ephemeral range, so
      // showing the lowest surfaces "peers see me where I bound" rather than an
      // arbitrary short-lived port.
      final summary = summariseObservedAddrs([
        '/ip4/203.0.113.7/tcp/51000',
        '/ip4/203.0.113.7/tcp/8080',
        '/ip4/203.0.113.7/tcp/62000',
      ]);

      expect(summary.single, startsWith('/ip4/203.0.113.7/tcp/8080'));
      expect(summary.single, contains('+2 more'));
    });

    test('uses the singular for exactly one extra port', () {
      final summary = summariseObservedAddrs([
        '/ip4/203.0.113.7/tcp/8080',
        '/ip4/203.0.113.7/tcp/51000',
      ]);
      expect(summary.single, contains('+1 more ephemeral port'));
      expect(summary.single, isNot(contains('ports')));
    });

    test('deduplicates identical repeats', () {
      expect(
        summariseObservedAddrs([
          '/ip4/203.0.113.7/tcp/8080',
          '/ip4/203.0.113.7/tcp/8080',
        ]),
        ['/ip4/203.0.113.7/tcp/8080'],
      );
    });

    test('collapses IPv6 ephemeral ports the same as IPv4', () {
      expect(
        summariseObservedAddrs([
          '/ip6/2001:db8::1/tcp/40001',
          '/ip6/2001:db8::1/tcp/40002',
        ]),
        ['/ip6/2001:db8::1/tcp/40001 (+1 more ephemeral port)'],
      );
    });

    test('collapses QUIC ports and keeps the transport suffix', () {
      // Dropping '/quic-v1' would leave a line naming a UDP port that is not
      // the address anyone can dial.
      expect(
        summariseObservedAddrs([
          '/ip4/203.0.113.9/udp/4001/quic-v1',
          '/ip4/203.0.113.9/udp/4002/quic-v1',
        ]),
        ['/ip4/203.0.113.9/udp/4001/quic-v1 (+1 more ephemeral port)'],
      );
    });

    test('keeps the two families apart', () {
      final summary = summariseObservedAddrs([
        '/ip4/203.0.113.7/tcp/8080',
        '/ip6/2001:db8::1/tcp/8080',
      ]);
      expect(summary, [
        '/ip4/203.0.113.7/tcp/8080',
        '/ip6/2001:db8::1/tcp/8080',
      ]);
    });

    test('passes through anything it cannot parse', () {
      // Better a line the user can read than a silently dropped address: a
      // transport with no port at all must not vanish from the view.
      expect(
        summariseObservedAddrs([
          '/ip4/203.0.113.7/tcp/8080',
          '/ip4/203.0.113.8/sctp/1',
        ]),
        contains('/ip4/203.0.113.8/sctp/1'),
      );
    });

    test('handles an empty list', () {
      expect(summariseObservedAddrs([]), isEmpty);
    });
  });

  group('scopeOf', () {
    // A mapped address is a v4 address wearing a v6 costume; classifying it
    // by the costume put loopback at the top of the address list.
    test('classifies an IPv4-mapped address by the v4 inside it', () {
      expect(scopeOf('/ip6/::ffff:127.0.0.1/tcp/1'), AddrScope.local);
      expect(scopeOf('/ip6/::ffff:10.1.2.3/tcp/1'), AddrScope.internal);
      expect(scopeOf('/ip6/::ffff:192.168.1.5/tcp/1'), AddrScope.internal);
      expect(scopeOf('/ip6/::ffff:203.0.113.7/tcp/1'), AddrScope.public);
    });

    test('classifies IPv6 by its own prefixes', () {
      expect(scopeOf('/ip6/fdc6:1200::20/tcp/8080'), AddrScope.internal);
      expect(scopeOf('/ip6/2001:db8::1/tcp/1'), AddrScope.public);
    });

    test('classifies public addresses', () {
      expect(scopeOf('/ip4/98.232.246.19/tcp/8080'), AddrScope.public);
      expect(scopeOf('/ip4/18.219.43.67/tcp/8000'), AddrScope.public);
      expect(scopeOf('/ip6/2001:db8::1/tcp/8080'), AddrScope.public);
    });

    test('classifies every private range as internal', () {
      // The full RFC1918 set plus the two ranges that behave the same way:
      // CGNAT, which a carrier hands out and nobody outside can reach, and
      // link-local, which does not leave the segment.
      for (final host in [
        '10.0.0.5',
        '192.168.68.135',
        '172.16.0.1',
        '172.31.255.254',
        '100.64.0.1', // CGNAT
        '169.254.1.1', // link-local
      ]) {
        expect(
          scopeOf('/ip4/$host/tcp/8080'),
          AddrScope.internal,
          reason: '$host should be internal',
        );
      }
      // …but the neighbours of those ranges are public.
      expect(scopeOf('/ip4/172.15.0.1/tcp/8080'), AddrScope.public);
      expect(scopeOf('/ip4/172.32.0.1/tcp/8080'), AddrScope.public);
      expect(scopeOf('/ip4/100.128.0.1/tcp/8080'), AddrScope.public);
    });

    test('classifies loopback and wildcard binds as local', () {
      expect(scopeOf('/ip4/127.0.0.1/tcp/8080'), AddrScope.local);
      // A wildcard bind names no interface, so it tells the user nothing about
      // reachability and must not lead the collapsed line.
      expect(scopeOf('/ip4/0.0.0.0/tcp/8080'), AddrScope.local);
      expect(scopeOf('/ip6/::1/tcp/8080'), AddrScope.local);
      expect(scopeOf('/ip6/::/tcp/8080'), AddrScope.local);
    });

    test('treats IPv6 unique-local and link-local as internal', () {
      expect(scopeOf('/ip6/fd00::1/tcp/8080'), AddrScope.internal);
      expect(scopeOf('/ip6/fe80::1/tcp/8080'), AddrScope.internal);
    });

    test('treats a circuit address as public', () {
      // A circuit reaches as far as its relay does, and nobody reserves a
      // circuit on a LAN-only relay.
      expect(
        scopeOf(
          '/ip4/18.219.43.67/tcp/8000/p2p/QmQhRuheeCLEsVD3RsnknM75gPDDqxAb8DhnWgro7KhaJc/p2p-circuit',
        ),
        AddrScope.public,
      );
    });

    test('ranks anything unrecognised as public', () {
      // Better to lead with an address we cannot classify than to bury a new
      // transport below loopback.
      expect(scopeOf('/dns4/example.com/tcp/8080'), AddrScope.public);
      expect(scopeOf('nonsense'), AddrScope.public);
    });
  });

  group('sortByScope', () {
    test('puts the useful address first for a real listen set', () {
      // Verbatim from a live node: a wildcard bind and two LAN addresses. The
      // collapsed line shows only the first, so a LAN address has to beat the
      // wildcard.
      final sorted = sortByScope([
        '/ip4/127.0.0.1/tcp/8080',
        '/ip4/192.168.68.135/tcp/8080',
        '/ip4/192.168.68.174/tcp/8080',
      ]);
      expect(sorted.first, '/ip4/192.168.68.135/tcp/8080');
      expect(sorted.last, '/ip4/127.0.0.1/tcp/8080');
    });

    test('a public address outranks everything', () {
      final sorted = sortByScope([
        '/ip4/127.0.0.1/tcp/8080',
        '/ip4/192.168.68.135/tcp/8080',
        '/ip4/98.232.246.19/tcp/8080',
      ]);
      expect(sorted.first, '/ip4/98.232.246.19/tcp/8080');
    });

    test('is stable within a scope', () {
      // The daemon ranks observed addresses by how many distinct peers
      // confirmed each; re-sorting must not discard that.
      final sorted = sortByScope([
        '/ip4/203.0.113.1/tcp/1',
        '/ip4/203.0.113.2/tcp/2',
        '/ip4/203.0.113.3/tcp/3',
      ]);
      expect(sorted, [
        '/ip4/203.0.113.1/tcp/1',
        '/ip4/203.0.113.2/tcp/2',
        '/ip4/203.0.113.3/tcp/3',
      ]);
    });

    test('keeps every address', () {
      final input = [
        '/ip4/127.0.0.1/tcp/8080',
        '/ip4/10.0.0.1/tcp/8080',
        '/ip4/98.232.246.19/tcp/8080',
      ];
      expect(sortByScope(input).toSet(), input.toSet());
      expect(sortByScope(input), hasLength(input.length));
    });

    test('handles empty and single-element lists', () {
      expect(sortByScope([]), isEmpty);
      expect(sortByScope(['/ip4/127.0.0.1/tcp/1']), ['/ip4/127.0.0.1/tcp/1']);
    });
  });

  group('shortenAddrPeerIds', () {
    const relay = '12D3KooWRelayExamplePeerIdentifierAAAAAAAAAAAAAAAAAAAA';

    test('elides the peer id and leaves the address whole', () {
      final short = shortenAddrPeerIds('/ip6/2001:db8::1/tcp/8080/p2p/$relay');
      // The port is what the elision used to eat on a long v6 multiaddr.
      expect(short, startsWith('/ip6/2001:db8::1/tcp/8080/p2p/'));
      expect(short, isNot(contains(relay)));
      expect(
        short.length,
        lessThan('/ip6/2001:db8::1/tcp/8080/p2p/$relay'.length),
      );
    });

    test('shortens every peer id in a circuit address', () {
      const self = '12D3KooWSelfExamplePeerIdentifierBBBBBBBBBBBBBBBBBBBB';
      final short = shortenAddrPeerIds(
        '/ip4/198.51.100.7/tcp/4001/p2p/$relay/p2p-circuit/p2p/$self',
      );
      expect(short, contains('/p2p-circuit/p2p/'));
      expect(short, isNot(contains(relay)));
      expect(short, isNot(contains(self)));
    });

    test('leaves an address with no peer id alone', () {
      expect(
        shortenAddrPeerIds('/ip4/203.0.113.7/tcp/8080'),
        '/ip4/203.0.113.7/tcp/8080',
      );
    });
  });
}
