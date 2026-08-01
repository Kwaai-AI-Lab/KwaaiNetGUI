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
  const _AddressLine({required this.label, required this.values});

  final String label;
  final List<String> values;

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
    final monoStyle = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'Menlo',
      fontFamilyFallback: const ['Consolas', 'monospace'],
    );

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
                Text(shown.join('\n'), style: monoStyle),
                if (hidden > 0)
                  // A plain tappable Text rather than a TextButton: this page
                  // is rebuilt often and Material buttons bring an ink
                  // controller each. No animation, no per-frame cost.
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        _expanded ? 'show less' : 'and $hidden more',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: kwaai.accentPrimary,
                        ),
                      ),
                    ),
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
    final routingIds = {for (final r in routing) r.peerId};
    // First match: a peer with both a direct and a relayed path has two rows,
    // and their protocol lists come from the same identify, so either serves.
    final selectedConnection = selectedPeerId == null
        ? null
        : connected.where((p) => p.peerId == selectedPeerId).firstOrNull;

    // Connections get the larger share: it is the primary table, and routing
    // entries are one narrow column. Both are flex rather than fixed so the
    // split holds at any window height.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Caption(
          title: 'CONNECTIONS',
          detail: connected.isEmpty
              ? null
              : '${connected.length} live '
                    '${connected.length == 1 ? 'connection' : 'connections'}',
        ),
        Expanded(
          flex: 3,
          child: connected.isEmpty
              ? const _EmptyRow(text: 'No active connections.')
              : _ConnectedTable(
                  peers: connected,
                  routingIds: routingIds,
                  selectedPeerId: selectedPeerId,
                  onSelectPeer: onSelectPeer,
                ),
        ),
        // Detail for the selected connection. One widget for the whole table
        // rather than a tooltip per row — same information, none of the
        // per-row animation cost.
        if (selectedConnection != null)
          _SelectedPeerDetail(peer: selectedConnection),
        Divider(height: 1, color: context.kwaai.divider),
        _Caption(
          title: 'DHT ROUTING TABLE',
          detail: routing.isEmpty
              ? null
              : '${routing.length} known '
                    '${routing.length == 1 ? 'peer' : 'peers'}',
        ),
        Expanded(
          flex: 2,
          child: routing.isEmpty
              // Not an error state. Kademlia stays in client mode — adding
              // nothing — until reachability resolves, so a node that has just
              // started legitimately has connections and an empty table.
              ? const _EmptyRow(
                  text:
                      'Empty. The routing table fills once reachability is known.',
                )
              : _RoutingTable(
                  peers: routing,
                  selectedPeerId: selectedPeerId,
                  onSelectPeer: onSelectPeer,
                ),
        ),
      ],
    );
  }
}

/// Full detail for the selected connection — chiefly the protocol list, which
/// the table shows only as a count.
class _SelectedPeerDetail extends StatelessWidget {
  const _SelectedPeerDetail({required this.peer});

  final pb.ConnectedPeer peer;

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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      color: kwaai.accentPrimary.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('SELECTED', style: labelStyle),
              const SizedBox(width: 10),
              Expanded(child: Text(peer.peerId, style: monoStyle)),
              _CopyButton(text: peer.peerId, label: 'Peer ID'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 74, child: Text('Address', style: labelStyle)),
              Expanded(child: Text(peer.addr, style: monoStyle)),
              _CopyButton(text: peer.addr, label: 'Address'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 74, child: Text('Protocols', style: labelStyle)),
              Expanded(
                child: Text(
                  peer.protocols.isEmpty
                      // Not "speaks nothing": identify completes shortly after
                      // the connection does.
                      ? 'Identify has not completed yet'
                      : peer.protocols.join('\n'),
                  style: monoStyle,
                ),
              ),
            ],
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
        children: [
          Text(title, style: style),
          if (detail != null) ...[
            const Spacer(),
            Text(detail!, style: theme.textTheme.bodySmall),
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

/// One row per *connection*, not per peer. A peer reachable both directly and
/// over a relay appears twice — that duplication is how a hole-punch upgrade
/// shows up while it is happening, so it is preserved rather than collapsed.
class _ConnectedTable extends StatelessWidget {
  const _ConnectedTable({
    required this.peers,
    required this.routingIds,
    required this.selectedPeerId,
    required this.onSelectPeer,
  });

  final List<pb.ConnectedPeer> peers;
  final Set<String> routingIds;
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

    // Vertical scroll outside, horizontal inside — the same nesting the VPK
    // table uses. The outer one is what gives the DataTable a bounded height
    // to lay out against; without it (a ListView parent, say) the table is
    // measured against infinity on every frame.
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
                DataColumn(label: Text('PATH', style: headStyle)),
                DataColumn(label: Text('DIR', style: headStyle)),
                DataColumn(label: Text('RTT', style: headStyle), numeric: true),
                DataColumn(label: Text('ROLE', style: headStyle)),
                DataColumn(label: Text('IN TABLE', style: headStyle)),
                DataColumn(label: Text('VERSION', style: headStyle)),
                DataColumn(
                  label: Text('PROTOCOLS', style: headStyle),
                  numeric: true,
                ),
                DataColumn(label: Text('PEER ID', style: headStyle)),
                DataColumn(label: Text('ADDRESS', style: headStyle)),
              ],
              rows: [
                for (final p in peers)
                  DataRow(
                    selected: p.peerId == selectedPeerId,
                    color: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? selectedFill
                          : null,
                    ),
                    onSelectChanged: (_) => onSelectPeer(p.peerId),
                    cells: [
                      DataCell(_PathCell(kind: p.kind)),
                      DataCell(Text(p.direction, style: cellStyle)),
                      DataCell(
                        Text(
                          // 0 means no ping has completed yet, not zero latency.
                          p.rttMs == 0 ? '—' : '${p.rttMs} ms',
                          style: cellStyle,
                        ),
                      ),
                      DataCell(_RoleCell(peer: p)),
                      DataCell(
                        Icon(
                          routingIds.contains(p.peerId)
                              ? Icons.check
                              : Icons.remove,
                          size: 14,
                          color: routingIds.contains(p.peerId)
                              ? kwaai.statusRunning
                              : theme.dividerColor,
                        ),
                      ),
                      DataCell(
                        Text(
                          p.agentVersion.isEmpty ? '—' : p.agentVersion,
                          style: cellStyle,
                        ),
                      ),
                      // Collapsed to a count: the list is long and mostly
                      // uninteresting per row, but its size is a quick read on
                      // whether identify has landed. Selecting the row shows
                      // the full list below the table.
                      //
                      // No Tooltip here, and none on the address. A Tooltip
                      // runs an AnimationController, so one per cell means two
                      // per row all ticking every frame: 0.05ms/frame becomes
                      // ~14ms at twenty rows, which is what made this page feel
                      // like it hung. `test/peers_layout_test.dart` guards it.
                      DataCell(
                        Text(
                          p.protocols.isEmpty ? '—' : '${p.protocols.length}',
                          style: cellStyle,
                        ),
                      ),
                      DataCell(Text(_shortPeerId(p.peerId), style: monoStyle)),
                      DataCell(Text(p.addr, style: monoStyle)),
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

class _RoutingTable extends StatelessWidget {
  const _RoutingTable({
    required this.peers,
    required this.selectedPeerId,
    required this.onSelectPeer,
  });

  final List<pb.RoutingPeer> peers;
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

    // Vertical scroll outside, horizontal inside — the same nesting the VPK
    // table uses. The outer one is what gives the DataTable a bounded height
    // to lay out against; without it (a ListView parent, say) the table is
    // measured against infinity on every frame.
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
                DataColumn(label: Text('CONNECTED', style: headStyle)),
                DataColumn(label: Text('PEER ID', style: headStyle)),
              ],
              rows: [
                for (final p in peers)
                  DataRow(
                    selected: p.peerId == selectedPeerId,
                    color: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? selectedFill
                          : null,
                    ),
                    onSelectChanged: (_) => onSelectPeer(p.peerId),
                    cells: [
                      DataCell(
                        Icon(
                          p.connected ? Icons.check : Icons.remove,
                          size: 14,
                          color: p.connected
                              ? kwaai.statusRunning
                              : theme.dividerColor,
                        ),
                      ),
                      DataCell(Text(p.peerId, style: monoStyle)),
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

/// Direct or relayed, colour-matched to the CLI's own vocabulary (green for
/// direct, amber for relayed).
class _PathCell extends StatelessWidget {
  const _PathCell({required this.kind});

  final pbenum.PeerConnKind kind;

  @override
  Widget build(BuildContext context) {
    final kwaai = context.kwaai;
    final relayed = kind == pbenum.PeerConnKind.PEER_CONN_KIND_RELAY;
    final color = relayed ? kwaai.semanticWarning : kwaai.statusRunning;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          relayed ? Icons.alt_route : Icons.arrow_right_alt,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 5),
        Text(
          relayed ? 'relay' : 'direct',
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
  const _RoleCell({required this.peer});

  final pb.ConnectedPeer peer;

  @override
  Widget build(BuildContext context) {
    final kwaai = context.kwaai;
    final theme = Theme.of(context);
    if (peer.isBootstrap) {
      return Text(
        'bootstrap',
        style: theme.textTheme.bodySmall?.copyWith(color: kwaai.accentPrimary),
      );
    }
    if (peer.isTrustedRelay) {
      return Text(
        'trusted relay',
        style: theme.textTheme.bodySmall?.copyWith(color: kwaai.semanticInfo),
      );
    }
    return Text('—', style: theme.textTheme.bodySmall);
  }
}

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
