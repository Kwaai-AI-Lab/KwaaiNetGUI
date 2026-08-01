import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/generated/kwaai.pb.dart' as pb;
import '../../chat/generated/kwaai.pbenum.dart' as pbenum;
import '../../chat/session_client.dart';
import '../../daemon/daemon_state.dart';
import '../../daemon/peers_state.dart';
import '../theme/kwaai_theme.dart';
import '../widgets/service_status_view.dart';

/// How long without an update before the view is marked stale.
///
/// The daemon suppresses snapshots that would say nothing new but still sends
/// an unchanged one every 60 s, so silence up to that point is normal and
/// healthy. This clears that heartbeat with enough margin to absorb a slow
/// tick without crying wolf — past it, the daemon has missed a beat it
/// promised to send.
///
/// Keep this comfortably above the daemon's HEARTBEAT (grpc_server.rs), which
/// the network op shares with block coverage and storage discovery. If that
/// interval changes, this has to move with it — the relationship is asserted
/// in `test/peers_staleness_test.dart`, which is why this is public.
const peersStaleAfter = Duration(seconds: 100);

/// How often to re-evaluate staleness while no updates arrive.
const peersStaleTick = Duration(seconds: 5);

/// Height of the table's caption bar. Fixed rather than intrinsic so the bar
/// is identical whatever it contains. Mirrors the Sharding and VPK tabs.
const _captionBarHeight = 28.0;

/// Settings tab showing this node's place in the p2p network: whether it is
/// reachable, who it is connected to, and who it knows how to find — the same
/// view `kwaainet p2p peers list` prints in the terminal, plus the parts that
/// command cannot see.
///
/// Named "Peers" in the sidebar to leave the existing Network tab (bind
/// address, initial peers, privacy) its name. The wire operation is still
/// called `network`, because it reports more than peers.
///
/// Data arrives through [peersProvider]. Connections and the routing table
/// are sampled every few seconds; a reachability change is pushed as it
/// happens. `update.reason` distinguishes the two, which is what lets the
/// reachability badge react immediately without the peer table pretending
/// every tick is news.
///
/// Requires the daemon to be running the native p2p stack. Against the Go p2p
/// daemon the operation is unimplemented — most of this view has no wire
/// representation there — and the page says so rather than showing a table
/// that is mostly blank.
class PeersTab extends ConsumerStatefulWidget {
  const PeersTab({super.key});

  @override
  ConsumerState<PeersTab> createState() => _PeersTabState();
}

class _PeersTabState extends ConsumerState<PeersTab> {
  /// Peer id highlighted in the tables. Null = nothing highlighted.
  String? _selectedPeerId;

  /// Last update we rendered. The subscription is torn down and re-opened
  /// across daemon reconnects; holding the last snapshot keeps the view stable
  /// (rather than flashing back to a spinner) through the gap.
  pb.NetworkUpdate? _last;

  /// When [_last] arrived, for the staleness check.
  ///
  /// Local arrival time rather than the update's own `serverTime`: the question
  /// is "how long since this daemon last told us anything", which a clock skew
  /// between the two machines shouldn't distort.
  DateTime? _lastArrived;

  /// Drives a rebuild while no updates are arriving, so the staleness cue can
  /// appear during silence. Nothing else would rebuild the view.
  Timer? _staleTicker;

  /// Whether the view was stale at the last tick.
  ///
  /// The ticker only calls setState when this *changes*. Rebuilding the whole
  /// page every 5s to redraw one chip is what makes a tab with two data tables
  /// on it feel wedged — the staleness cue is a binary state, so it only needs
  /// a rebuild when it flips.
  bool _wasStale = false;

  @override
  void initState() {
    super.initState();
    _staleTicker = Timer.periodic(peersStaleTick, (_) {
      if (!mounted) return;
      final arrived = _lastArrived;
      final stale =
          arrived != null &&
          DateTime.now().difference(arrived) > peersStaleAfter;
      if (stale != _wasStale) {
        setState(() => _wasStale = stale);
      }
    });
  }

  @override
  void dispose() {
    _staleTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final network = ref.watch(peersProvider);
    final fresh = network.valueOrNull;
    // Identity, not equality: `valueOrNull` re-serves the last emitted value on
    // every rebuild, so stamping the arrival time whenever it is non-null would
    // reset the clock each tick and the staleness cue could never fire. Only a
    // genuinely new object is a new arrival.
    if (fresh != null && !identical(fresh, _last)) {
      _last = fresh;
      _lastArrived = DateTime.now();
    }
    final update = _last;

    if (update == null) {
      // Every error here means the same thing to the user — there is no
      // network information to show — and the GUI cannot honestly tell the
      // causes apart. `INVALID_ARGUMENT "ClientFrame missing body"` is what an
      // older daemon returns for an operation it has never heard of, but it is
      // also its catch-all for any frame it cannot decode. Claiming "your
      // daemon is too old" off that would be a guess presented as a diagnosis,
      // and wrong if it ever fires for a genuine encoding bug.
      //
      // So: one honest headline, with the daemon's own words underneath as
      // secondary detail — accurate where it is specific, self-evidently
      // generic where it is not.
      final err = network.error;
      if (err != null) {
        return ServiceStatusView(
          headline: 'Network information is not available',
          spinner: false,
          subtitle: _UnavailableDetail(error: err),
        );
      }

      final running =
          ref.watch(daemonStatusProvider).valueOrNull?.running ?? false;
      return ServiceStatusView(
        headline: running
            ? 'Reading the local p2p state…'
            : 'Daemon is not running',
        spinner: running,
        subtitle: running
            ? null
            : const Text('Start it from the Status tab to see the network.'),
      );
    }

    final arrived = _lastArrived;
    final staleFor = arrived == null
        ? null
        : DateTime.now().difference(arrived);
    final stale = staleFor != null && staleFor > peersStaleAfter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: _SelfStatusHeader(
            self: update.hasSelfStatus() ? update.selfStatus : null,
            connectedCount: update.connected.length,
            routingCount: update.routing.length,
            stale: stale,
            staleFor: staleFor,
          ),
        ),
        Divider(height: 1, color: context.kwaai.divider),
        Expanded(
          child: _TableSection(
            connected: update.connected,
            routing: update.routing,
            selectedPeerId: _selectedPeerId,
            onSelectPeer: _togglePeer,
          ),
        ),
      ],
    );
  }

  void _togglePeer(String peerId) => setState(() {
    _selectedPeerId = _selectedPeerId == peerId ? null : peerId;
  });
}

/// Secondary detail under the unavailable headline: the daemon's own message,
/// plus the one actionable hint we can offer without guessing.
class _UnavailableDetail extends StatelessWidget {
  const _UnavailableDetail({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
    );

    // Only surfaced for the one code that names a specific, fixable cause.
    // Anything else gets the message alone.
    final needsNative =
        error is SessionOpError &&
        (error as SessionOpError).code == _unimplemented;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            error is SessionOpError
                ? (error as SessionOpError).message
                : error.toString(),
            style: muted,
            textAlign: TextAlign.center,
          ),
        ),
        if (needsNative) ...[
          const SizedBox(height: 10),
          SelectableText(
            'kwaainet config set native_p2p true',
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'Menlo',
              fontFamilyFallback: const ['Consolas', 'monospace'],
            ),
          ),
        ],
      ],
    );
  }
}

/// `Error.Code.UNIMPLEMENTED` from kwaai.proto.
const _unimplemented = 6;

/// Copies a value to the clipboard.
///
/// Replaces selectable text on this page: the addresses and peer ids here are
/// the things a user wants to paste elsewhere, but making them selectable costs
/// a text-editing pipeline per line on every rebuild, and this page rebuilds
/// often. A button is built once and does the same job.
class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.text, required this.label});

  final String text;
  final String label;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.copy_outlined, size: 13),
      iconSize: 13,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      tooltip: 'Copy $label',
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: text));
        if (!context.mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text('$label copied'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }
}

/// This node's own position: reachability, relay use, and the addresses it
/// listens on or has been observed at.
class _SelfStatusHeader extends StatelessWidget {
  const _SelfStatusHeader({
    required this.self,
    required this.connectedCount,
    required this.routingCount,
    required this.stale,
    required this.staleFor,
  });

  final pb.SelfStatus? self;
  final int connectedCount;
  final int routingCount;
  final bool stale;
  final Duration? staleFor;

  @override
  Widget build(BuildContext context) {
    final kwaai = context.kwaai;
    final theme = Theme.of(context);
    final s = self;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wrap, not Row: the badge text grows with the reachability source and
        // the counts grow with the network, so on a narrow window this line
        // genuinely cannot fit. Wrapping re-flows it instead of overflowing.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: [
            Text('This node', style: theme.textTheme.titleSmall),
            if (s != null) _ReachabilityBadge(self: s),
            if (stale && staleFor != null)
              _StaleChip(staleFor: staleFor!)
            else
              Text(
                '$connectedCount connected · $routingCount in routing table',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: 0.75,
                  ),
                ),
              ),
          ],
        ),
        if (s != null) ...[
          const SizedBox(height: 8),
          _AddressLine(label: 'Peer ID', values: [s.peerId]),
          // Each of these collapses to its first entry, so scope order decides
          // what the user sees without expanding: the public address if there
          // is one, then LAN, then loopback or a wildcard bind.
          if (s.listenAddrs.isNotEmpty)
            _AddressLine(
              label: 'Listening',
              values: sortByScope(s.listenAddrs),
            ),
          if (s.observedAddrs.isNotEmpty)
            _AddressLine(
              label: 'Observed',
              values: sortByScope(summariseObservedAddrs(s.observedAddrs)),
            ),
          if (s.relayAddrs.isNotEmpty)
            _AddressLine(label: 'Relays', values: sortByScope(s.relayAddrs)),
        ],
        if (s == null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Reachability not yet determined.',
              style: theme.textTheme.bodySmall?.copyWith(color: kwaai.divider),
            ),
          ),
      ],
    );
  }
}

/// Public / private / unknown, with what produced the verdict.
///
/// "Unknown" is a real state, not a loading state: the node defers announcing
/// while it holds, so showing it plainly matters more than hiding it behind a
/// spinner.
class _ReachabilityBadge extends StatelessWidget {
  const _ReachabilityBadge({required this.self});

  final pb.SelfStatus self;

  @override
  Widget build(BuildContext context) {
    final kwaai = context.kwaai;
    final (label, color) = switch (self.reachability) {
      'public' => ('Public', kwaai.statusRunning),
      'private' => ('Private', kwaai.semanticWarning),
      _ => ('Reachability unknown', kwaai.statusTransitioning),
    };

    final parts = <String>[
      label,
      if (self.reachabilitySource.isNotEmpty) 'via ${self.reachabilitySource}',
      if (self.usingRelay) 'relayed',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        parts.join(' · '),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StaleChip extends StatelessWidget {
  const _StaleChip({required this.staleFor});

  final Duration staleFor;

  @override
  Widget build(BuildContext context) {
    final kwaai = context.kwaai;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kwaai.semanticWarning.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'No update for ${staleFor.inSeconds}s',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: kwaai.semanticWarning),
      ),
    );
  }
}

/// One labelled row of addresses, collapsed to a single line.
///
/// A node routinely listens on several addresses, is observed at more, and can
/// hold multiple relay reservations — so left unbounded these three lines
/// dominate the header and push the tables off screen. Only the first is shown;
/// the rest are one click away.
///
/// The first is the useful one by construction: listen addresses come in
/// binding order, observed addresses are ranked most-confirmed first by the
/// daemon, and relay addresses are all equivalent.
class _AddressLine extends StatefulWidget {
  const _AddressLine({
    required this.label,
    required this.values,
    this.mono = true,
  });

  final String label;
  final List<String> values;

  /// Monospace the values. True for addresses and peer ids, where character
  /// alignment aids comparison; false for prose, which reads badly in mono.
  final bool mono;

  @override
  State<_AddressLine> createState() => _AddressLineState();
}

class _AddressLineState extends State<_AddressLine> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kwaai = context.kwaai;
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
    );
    final monoStyle = widget.mono
        ? theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'Menlo',
            fontFamilyFallback: const ['Consolas', 'monospace'],
          )
        : theme.textTheme.bodySmall;

    final values = widget.values;
    final hidden = values.length - 1;
    final shown = _expanded ? values : values.take(1).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 74, child: Text(widget.label, style: labelStyle)),
          Expanded(
            // Plain Text, not SelectableText. This page rebuilds on every
            // update *and* every stale tick, and each SelectableText builds a
            // gesture-recognizer and text-editing pipeline on construction —
            // enough, repeated across the address lines, to blow the frame
            // budget and make the tab feel wedged. Copying an address is served
            // by the tap-to-copy button instead, which costs nothing to build.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < shown.length; i++)
                  Row(
                    children: [
                      // One Text per value, each clipped to a single line.
                      // Joining them into one Text and capping maxLines
                      // silently dropped entries once a multiaddr wrapped —
                      // the count said "and 4 more" while only four of five
                      // were rendered.
                      //
                      // softWrap false + ellipsis: a multiaddr has no break
                      // opportunities, so left to wrap it would force the row
                      // wider than the viewport.
                      Expanded(
                        child: Text(
                          shown[i],
                          style: monoStyle,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      // The toggle rides the first line's right edge rather
                      // than sitting on a line of its own: it costs no vertical
                      // space, and the address it shares the row with truncates
                      // to make room.
                      if (hidden > 0 && i == 0) ...[
                        const SizedBox(width: 8),
                        // A plain tappable Text rather than a TextButton: this
                        // page rebuilds often and Material buttons bring an ink
                        // controller each. No animation, no per-frame cost.
                        GestureDetector(
                          onTap: () => setState(() => _expanded = !_expanded),
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            _expanded ? 'show less' : 'and $hidden more',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: kwaai.accentPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
          if (values.isNotEmpty)
            // Copies every value, not just the visible one — the collapse is a
            // display choice and shouldn't quietly narrow what you get.
            _CopyButton(text: values.join('\n'), label: widget.label),
        ],
      ),
    );
  }
}

/// The two peer tables, stacked.
///
/// Deliberately two sections rather than one merged table: the connected set
/// and the routing table overlap without either containing the other, so
/// nesting them would imply a containment that does not hold. The `IN TABLE` /
/// `CONNECTED` columns make the overlap visible instead.
///
/// Each section gets a *bounded* share of the height and scrolls internally.
/// That bound is load-bearing, not cosmetic: a `DataTable` sizes itself to its
/// content, and inside a vertically-scrolling parent it is laid out against an
/// unbounded height, which costs ~25ms per frame at twenty rows versus ~0.1ms
/// when bounded. Putting these tables in a ListView is what made this page
/// feel like it hung. `test/peers_layout_test.dart` measures it.
class _TableSection extends StatelessWidget {
  const _TableSection({
    required this.connected,
    required this.routing,
    required this.selectedPeerId,
    required this.onSelectPeer,
  });

  final List<pb.ConnectedPeer> connected;
  final List<pb.RoutingPeer> routing;
  final String? selectedPeerId;
  final void Function(String peerId) onSelectPeer;

  @override
  Widget build(BuildContext context) {
    final rows = mergePeerRows(connected, routing);

    final selected = selectedPeerId == null
        ? null
        : rows.where((r) => r.peerId == selectedPeerId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Caption(title: 'PEERS', detail: _summary(rows)),
        Expanded(
          child: rows.isEmpty
              ? const _EmptyRow(text: 'No peers known.')
              : _PeerTable(
                  rows: rows,
                  selectedPeerId: selectedPeerId,
                  onSelectPeer: onSelectPeer,
                ),
        ),
        // Detail for the selected peer, pinned below the table rather than
        // spliced into it. A DataRow cannot span columns, so an inline detail
        // had to live in one cell and overflowed it; down here it gets the full
        // width and the table keeps its alignment. It also stays put while the
        // table scrolls, which is what you want when comparing a peer's detail
        // against the rows around it.
        if (selected != null) ...[
          Divider(height: 1, color: context.kwaai.divider),
          // Bounded and scrollable: a peer can hold several connections and a
          // long protocol list, and the panel must not push the table off
          // screen or overflow the page.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 190),
            child: SingleChildScrollView(
              child: _PeerConnections(row: selected),
            ),
          ),
        ],
      ],
    );
  }

  String? _summary(List<PeerRow> rows) {
    if (rows.isEmpty) return null;
    final live = rows.where((r) => r.isConnected).length;
    final dht = rows.where((r) => r.inRoutingTable).length;
    return '$live connected · $dht in routing table';
  }
}

/// One peer, however we know about it.
///
/// The connected set and the DHT routing table overlap without either
/// containing the other, and a peer can be in one, the other, or both:
///
/// * **both** — a DHT-speaking peer we hold a connection to;
/// * **connected only** — typically a client-mode node that does not speak
///   `/ipfs/kad/1.0.0`, so it is deliberately never added to the routing table;
/// * **routing only** — a peer we know how to reach but have no live
///   connection to.
///
/// Presenting those as two tables forced the reader to cross-reference them to
/// notice the middle case at all. One row per peer with two state columns makes
/// all three legible at a glance, and answers "why isn't this peer in my
/// routing table?" without leaving the page.
///
/// Public for `test/peers_merge_test.dart`.
class PeerRow {
  const PeerRow({
    required this.peerId,
    required this.connections,
    required this.inRoutingTable,
    required this.isBootstrap,
    required this.isTrustedRelay,
  });

  final String peerId;

  /// Every live connection to this peer, in the daemon's order. Empty for a
  /// routing-only peer.
  ///
  /// More than one is normal and interesting: a peer mid-hole-punch holds both
  /// a relayed path and the direct one DCUtR built, which is what the expanded
  /// row shows.
  final List<pb.ConnectedPeer> connections;

  final bool inRoutingTable;
  final bool isBootstrap;
  final bool isTrustedRelay;

  bool get isConnected => connections.isNotEmpty;

  /// The connection the collapsed row describes.
  ///
  /// Prefers a direct path over a relayed one: if a peer is reachable both
  /// ways, the direct path is the one that matters, and showing the relay
  /// would understate the connection.
  pb.ConnectedPeer? get primary {
    if (connections.isEmpty) return null;
    for (final c in connections) {
      if (c.kind == pbenum.PeerConnKind.PEER_CONN_KIND_DIRECT) return c;
    }
    return connections.first;
  }

  /// Whether any connection to this peer was upgraded by DCUtR.
  bool get anyDcutr => connections.any((c) => c.dcutr);
}

/// Merge the two peer sets into one row per peer, in display order.
///
/// Ordering follows `kwaainet p2p peers list`: bootstrap → trusted relay →
/// direct → relayed → routing-only, then by peer id. Keeping the CLI's grouping
/// means both surfaces describe the same network the same way, and puts the
/// peers the operator explicitly configured where they will look first.
///
/// Public for `test/peers_merge_test.dart`.
List<PeerRow> mergePeerRows(
  List<pb.ConnectedPeer> connected,
  List<pb.RoutingPeer> routing,
) {
  final routingById = {for (final r in routing) r.peerId: r};
  final byPeer = <String, List<pb.ConnectedPeer>>{};
  for (final c in connected) {
    (byPeer[c.peerId] ??= []).add(c);
  }

  final rows = <PeerRow>[];
  for (final entry in byPeer.entries) {
    final conns = entry.value;
    rows.add(
      PeerRow(
        peerId: entry.key,
        connections: conns,
        inRoutingTable: routingById.containsKey(entry.key),
        // Read off the connection: the daemon has already applied local
        // configuration there, and a routing entry carries the same flag.
        isBootstrap: conns.any((c) => c.isBootstrap),
        isTrustedRelay: conns.any((c) => c.isTrustedRelay),
      ),
    );
  }
  for (final r in routing) {
    if (byPeer.containsKey(r.peerId)) continue;
    rows.add(
      PeerRow(
        peerId: r.peerId,
        connections: const [],
        inRoutingTable: true,
        isBootstrap: r.isBootstrap,
        isTrustedRelay: false,
      ),
    );
  }

  int group(PeerRow r) {
    if (r.isBootstrap) return 0;
    if (r.isTrustedRelay) return 1;
    final p = r.primary;
    if (p == null) return 4; // routing-only, no connection to classify
    return p.kind == pbenum.PeerConnKind.PEER_CONN_KIND_RELAY ? 3 : 2;
  }

  rows.sort((a, b) {
    final byGroup = group(a).compareTo(group(b));
    return byGroup != 0 ? byGroup : a.peerId.compareTo(b.peerId);
  });
  return rows;
}

/// The merged peer table. One row per peer; selecting a row expands it.
class _PeerTable extends StatelessWidget {
  const _PeerTable({
    required this.rows,
    required this.selectedPeerId,
    required this.onSelectPeer,
  });

  final List<PeerRow> rows;
  final String? selectedPeerId;
  final void Function(String peerId) onSelectPeer;

  @override
  Widget build(BuildContext context) {
    final kwaai = context.kwaai;
    final theme = Theme.of(context);
    final headStyle = theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.6);
    final cellStyle = theme.textTheme.bodySmall;
    final monoStyle = cellStyle?.copyWith(
      fontFamily: 'Menlo',
      fontFamilyFallback: const ['Consolas', 'monospace'],
    );
    final selectedFill = kwaai.accentPrimary.withValues(alpha: 0.16);
    final muted = theme.dividerColor;

    // Vertical scroll outside, horizontal inside — the nesting the VPK table
    // uses. The outer one gives the DataTable a bounded height to lay out
    // against; without it the table is measured against infinity every frame.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowHeight: 32,
              dataRowMinHeight: 30,
              dataRowMaxHeight: 34,
              columnSpacing: 20,
              horizontalMargin: 16,
              showCheckboxColumn: false,
              columns: [
                DataColumn(label: Text('CONN', style: headStyle)),
                DataColumn(label: Text('DHT', style: headStyle)),
                DataColumn(label: Text('PATH', style: headStyle)),
                DataColumn(label: Text('DIR', style: headStyle)),
                DataColumn(label: Text('RTT', style: headStyle), numeric: true),
                DataColumn(label: Text('ROLE', style: headStyle)),
                DataColumn(label: Text('VERSION', style: headStyle)),
                DataColumn(label: Text('PEER ID', style: headStyle)),
                DataColumn(label: Text('ADDRESS', style: headStyle)),
              ],
              rows: [
                for (final r in rows)
                  DataRow(
                    selected: r.peerId == selectedPeerId,
                    color: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? selectedFill
                          : null,
                    ),
                    onSelectChanged: (_) => onSelectPeer(r.peerId),
                    cells: [
                      DataCell(_StateMark(on: r.isConnected)),
                      DataCell(_StateMark(on: r.inRoutingTable)),
                      DataCell(
                        r.primary == null
                            ? Text('—', style: cellStyle)
                            : _PathCell(
                                kind: r.primary!.kind,
                                dcutr: r.anyDcutr,
                              ),
                      ),
                      DataCell(
                        Text(r.primary?.direction ?? '—', style: cellStyle),
                      ),
                      DataCell(
                        Text(
                          // 0 means no ping has completed yet, not zero latency.
                          (r.primary?.rttMs ?? 0) == 0
                              ? '—'
                              : '${r.primary!.rttMs} ms',
                          style: cellStyle,
                        ),
                      ),
                      DataCell(_RoleCell(row: r)),
                      DataCell(
                        Text(
                          r.primary?.agentVersion.isNotEmpty ?? false
                              ? r.primary!.agentVersion
                              : '—',
                          style: cellStyle,
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_shortPeerId(r.peerId), style: monoStyle),
                            // Only the count, and only when there is more than
                            // one — the paths themselves are in the panel below.
                            if (r.connections.length > 1) ...[
                              const SizedBox(width: 6),
                              Text(
                                '×${r.connections.length}',
                                style: cellStyle?.copyWith(color: muted),
                              ),
                            ],
                          ],
                        ),
                      ),
                      DataCell(Text(r.primary?.addr ?? '—', style: monoStyle)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A check or a dash for a boolean state column.
class _StateMark extends StatelessWidget {
  const _StateMark({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final kwaai = context.kwaai;
    return Icon(
      on ? Icons.check : Icons.remove,
      size: 14,
      color: on ? kwaai.statusRunning : Theme.of(context).dividerColor,
    );
  }
}

/// The selected peer's connections, one row each.
///
/// The peers table shows one row per peer and says nothing about *how* it is
/// reached; this is where that lives. Keeping it out of the table means the
/// table stays one row per peer no matter how many paths a peer holds, and a
/// peer mid-hole-punch — relayed path still open, direct one just built — shows
/// both here without the row count moving.
///
/// Pinned below the table rather than spliced into it: a DataRow cannot span
/// columns, so an inline detail had to live inside one cell and overflowed it.
class _PeerConnections extends StatelessWidget {
  const _PeerConnections({required this.row});

  final PeerRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kwaai = context.kwaai;
    final monoStyle = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'Menlo',
      fontFamilyFallback: const ['Consolas', 'monospace'],
    );
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      letterSpacing: 0.6,
      color: theme.textTheme.labelSmall?.color?.withValues(alpha: 0.75),
    );

    // Protocols come from identify, which happens once per peer rather than
    // once per connection.
    final protocols = row.primary?.protocols ?? const <String>[];

    return Container(
      width: double.infinity,
      color: kwaai.accentPrimary.withValues(alpha: 0.06),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Always plural: "CONNECTIONS" heads the section whatever it
              // contains, rather than the count changing the noun.
              Text('${row.connections.length} CONNECTIONS', style: labelStyle),
              const SizedBox(width: 14),
              Text('Peer ID', style: labelStyle),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  row.peerId,
                  style: monoStyle,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _CopyButton(text: row.peerId, label: 'Peer ID'),
            ],
          ),
          if (row.connections.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                // A routing-table entry we hold no connection to. Normal: the
                // table deliberately retains peers we are not talking to.
                'Known from the DHT routing table; not currently connected.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: 0.7,
                  ),
                ),
              ),
            )
          else
            for (final c in row.connections)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Wide enough for "DCUtR" and its icon, which need more
                    // room than the 74px label column beside them.
                    SizedBox(
                      width: 88,
                      child: _PathCell(kind: c.kind, dcutr: c.dcutr),
                    ),
                    SizedBox(
                      width: 72,
                      child: Text(
                        c.direction,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(
                        c.rttMs == 0 ? '—' : '${c.rttMs} ms',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        c.addr,
                        style: monoStyle,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _CopyButton(text: c.addr, label: 'Address'),
                  ],
                ),
              ),
          const SizedBox(height: 6),
          if (protocols.isEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 74,
                  child: Text('Protocols', style: labelStyle),
                ),
                Expanded(
                  child: Text(
                    // Not "speaks nothing": identify completes shortly after
                    // the connection does, and a routing-only peer has no
                    // connection to have identified over.
                    row.isConnected
                        ? 'Identify has not completed yet'
                        : 'Not connected',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            )
          else
            // One per line, described rather than listed as raw ids, and
            // collapsed to the first — a peer advertises a dozen and the panel
            // should not be mostly protocol list. Reuses the same collapse the
            // address lines use, so the interaction is identical.
            _AddressLine(
              label: 'Protocols',
              values: [for (final p in protocols) describeProtocol(p)],
              mono: false,
            ),
        ],
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({required this.title, this.detail});

  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      letterSpacing: 0.6,
      fontWeight: FontWeight.w600,
      color: theme.textTheme.labelSmall?.color?.withValues(alpha: 0.75),
    );
    return Container(
      height: _captionBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Row(
        // Title left, summary hard against the right edge.
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: style),
          if (detail != null) ...[
            // Flexible + ellipsis: the summary grows with the network ("15
            // connected · 3 in routing table"), so on a narrow window it has to
            // give way rather than push the bar wider than the viewport.
            Flexible(
              child: Text(
                detail!,
                style: theme.textTheme.bodySmall,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.65),
        ),
      ),
    );
  }
}

/// How the connection reaches the peer: relayed, plain direct, or direct via
/// DCUtR.
///
/// DCUtR is called out by name rather than folded into "direct" because the two
/// are not the same achievement: a plain direct path means there was no NAT in
/// the way, while a DCUtR path means one was traversed. On a node reporting
/// private reachability the latter is the difference between "nothing works"
/// and "hole punching is working".
class _PathCell extends StatelessWidget {
  const _PathCell({required this.kind, this.dcutr = false});

  final pbenum.PeerConnKind kind;
  final bool dcutr;

  @override
  Widget build(BuildContext context) {
    final kwaai = context.kwaai;
    final relayed = kind == pbenum.PeerConnKind.PEER_CONN_KIND_RELAY;
    final (label, icon, color) = relayed
        ? ('relay', Icons.alt_route, kwaai.semanticWarning)
        : dcutr
        ? ('DCUtR', Icons.bolt, kwaai.accentPrimary)
        : ('direct', Icons.arrow_right_alt, kwaai.statusRunning);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// Bootstrap / trusted-relay labelling. Both reflect configuration the
/// operator explicitly chose, which is why they are called out rather than
/// left to be inferred from the peer id.
class _RoleCell extends StatelessWidget {
  const _RoleCell({required this.row});

  final PeerRow row;

  @override
  Widget build(BuildContext context) {
    final kwaai = context.kwaai;
    final theme = Theme.of(context);
    if (row.isBootstrap) {
      return Text(
        'bootstrap',
        style: theme.textTheme.bodySmall?.copyWith(color: kwaai.accentPrimary),
      );
    }
    if (row.isTrustedRelay) {
      return Text(
        'trusted relay',
        style: theme.textTheme.bodySmall?.copyWith(color: kwaai.semanticInfo),
      );
    }
    return Text('—', style: theme.textTheme.bodySmall);
  }
}

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
/// Public for `test/peers_protocols_test.dart`.
const protocolDescriptions = <String, String>{
  // ── libp2p core ────────────────────────────────────────────────────────
  '/ipfs/id/1.0.0': 'Identify — exchanges peer id, addresses and capabilities',
  '/ipfs/id/push/1.0.0':
      'Identify push — sends updates when its details change',
  '/ipfs/ping/1.0.0': 'Ping — liveness and round-trip time',
  '/ipfs/kad/1.0.0': 'Kademlia DHT — serves peer and content lookups',

  // ── NAT traversal ──────────────────────────────────────────────────────
  '/libp2p/autonat/1.0.0':
      'AutoNAT — dials peers back to test their reachability',
  '/libp2p/circuit/relay/0.2.0/hop':
      'Circuit relay (hop) — willing to relay traffic for other peers',
  '/libp2p/circuit/relay/0.2.0/stop':
      'Circuit relay (stop) — can be reached through a relay',
  '/libp2p/circuit/relay/0.1.0': 'Circuit relay v1 — legacy relay protocol',
  '/libp2p/dcutr': 'DCUtR — coordinates hole punching to upgrade relayed paths',

  // ── KwaaiNet ───────────────────────────────────────────────────────────
  '/kwaai/p2p/hello/1.0.0': 'Hello — accepts direct messages from any peer',
  '/kwaai/inference/1.0.0':
      'Inference — serves transformer blocks for distributed inference',
  '/kwaai/inference-mux/1.0.0':
      'Inference mux — concurrent GPU inference over one persistent stream',
  '/kwaai/ollama-proxy/1.0.0':
      'Ollama proxy — tunnels HTTP inference to Ollama',
  '/kwaai/shard-proxy/1.0.0':
      'Shard proxy — tunnels HTTP inference to the local shard API',

  // ── hivemind DHT ───────────────────────────────────────────────────────
  'DHTProtocol.rpc_ping': 'Hivemind DHT — liveness probe',
  'DHTProtocol.rpc_store': 'Hivemind DHT — stores records',
  'DHTProtocol.rpc_find': 'Hivemind DHT — serves record lookups',
};

/// A human description for `id`, or the id itself when unrecognised.
///
/// Public for `test/peers_protocols_test.dart`.
String describeProtocol(String id) => protocolDescriptions[id] ?? id;

/// How widely reachable an address is. Ordering is the ranking.
///
/// Public for `test/peers_address_summary_test.dart`.
enum AddrScope {
  /// Routable from the internet — the address that determines whether anyone
  /// outside can reach this node, so it leads.
  public,

  /// RFC1918 / CGNAT / link-local — reachable from the same network only.
  internal,

  /// Loopback, or a wildcard bind that names no interface at all.
  local,
}

/// Classify a multiaddr by how far it reaches.
///
/// Deliberately coarse: the question this answers is "which of these lines do I
/// show first", not "what exactly is this address". Anything unrecognised
/// counts as public so a new transport ranks high rather than being buried.
///
/// Public for `test/peers_address_summary_test.dart`.
AddrScope scopeOf(String addr) {
  final parts = addr.split('/')..removeWhere((p) => p.isEmpty);
  // A circuit address reaches as far as its relay does, which is public by
  // definition — nobody reserves a circuit on a LAN-only relay.
  if (parts.contains('p2p-circuit')) return AddrScope.public;

  final ipIdx = parts.indexWhere((p) => p == 'ip4' || p == 'ip6');
  if (ipIdx < 0 || ipIdx + 1 >= parts.length) return AddrScope.public;
  final host = parts[ipIdx + 1];

  if (host == '0.0.0.0' ||
      host == '::' ||
      host.startsWith('127.') ||
      host == '::1') {
    return AddrScope.local;
  }

  if (parts[ipIdx] == 'ip6') {
    final h = host.toLowerCase();
    // fc00::/7 unique-local, fe80::/10 link-local.
    if (h.startsWith('fc') ||
        h.startsWith('fd') ||
        h.startsWith('fe8') ||
        h.startsWith('fe9') ||
        h.startsWith('fea') ||
        h.startsWith('feb')) {
      return AddrScope.internal;
    }
    return AddrScope.public;
  }

  final octets = host.split('.');
  if (octets.length != 4) return AddrScope.public;
  final a = int.tryParse(octets[0]);
  final b = int.tryParse(octets[1]);
  if (a == null || b == null) return AddrScope.public;

  // RFC1918, plus CGNAT (100.64/10) and link-local (169.254/16): all of them
  // mean "someone on my network can reach this, nobody else can".
  if (a == 10) return AddrScope.internal;
  if (a == 192 && b == 168) return AddrScope.internal;
  if (a == 172 && b >= 16 && b <= 31) return AddrScope.internal;
  if (a == 100 && b >= 64 && b <= 127) return AddrScope.internal;
  if (a == 169 && b == 254) return AddrScope.internal;

  return AddrScope.public;
}

/// Order addresses public → internal → local, preserving the original order
/// within each group.
///
/// The collapsed address line shows only the first entry, so this decides which
/// one that is. A node binding `0.0.0.0` and holding a LAN address would
/// otherwise lead with a wildcard that tells the user nothing about whether
/// they are reachable.
///
/// Public for `test/peers_address_summary_test.dart`.
List<String> sortByScope(List<String> addrs) {
  final indexed = addrs.indexed.toList();
  indexed.sort((x, y) {
    final byScope = scopeOf(x.$2).index.compareTo(scopeOf(y.$2).index);
    // Stable: the daemon already ranks observed addresses by how many distinct
    // peers confirmed them, and that ordering is worth keeping within a scope.
    return byScope != 0 ? byScope : x.$1.compareTo(y.$1);
  });
  return [for (final e in indexed) e.$2];
}

/// Collapse the observed-address list to one line per host.
///
/// Peers report the address they see us at, which for an outbound connection is
/// our public IP plus that connection's *ephemeral source port*. A busy node
/// therefore reports the same address a dozen times over, once per port —
/// eleven lines saying one thing: "your public IP is 98.232.246.19".
///
/// Grouping by host keeps that fact and drops the repetition. Ports are still
/// summarised, because one of them is not noise: a port matching what we listen
/// on means peers see us where we bound, which is the difference between a
/// port-forwarded node and one whose NAT is rewriting every port.
///
/// Circuit addresses are left whole — a relayed observation names the relay,
/// and that is the interesting part rather than the port.
///
/// Public for `test/peers_address_summary_test.dart`.
List<String> summariseObservedAddrs(List<String> addrs) {
  // Insertion-ordered: the daemon sorts most-confirmed first, and that ranking
  // is worth preserving.
  final byHost = <String, List<int>>{};
  final circuits = <String>[];
  final unparsed = <String>[];

  for (final addr in addrs) {
    if (addr.contains('/p2p-circuit')) {
      if (!circuits.contains(addr)) circuits.add(addr);
      continue;
    }
    final parts = addr.split('/')..removeWhere((p) => p.isEmpty);
    // Expect [ip4, <host>, tcp, <port>, …]; anything else passes through
    // unchanged rather than being silently dropped.
    final tcp = parts.indexOf('tcp');
    if (parts.length < 2 || tcp < 0 || tcp + 1 >= parts.length) {
      if (!unparsed.contains(addr)) unparsed.add(addr);
      continue;
    }
    final port = int.tryParse(parts[tcp + 1]);
    if (port == null) {
      if (!unparsed.contains(addr)) unparsed.add(addr);
      continue;
    }
    final host = '/${parts.sublist(0, tcp).join('/')}';
    (byHost[host] ??= []).add(port);
  }

  final out = <String>[];
  byHost.forEach((host, ports) {
    final unique = ports.toSet().toList()..sort();
    if (unique.length == 1) {
      out.add('$host/tcp/${unique.first}');
    } else {
      // The count is the useful signal — that these are many short-lived
      // source ports rather than several distinct listeners.
      out.add(
        '$host/tcp/${unique.first} '
        '(+${unique.length - 1} more ephemeral ${unique.length == 2 ? 'port' : 'ports'})',
      );
    }
  });

  return [...out, ...circuits, ...unparsed];
}

/// Peer ids are 52 characters and every one in a list shares a prefix; the
/// tail is what distinguishes them, so keep both ends and elide the middle.
String _shortPeerId(String id) {
  if (id.length <= 20) return id;
  return '${id.substring(0, 8)}…${id.substring(id.length - 8)}';
}
