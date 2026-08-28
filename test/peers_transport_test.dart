import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/p2p/transport.dart';

/// A node now listens on TCP *and* QUIC, so "direct" no longer says how a peer
/// was reached. Which transport carried a path is the interesting half when
/// hole punching is the thing being watched: a QUIC punch and a TCP punch are
/// different achievements, and only one of them is reliable through a NAT.
void main() {
  group('transportOf', () {
    test('reads the transport off a plain address', () {
      expect(transportOf(addr: '/ip4/198.18.0.31/tcp/8080'), 'tcp');
      expect(transportOf(addr: '/ip4/198.18.0.21/udp/8080/quic-v1'), 'quic');
    });

    test('a circuit reports the relay hop, which is what moves the bytes', () {
      expect(
        transportOf(
          addr:
              '/ip4/198.18.0.15/tcp/8000/p2p/QmbDHs/p2p-circuit/p2p/12D3KooWEYe',
        ),
        'tcp',
      );
      expect(
        transportOf(
          addr:
              '/ip4/198.18.0.15/udp/8080/quic-v1/p2p/QmbDHs/p2p-circuit/p2p/12D3',
        ),
        'quic',
      );
    });

    test('an inbound relayed connection falls back to via', () {
      // `addr` is a bare `/p2p/<peer>`: it says who reached us and nothing
      // about how. The relay address is the only place the transport appears.
      expect(
        transportOf(
          addr: '/p2p/12D3KooWEYe',
          via: '/ip4/198.18.0.14/udp/8080/quic-v1/p2p/QmTfGx/p2p-circuit',
        ),
        'quic',
      );
    });

    test('older peers advertising /quic rather than /quic-v1 still read', () {
      expect(transportOf(addr: '/ip4/1.2.3.4/udp/4001/quic'), 'quic');
    });

    test('null when nothing names a transport, rather than a guess', () {
      expect(transportOf(addr: '/p2p/12D3KooWEYe'), isNull);
      expect(transportOf(addr: ''), isNull);
    });
  });
}
