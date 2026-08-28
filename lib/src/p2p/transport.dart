/// Which transport a connection runs over, read off its multiaddr.
///
/// Kept beside [protocols.dart] rather than in the Peers page for the same
/// reason: the transport is a fact about the connection, not about a view.
library;

/// The transport named by `addr`, falling back to `via`.
///
/// An inbound relayed connection's `addr` is a bare `/p2p/<peer>` — it says who
/// reached us and nothing about how — so the relay address in `via` is what
/// carries the hop's transport. For a circuit address the answer is the relay
/// hop's transport, which is the one that actually moves the bytes.
///
/// Returns null when neither names a transport, which is the honest answer for
/// a bare `/p2p/<peer>` with no relay recorded.
String? transportOf({required String addr, String via = ''}) {
  final named = _names(addr) ? addr : (_names(via) ? via : null);
  if (named == null) return null;
  // `/quic-v1` today, `/quic` on older peers; both are QUIC to a reader.
  if (named.contains('/quic')) return 'quic';
  if (named.contains('/tcp/')) return 'tcp';
  return null;
}

bool _names(String addr) => addr.contains('/tcp/') || addr.contains('/quic');
