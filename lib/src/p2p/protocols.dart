/// Human descriptions for libp2p protocol ids.
///
/// Kept out of the Peers page because protocol identity is a property of the
/// network, not of a view: the CLI, a log formatter or a future diagnostics
/// screen all want the same mapping, and it should not have to import a
/// settings page to get it.
library;

/// What each libp2p protocol id means, in plain words.
///
/// Protocol ids are stable, versioned identifiers — a peer advertising
/// `/libp2p/dcutr` is saying something specific and unchanging — so a lookup
/// table is exact rather than a heuristic. Reading a peer's capabilities off
/// raw ids means knowing the ecosystem by heart; this is the difference between
/// "can this peer relay for me?" being obvious or requiring a search.
///
/// Unknown ids are shown verbatim rather than dropped: a peer running something
/// this build has never heard of is worth seeing, not hiding.
///
/// `+` matches one path segment — see [describeProtocol]. Versions are
/// wildcarded so a peer running a newer revision is still described rather than
/// falling through to its raw id.
///
/// Public for `test/peers_protocols_test.dart`.
const protocolDescriptions = <String, String>{
  // ── libp2p core ────────────────────────────────────────────────────────
  '/ipfs/id/+': 'Identify — exchanges peer id, addresses and capabilities',
  '/ipfs/id/push/+': 'Identify push — sends updates when its details change',
  // Note the namespace: /p2p/, not /ipfs/. An older extension that predates
  // the /ipfs/id/push/ naming, so it needs its own key rather than being
  // caught by an /ipfs/id/+ pattern.
  '/p2p/id/delta/+':
      'Identify delta — sends only the protocols that changed, not a full '
      'identify',
  '/ipfs/ping/+': 'Ping — liveness and round-trip time',
  '/ipfs/kad/+': 'Kademlia DHT — serves peer and content lookups',

  // ── NAT traversal ──────────────────────────────────────────────────────
  '/libp2p/autonat/+': 'AutoNAT — dials peers back to test their reachability',
  // The version sits *before* hop/stop here, which is why matching is by
  // segment rather than by prefix: a prefix match on /libp2p/circuit/relay/
  // would collapse these two, and they mean opposite roles.
  '/libp2p/circuit/relay/+/hop':
      'Circuit relay (hop) — willing to relay traffic for other peers',
  '/libp2p/circuit/relay/+/stop':
      'Circuit relay (stop) — can be reached through a relay',
  // v1 has no hop/stop suffix at all, so it is its own shape.
  '/libp2p/circuit/relay/0.1.0': 'Circuit relay v1 — legacy relay protocol',
  '/libp2p/dcutr': 'DCUtR — coordinates hole punching to upgrade relayed paths',

  // ── KwaaiNet ───────────────────────────────────────────────────────────
  '/kwaai/p2p/hello/+': 'Hello — accepts direct messages from any peer',
  '/kwaai/inference/+':
      'Inference — serves transformer blocks for distributed inference',
  '/kwaai/inference-mux/+':
      'Inference mux — concurrent GPU inference over one persistent stream',
  '/kwaai/ollama-proxy/+': 'Ollama proxy — tunnels HTTP inference to Ollama',
  '/kwaai/shard-proxy/+':
      'Shard proxy — tunnels HTTP inference to the local shard API',

  // ── hivemind DHT ───────────────────────────────────────────────────────
  'DHTProtocol.rpc_ping': 'Hivemind DHT — liveness probe',
  'DHTProtocol.rpc_store': 'Hivemind DHT — stores records',
  'DHTProtocol.rpc_find': 'Hivemind DHT — serves record lookups',
};

/// A protocol id without its trailing version segment, so ids that differ only
/// by version compare equal: `/kwaai/inference/1.0.0` and `…/2.0.0` are both
/// `/kwaai/inference`. An id whose last segment is not a version (`/libp2p/dcutr`)
/// is its own family.
String protocolFamily(String id) {
  final cut = id.lastIndexOf('/');
  if (cut <= 0) return id;
  return _version.hasMatch(id.substring(cut + 1)) ? id.substring(0, cut) : id;
}

final _version = RegExp(r'^\d+(\.\d+)*$');

/// The protocols in [advertised], one entry per family, sorted — a discovered
/// list, not a curated one: whatever ids the caller has actually seen, however
/// many sources it concatenated them from.
///
/// Maps each family to the first advertised id carrying it, so a caller can
/// still reach the versioned form — [describeProtocol]'s wildcard keys match
/// full ids, not families.
///
/// Public for `test/peers_protocol_filter_test.dart`.
Map<String, String> protocolFamilies(Iterable<String> advertised) {
  final byFamily = <String, String>{};
  for (final id in advertised) {
    byFamily.putIfAbsent(protocolFamily(id), () => id);
  }
  return Map.fromEntries(
    byFamily.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
}

/// A human description for `id`, or the id itself when unrecognised.
///
/// Keys may contain `+`, which matches exactly one path segment — MQTT's
/// single-level wildcard, chosen over glob's `*` because that is precisely the
/// distinction that matters here. `*` reads as "match anything" and invites
/// `/libp2p/circuit/relay/*`, which would span segments and collapse hop into
/// stop; `+` says "one segment" to anyone who has touched MQTT.
///
/// So `/ipfs/kad/+` describes 1.0.0 and every later version, while
/// `/libp2p/circuit/relay/+/hop` stays distinct from `…/+/stop`. That pair is
/// why matching is per segment rather than by prefix at all: libp2p has no
/// convention putting the version last, and circuit relay puts the
/// discriminator *after* it, so a prefix match on `/libp2p/circuit/relay/`
/// would merge "will relay for others" with "reachable through a relay".
///
/// Exact keys win over wildcard ones, so a specific version can be described
/// differently from its family when that ever matters.
///
/// Public for `test/peers_protocols_test.dart`.
String describeProtocol(String id) {
  final exact = protocolDescriptions[id];
  if (exact != null) return exact;

  final segments = id.split('/');
  for (final entry in protocolDescriptions.entries) {
    if (!entry.key.contains('+')) continue;
    final pattern = entry.key.split('/');
    if (pattern.length != segments.length) continue;
    var matches = true;
    for (var i = 0; i < pattern.length; i++) {
      if (pattern[i] != '+' && pattern[i] != segments[i]) {
        matches = false;
        break;
      }
    }
    if (matches) return entry.value;
  }
  return id;
}
