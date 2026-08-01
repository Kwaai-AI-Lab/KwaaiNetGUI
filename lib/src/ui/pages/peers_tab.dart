import 'dart:async';

import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _staleTicker = Timer.periodic(
      peersStaleTick,
      (_) {
        if (mounted) setState(() {});
      },
    );
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
    if (fresh != null) {
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
    final staleFor = arrived == null ? null : DateTime.now().difference(arrived);
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
        error is SessionOpError && (error as SessionOpError).code == _unimplemented;

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
        Row(
          children: [
            Text('This node', style: theme.textTheme.titleSmall),
            const SizedBox(width: 12),
            if (s != null) _ReachabilityBadge(self: s),
            const Spacer(),
            if (stale && staleFor != null)
              _StaleChip(staleFor: staleFor!)
            else
              Text(
                '$connectedCount connected · $routingCount in routing table',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color
                      ?.withValues(alpha: 0.75),
                ),
              ),
          ],
        ),
        if (s != null) ...[
          const SizedBox(height: 8),
          _AddressLine(label: 'Peer ID', values: [s.peerId]),
          if (s.listenAddrs.isNotEmpty)
            _AddressLine(label: 'Listening', values: s.listenAddrs),
          if (s.observedAddrs.isNotEmpty)
            _AddressLine(label: 'Observed', values: s.observedAddrs),
          if (s.relayAddrs.isNotEmpty)
            _AddressLine(label: 'Relays', values: s.relayAddrs),
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
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
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
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: kwaai.semanticWarning),
      ),
    );
  }
}

/// One labelled row of addresses. Multi-valued because a node routinely
/// listens on several and is observed at more than one.
class _AddressLine extends StatelessWidget {
  const _AddressLine({required this.label, required this.values});

  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
    );
    final monoStyle = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'Menlo',
      fontFamilyFallback: const ['Consolas', 'monospace'],
    );

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 74, child: Text(label, style: labelStyle)),
          Expanded(
            child: SelectableText(values.join('\n'), style: monoStyle),
          ),
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

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Caption(
          title: 'CONNECTIONS',
          detail: connected.isEmpty
              ? null
              : '${connected.length} live '
                  '${connected.length == 1 ? 'connection' : 'connections'}',
        ),
        if (connected.isEmpty)
          const _EmptyRow(text: 'No active connections.')
        else
          _ConnectedTable(
            peers: connected,
            routingIds: routingIds,
            selectedPeerId: selectedPeerId,
            onSelectPeer: onSelectPeer,
          ),
        _Caption(
          title: 'DHT ROUTING TABLE',
          detail: routing.isEmpty
              ? null
              : '${routing.length} known '
                  '${routing.length == 1 ? 'peer' : 'peers'}',
        ),
        if (routing.isEmpty)
          // Not an error state. Kademlia stays in client mode — adding
          // nothing — until reachability resolves, so a node that has just
          // started legitimately has connections and an empty table.
          const _EmptyRow(
            text: 'Empty. The routing table fills once reachability is known.',
          )
        else
          _RoutingTable(
            peers: routing,
            selectedPeerId: selectedPeerId,
            onSelectPeer: onSelectPeer,
          ),
      ],
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

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
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
              DataColumn(label: Text('PROTOCOLS', style: headStyle), numeric: true),
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
                    DataCell(
                      // Collapsed to a count: the list is long and mostly
                      // uninteresting per row, but its size is a quick read on
                      // whether identify has landed.
                      Tooltip(
                        message: p.protocols.isEmpty
                            ? 'Identify has not completed yet'
                            : p.protocols.join('\n'),
                        child: Text(
                          p.protocols.isEmpty ? '—' : '${p.protocols.length}',
                          style: cellStyle,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        _shortPeerId(p.peerId),
                        style: monoStyle,
                      ),
                    ),
                    DataCell(
                      Tooltip(
                        message: p.addr,
                        child: Text(p.addr, style: monoStyle),
                      ),
                    ),
                  ],
                ),
            ],
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

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
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

/// Peer ids are 52 characters and every one in a list shares a prefix; the
/// tail is what distinguishes them, so keep both ends and elide the middle.
String _shortPeerId(String id) {
  if (id.length <= 20) return id;
  return '${id.substring(0, 8)}…${id.substring(id.length - 8)}';
}
