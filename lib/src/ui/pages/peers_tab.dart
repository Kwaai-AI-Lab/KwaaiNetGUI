import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/generated/kwaai.pb.dart' as pb;
import '../../chat/generated/kwaai.pbenum.dart' as pbenum;
import '../../chat/kwaai_rpc_client.dart';
import '../../chat/session_client.dart';
import '../../daemon/daemon_state.dart';
import '../../daemon/peers_state.dart';
import '../../p2p/protocols.dart';
import '../theme/kwaai_theme.dart';
import '../widgets/filter_toggle.dart';
import '../widgets/kwaai_dropdown.dart';
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

      // Reachability, not the local PID: with KWAAINET_GRPC_PORT set the
      // daemon runs elsewhere and has no PID on this machine.
      final running = ref.watch(daemonAvailableProvider);
      return ServiceStatusView(
        headline: running
            ? 'Reading the local p2p state…'
            : unavailableHeadline(),
        spinner: running,
        subtitle: running ? null : Text(unavailableHint('see the network')),
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
            // Evidence, not capability: a live DCUtR-upgraded connection is
            // proof a peer got through the NAT to us.
            holePunched: update.connected.any((c) => c.dcutr),
            stale: stale,
            staleFor: staleFor,
          ),
        ),
        Divider(height: 1, color: context.kwaai.divider),
        Expanded(
          child: _TableSection(
            connected: update.connected,
            routing: update.routing,
            localProtocols: update.hasSelfStatus()
                ? update.selfStatus.localProtocols
                : const [],
            selectedPeerId: _selectedPeerId,
            onSelectPeer: _togglePeer,
            onConnect: _connectPeer,
          ),
        ),
      ],
    );
  }

  /// Dial a peer we know of but are not connected to.
  ///
  /// The next snapshot reports the result, so there is nothing to update here
  /// beyond surfacing a failure — a successful connection simply appears.
  ///
  /// Returns whether the dial succeeded. A refused dial comes back as a reply
  /// with `connected == false`, not as a thrown error, so a caller that infers
  /// the outcome from whether this threw would call every failure a success.
  Future<bool> _connectPeer(String peerId) async {
    final reply = await ref.read(kwaaiRpcClientProvider).connectPeer(peerId);
    if (!mounted) return reply?.connected ?? false;
    final failed = reply == null || !reply.connected;
    if (failed) {
      final detail = reply?.error ?? 'the daemon could not be reached';
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Could not connect: $detail'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
    return !failed;
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
    required this.holePunched,
    required this.stale,
    required this.staleFor,
  });

  final pb.SelfStatus? self;
  final int connectedCount;
  final int routingCount;

  /// Whether any live connection was upgraded by DCUtR.
  final bool holePunched;
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
        // Wrap, not Row, for the title group: the badge text grows with the
        // reachability source, so on a narrow window it genuinely cannot fit
        // and needs to re-flow rather than overflow.
        //
        // The counts sit outside that group, in a Row that spans the full
        // width, so they can be pushed to the right edge. Inside the Wrap they
        // were just another wrapped child, landing mid-line or on a line of
        // their own aligned left under the title.
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Expanded, not Flexible: it must claim the leftover width so the
            // counts are pushed to the right edge. Flexible lets the Row
            // shrink to its content, leaving the counts mid-bar.
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 6,
                children: [
                  Text('This node', style: theme.textTheme.titleSmall),
                  if (s != null)
                    _ReachabilityBadge(self: s, holePunched: holePunched),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (stale && staleFor != null)
              _StaleChip(staleFor: staleFor!)
            else
              Text(
                '$connectedCount connected · $routingCount in routing table',
                textAlign: TextAlign.right,
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
          // What we serve, directly under our identity and above what we can
          // reach — it belongs with "who am I" rather than with the addresses.
          // Reading it beside a peer's protocol list is how you tell whether a
          // capability gap is theirs or ours.
          if (s.localProtocols.isNotEmpty)
            _ProtocolLines(protocols: s.localProtocols, label: 'Serving'),
          // Each of these collapses to its first entry, so scope order decides
          // what the user sees without expanding: the public address if there
          // is one, then LAN, then loopback or a wildcard bind.
          if (s.listenAddrs.isNotEmpty)
            _AddressLine(
              label: 'Listening',
              itemLabel: 'Address',
              values: sortByScope(s.listenAddrs),
            ),
          if (s.observedAddrs.isNotEmpty)
            _AddressLine(
              label: 'Observed',
              itemLabel: 'Address',
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
/// How the rest of the network reaches this node.
///
/// Two facts, in that order: whether we can be dialled from outside, and by
/// what route peers actually get in. "Behind NAT" rather than the wire's
/// "private", which reads as a privacy setting; AutoNAT cannot tell a NAT
/// from a firewall, and for this purpose they are the same thing.
///
/// The second part reports evidence, never a prediction. Whether a peer can
/// hole-punch to us is not knowable in advance — nothing in the snapshot says
/// so, and DCUtR only reports success on a connection that has already been
/// upgraded — so a held reservation is described as what it is, a reservation,
/// rather than as relaying being the ceiling. It used to read "relayed", which
/// claimed the degraded case for a node that simply had no punched connection
/// live at that moment.
class _ReachabilityBadge extends StatelessWidget {
  const _ReachabilityBadge({required this.self, required this.holePunched});

  final pb.SelfStatus self;
  final bool holePunched;

  @override
  Widget build(BuildContext context) {
    final kwaai = context.kwaai;
    final public = self.reachability == 'public';
    final (label, color) = switch (self.reachability) {
      'public' => ('Public', kwaai.statusRunning),
      'private' => ('Behind NAT', kwaai.semanticWarning),
      _ => ('Reachability unknown', kwaai.statusTransitioning),
    };

    final (String? route, String hint) = switch ((
      public,
      holePunched,
      self.usingRelay,
    )) {
      (true, _, _) => (
        self.reachabilitySource.isEmpty
            ? null
            : 'via ${self.reachabilitySource}',
        'Peers can dial this node directly.',
      ),
      (false, true, _) => (
        'hole punched',
        'Dial-back from outside fails, but a peer has since reached this '
            'node directly through the NAT — introduced over a relay, then '
            'upgraded by DCUtR.',
      ),
      (false, false, true) => (
        'relay reserved',
        'Dial-back from outside fails, so peers reach this node through a '
            'relay circuit it holds a reservation on. Connections made that '
            'way may then be upgraded to a direct path by DCUtR — whether '
            'they are is only known once a peer connects, so this is not a '
            'claim that relaying is the ceiling.',
      ),
      (false, false, false) => (
        'outbound only',
        'Not dialable from outside and holding no relay reservation, so '
            'nothing can reach this node — it can only open connections '
            'itself.',
      ),
    };

    final parts = [label, ?route];

    return Tooltip(
      message: self.reachability == 'unknown' || self.reachability.isEmpty
          ? 'No verdict yet: too few peers have reported an address and no '
                'dial-back has completed. Announcing is deferred until then.'
          : hint,
      child: Container(
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
    this.itemLabel,
  });

  /// What one entry is called, for the per-line copy buttons. The row label
  /// names the group ("Listening"), which reads wrong on a button that copies a
  /// single entry from it. Falls back to [label] when unset.
  final String? itemLabel;

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
                      //
                      // Flexible, not Expanded: the address takes only what it
                      // needs, so the toggle sits just after it rather than
                      // being pushed to the far edge with a gap between.
                      Flexible(
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
                        const SizedBox(width: 12),
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
                      // One per line, copying that line alone. These are the
                      // values you paste elsewhere — your peer id, an address
                      // to hand to someone — unlike the connections panel,
                      // which is read rather than copied from.
                      const SizedBox(width: 12),
                      _CopyButton(
                        text: shown[i],
                        label: widget.itemLabel ?? widget.label,
                      ),
                    ],
                  ),
              ],
            ),
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
///
/// Each section gets a *bounded* share of the height and scrolls internally.
/// That bound is load-bearing, not cosmetic: a `DataTable` sizes itself to its
/// content, and inside a vertically-scrolling parent it is laid out against an
/// unbounded height, which costs ~25ms per frame at twenty rows versus ~0.1ms
/// when bounded. Putting these tables in a ListView is what made this page
/// feel like it hung. `test/peers_layout_test.dart` measures it.
class _TableSection extends StatefulWidget {
  const _TableSection({
    required this.connected,
    required this.routing,
    required this.localProtocols,
    required this.selectedPeerId,
    required this.onSelectPeer,
    required this.onConnect,
  });

  final List<pb.ConnectedPeer> connected;
  final List<pb.RoutingPeer> routing;

  /// What this node itself advertises — the protocol filter offers our own
  /// KwaaiNet protocols, not the union of everything seen on the network.
  final List<String> localProtocols;
  final String? selectedPeerId;
  final void Function(String peerId) onSelectPeer;
  final Future<bool> Function(String peerId) onConnect;

  @override
  State<_TableSection> createState() => _TableSectionState();
}

class _TableSectionState extends State<_TableSection> {
  /// Whether client-mode peers are listed.
  ///
  /// Off by default: these are query-only participants that can never be a
  /// routing hop, and at scale there is one per connected inference client, so
  /// they would crowd out the nodes an operator is actually looking for.
  ///
  /// The hidden count is always shown next to the toggle. Hiding rows is
  /// defensible; hiding the fact that rows are hidden is not — and a silently
  /// filtered table would also conceal client peers accumulating in the
  /// routing table, which is exactly the symptom worth noticing.
  bool _showDhtClients = false;

  /// Whether peers we know of but hold no connection to are listed.
  ///
  /// Off by default for the same reason: a routing table carries every peer
  /// this node has ever learned an address for, and most of them are not part
  /// of what it is doing right now. Hidden, the table answers "who am I
  /// talking to"; shown, it answers "who could I talk to".
  bool _showUnconnected = false;

  /// Protocol families the table is narrowed to. Empty means no narrowing —
  /// the default shows every peer whatever it advertises.
  ///
  /// Families rather than full ids, so a peer running a different version of
  /// a protocol we advertise still matches.
  final Set<String> _protocolFilter = {};

  @override
  Widget build(BuildContext context) {
    final allRows = mergePeerRows(widget.connected, widget.routing);
    final clientRows = allRows.where((r) => r.isDhtClient).length;
    final unconnectedRows = allRows.where((r) => !r.isConnected).length;
    final rows = allRows
        .where(
          (r) =>
              (_showDhtClients || !r.isDhtClient) &&
              (_showUnconnected || r.isConnected) &&
              (_protocolFilter.isEmpty || r.advertisesAny(_protocolFilter)),
        )
        .toList();
    // What the table is actually withholding — zero once everything is shown.
    // Counted as a difference rather than summed per filter, which would
    // double-count a row both of them hide.
    final hidden = allRows.length - rows.length;

    // A selection can survive the filter hiding its row — keep the detail
    // panel honest by resolving against what is actually on screen.
    final selected = widget.selectedPeerId == null
        ? null
        : rows.where((r) => r.peerId == widget.selectedPeerId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Caption(
          title: 'PEERS',
          detail: _summary(rows, hidden),
          // On the caption row rather than its own band: the toggles change
          // what the summary counts, so keeping them together stops them
          // stealing a row of table height.
          trailing: _Filters(
            showDhtClients: _showDhtClients,
            showUnconnected: _showUnconnected,
            // Keyed off such rows existing at all, not off how many are
            // hidden — otherwise checking a box would make it vanish.
            clientRows: clientRows,
            unconnectedRows: unconnectedRows,
            onShowDhtClients: (v) => setState(() => _showDhtClients = v),
            onShowUnconnected: (v) => setState(() => _showUnconnected = v),
            protocolChoices: kwaaiProtocolFamilies(widget.localProtocols),
            selectedProtocols: _protocolFilter,
            onToggleProtocol: (family, on) => setState(() {
              on ? _protocolFilter.add(family) : _protocolFilter.remove(family);
            }),
            onClearProtocols: () => setState(_protocolFilter.clear),
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? _EmptyRow(
                  text: hidden > 0
                      ? 'No peers match these filters.'
                      : 'No peers known.',
                )
              : _PeerTable(
                  rows: rows,
                  selectedPeerId: widget.selectedPeerId,
                  onSelectPeer: widget.onSelectPeer,
                  onConnect: widget.onConnect,
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
              child: _PeerConnections(
                row: selected,
                // Same toggle the row uses, so closing here and re-clicking
                // the row cannot disagree about what is selected.
                onClose: () => widget.onSelectPeer(selected.peerId),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String? _summary(List<PeerRow> rows, int hidden) {
    if (rows.isEmpty && hidden == 0) return null;
    final live = rows.where((r) => r.isConnected).length;
    final dht = rows.where((r) => r.inRoutingTable).length;
    final summary = '$live connected · $dht in routing table';
    // Counts what the table is not showing. The table may legitimately be
    // empty while peers exist, so this has to be reported even then.
    return hidden > 0 ? '$summary · $hidden hidden' : summary;
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
    this.routingAddrs = const [],
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

  /// What the DHT routing table holds for this peer.
  ///
  /// Present even with no connection — that is the point. A routing entry with
  /// no address is a peer we know of but cannot dial, which looks identical to
  /// a merely-unconnected one unless the addresses are shown.
  final List<String> routingAddrs;

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

  /// Whether this peer both dialled us and was dialled by us.
  ///
  /// Worth a glance of its own: it means neither side is depending on the
  /// other to be reachable. The row's arrow points both ways for it; which
  /// connection went which way is in the panel below.
  bool get bothDirections =>
      connections.any((c) => c.direction == 'inbound') &&
      connections.any((c) => c.direction == 'outbound');

  /// Whether this peer queries the DHT without serving it.
  ///
  /// Deliberately false while the role is unknown: identify lands shortly
  /// *after* a connection establishes, so treating "not yet reported" as
  /// "client" would blink every new peer through the filtered-out state.
  /// A routing-only peer has no connection to read a role from and is never
  /// a client — it is in the routing table, which is the opposite claim.
  ///
  /// Independent of [isBootstrap] and [isTrustedRelay] rather than exclusive
  /// with them: those are operator configuration, this is observed behaviour.
  /// A client-mode peer still advertises circuit relay hop, and one of our own
  /// nodes runs kad in client mode whenever it is only reachable via a relay.
  bool get isDhtClient => primary?.dhtRole == pbenum.DhtRole.DHT_ROLE_CLIENT;

  /// Whether this peer advertises any of [families] (protocol ids compared by
  /// family, so versions do not have to agree).
  ///
  /// Checked across every connection rather than just [primary]: identify is
  /// per peer, but there is no guarantee which connection's snapshot carries
  /// it. Routing-only peers have no identify to read and never match — a
  /// protocol filter deliberately shows only peers *known* to serve it.
  bool advertisesAny(Set<String> families) => connections.any(
    (c) => c.protocols.any((p) => families.contains(protocolFamily(p))),
  );
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
        routingAddrs: routingById[entry.key]?.addrs ?? const [],
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
        routingAddrs: r.addrs,
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
    required this.onConnect,
  });

  final List<PeerRow> rows;
  final String? selectedPeerId;
  final void Function(String peerId) onSelectPeer;
  final Future<bool> Function(String peerId) onConnect;

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
                // PATH carries direction in its arrow, so there is no separate
                // DIR column: the arrow used to point right regardless, which
                // made it decoration beside a column holding the actual fact.
                DataColumn(label: Text('PATH', style: headStyle)),
                DataColumn(label: Text('RTT', style: headStyle), numeric: true),
                DataColumn(label: Text('ROLE', style: headStyle)),
                DataColumn(label: Text('VERSION', style: headStyle)),
                DataColumn(label: Text('PEER ID', style: headStyle)),
                DataColumn(label: Text('ADDRESS', style: headStyle)),
              ],
              rows: [
                for (final r in rows)
                  DataRow(
                    // Keyed by peer so per-row state survives the 5s refresh.
                    // Without it Flutter matches rows by position, and a peer
                    // appearing or dropping shifts everything below it —
                    // handing one row's connect outcome to a different peer,
                    // or resetting it so a failure mark never clears.
                    key: ValueKey(r.peerId),
                    selected: r.peerId == selectedPeerId,
                    color: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? selectedFill
                          : null,
                    ),
                    onSelectChanged: (_) => onSelectPeer(r.peerId),
                    cells: [
                      DataCell(
                        r.isConnected
                            ? const _StateMark(on: true)
                            : _ConnectCell(
                                // Keyed by peer for the same reason as the
                                // row: this cell holds the in-flight and
                                // outcome state, and it must follow the peer
                                // rather than the position.
                                key: ValueKey('connect-${r.peerId}'),
                                peerId: r.peerId,
                                onConnect: onConnect,
                                dialable: r.routingAddrs.isNotEmpty,
                              ),
                      ),
                      DataCell(_StateMark(on: r.inRoutingTable)),
                      DataCell(
                        r.primary == null
                            ? Text('—', style: cellStyle)
                            : _PathCell(
                                kind: r.primary!.kind,
                                dcutr: r.anyDcutr,
                                direction: r.primary!.direction,
                                bothDirections: r.bothDirections,
                              ),
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
                      DataCell(
                        Text(
                          // `via` when the address alone says nothing about the
                          // path — see the connections panel.
                          switch (r.primary) {
                            null => '—',
                            final p when p.via.isNotEmpty => p.via,
                            final p => p.addr,
                          },
                          style: monoStyle,
                        ),
                      ),
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

/// The CONN cell for a peer we hold no connection to: a dash that becomes a
/// connect button on hover.
///
/// Hover-reveal rather than an always-visible button, because most rows are
/// connected and a column of buttons would read as the primary action on a
/// page that is mostly for reading. The dash still says "not connected" at a
/// glance; the action appears where you are already pointing.
///
/// Dialling makes us the *dialer*, so this will not trigger a DCUtR upgrade —
/// libp2p has the inbound side initiate hole punching. It is for reaching a
/// peer the routing table knows about but we are not talking to.
class _ConnectCell extends StatefulWidget {
  const _ConnectCell({
    super.key,
    required this.peerId,
    required this.onConnect,
    required this.dialable,
  });

  final String peerId;
  final Future<bool> Function(String peerId) onConnect;

  /// Whether the routing table holds an address to dial.
  ///
  /// Offering the button without one invites a connect that cannot succeed —
  /// and fails confusingly, since a peer with no usable address may still be
  /// reached at a stale one and report a peer-id mismatch.
  final bool dialable;

  @override
  State<_ConnectCell> createState() => _ConnectCellState();
}

class _ConnectCellState extends State<_ConnectCell> {
  bool _hovered = false;
  bool _busy = false;

  /// Outcome of the last attempt, held briefly after it finishes.
  ///
  /// Without this the cell reverts to its idle mark the instant the future
  /// completes, so a fast failure is indistinguishable from never having
  /// clicked. A connect can also succeed without the row changing — the peer
  /// may already have been in the routing table — so "did that do anything?"
  /// needs answering here rather than being left to the table.
  bool? _lastOk;
  Timer? _clearOutcome;

  @override
  void dispose() {
    _clearOutcome?.cancel();
    super.dispose();
  }

  Future<void> _connect() async {
    _clearOutcome?.cancel();
    setState(() {
      _busy = true;
      _lastOk = null;
    });
    var ok = false;
    try {
      // The returned flag, not the absence of a throw: a refused dial comes
      // back as a normal reply carrying `connected: false`, so treating "did
      // not throw" as success marks every failure with a tick.
      ok = await widget.onConnect(widget.peerId);
    } catch (_) {
      // Swallowed deliberately: the caller surfaces the error, and this cell
      // only needs to know which mark to show.
      ok = false;
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _lastOk = ok;
        });
        // Long enough to read after the pointer has moved on, short enough
        // that a stale verdict does not linger over a changing table.
        _clearOutcome = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => _lastOk = null);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final kwaai = context.kwaai;

    // Both of these render regardless of hover — the pointer has usually left
    // the row by the time either matters.
    if (_busy) {
      return const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 1.6),
      );
    }

    // A failure mark replaces the button rather than sitting beside it: the
    // dial used the address the routing table holds, so an immediate retry
    // repeats it exactly. The mark clears on its own, which is when retrying
    // becomes worth offering again — by then a fresh snapshot may have
    // replaced the address that failed.
    if (_lastOk != null) {
      return Tooltip(
        message: _lastOk!
            ? 'Connect requested'
            : 'Connect failed — see the message below the table',
        child: Icon(
          _lastOk! ? Icons.check : Icons.close,
          size: 14,
          color: _lastOk!
              ? kwaai.semanticInfo
              : Theme.of(context).colorScheme.error,
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: _hovered
          ? IconButton(
              icon: const Icon(Icons.link, size: 14),
              iconSize: 14,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              color: widget.dialable
                  ? kwaai.accentPrimary
                  : Theme.of(context).disabledColor,
              tooltip: widget.dialable
                  ? 'Connect to this peer'
                  : 'No dialable address known for this peer',
              onPressed: widget.dialable ? _connect : null,
            )
          : const _StateMark(on: false),
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
  const _PeerConnections({required this.row, required this.onClose});

  final PeerRow row;

  /// Dismisses the panel. Clicking the selected row again does the same, but
  /// that is not discoverable from looking at it.
  final VoidCallback onClose;

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
              // Close, not copy. The panel opens by selecting a row, so it
              // needs a visible way out — clicking the row again works but is
              // not discoverable.
              IconButton(
                icon: const Icon(Icons.close, size: 14),
                iconSize: 14,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                tooltip: 'Close',
                onPressed: onClose,
              ),
            ],
          ),
          if (row.connections.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                // A routing-table entry we hold no connection to. Normal: the
                // table deliberately retains peers we are not talking to.
                //
                // Whether it is *dialable* is the part worth saying out loud:
                // an entry with no address cannot be connected to at all, and
                // reads identically to one that simply is not connected yet.
                row.routingAddrs.isEmpty
                    ? 'Known from the DHT routing table, but with no dialable '
                          'address — connecting is not possible until one is '
                          'learned.'
                    : 'Known from the DHT routing table; not currently '
                          'connected.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: 0.7,
                  ),
                ),
              ),
            ),
            if (row.routingAddrs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _AddressLine(
                  label: 'Known at',
                  itemLabel: 'address',
                  values: row.routingAddrs,
                ),
              ),
          ] else
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
                      child: _PathCell(
                        kind: c.kind,
                        dcutr: c.dcutr,
                        direction: c.direction,
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(
                        c.rttMs == 0 ? '—' : '${c.rttMs} ms',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    // For an inbound relayed connection `addr` is a bare
                    // /p2p/<peer> — it names who reached us and nothing about
                    // how. `via` carries the relay, which is the part worth
                    // showing, so prefer it when present.
                    Text('via', style: labelStyle),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        c.via.isNotEmpty ? c.via : c.addr,
                        style: monoStyle,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
            _ProtocolLines(protocols: protocols),
        ],
      ),
    );
  }
}

/// The protocols a peer advertises: raw id on the left, plain-words gloss on
/// the right, one per line.
///
/// Both, because they answer different questions. The id is the identifier you
/// would grep a log or a spec for; the description is what it means. Showing
/// only the id demands you know the ecosystem by heart, and showing only the
/// description hides the thing you would search for.
///
/// Collapsed to the first entry — a peer advertises a dozen and the panel
/// should not be mostly protocol list — with the same "and N more" toggle the
/// address lines use.
class _ProtocolLines extends StatefulWidget {
  const _ProtocolLines({required this.protocols, this.label = 'Protocols'});

  final List<String> protocols;

  /// Row label. "Protocols" for a peer's list, "Serving" for our own — the
  /// distinction matters when the two sit on the same page.
  final String label;

  @override
  State<_ProtocolLines> createState() => _ProtocolLinesState();
}

class _ProtocolLinesState extends State<_ProtocolLines> {
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
    final descStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8),
    );

    final protocols = widget.protocols;
    final hidden = protocols.length - 1;
    final shown = _expanded ? protocols : protocols.take(1).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 74, child: Text(widget.label, style: labelStyle)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < shown.length; i++)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fixed width so the descriptions line up into a column
                      // of their own rather than starting wherever each id
                      // happens to end.
                      SizedBox(
                        width: 244,
                        child: Text(
                          shown[i],
                          style: monoStyle,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Flexible, not Expanded: the description takes only the
                      // width it needs, so the toggle sits just after it rather
                      // than being shoved to the far edge of the panel.
                      Flexible(
                        child: Text(
                          // An unknown id describes itself, which would render
                          // the same text twice. Say so rather than leaving the
                          // gloss blank: an empty cell reads as a rendering
                          // fault, where this reads as "we have no description
                          // for this one" — which is the truth, and a prompt to
                          // add it.
                          describeProtocol(shown[i]) == shown[i]
                              ? 'No description'
                              : describeProtocol(shown[i]),
                          style: descStyle,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (hidden > 0 && i == 0) ...[
                        const SizedBox(width: 12),
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
        ],
      ),
    );
  }
}

/// The caption bar's filter checkboxes.
///
/// Each appears only once it has something to hide, so a small network is not
/// asked about categories it does not have — but a box the user has ticked
/// stays put, or unticking it would make it disappear.
class _Filters extends StatelessWidget {
  const _Filters({
    required this.showDhtClients,
    required this.showUnconnected,
    required this.clientRows,
    required this.unconnectedRows,
    required this.onShowDhtClients,
    required this.onShowUnconnected,
    required this.protocolChoices,
    required this.selectedProtocols,
    required this.onToggleProtocol,
    required this.onClearProtocols,
  });

  final bool showDhtClients;
  final bool showUnconnected;
  final int clientRows;
  final int unconnectedRows;
  final ValueChanged<bool> onShowDhtClients;
  final ValueChanged<bool> onShowUnconnected;

  /// KwaaiNet protocol family → an advertised id carrying it, from what this
  /// node itself serves.
  final Map<String, String> protocolChoices;

  final Set<String> selectedProtocols;
  final void Function(String family, bool selected) onToggleProtocol;
  final VoidCallback onClearProtocols;

  @override
  Widget build(BuildContext context) {
    final toggles = <Widget>[
      if (unconnectedRows > 0 || showUnconnected)
        FilterToggle(
          label: 'Show unconnected',
          tooltip:
              'Peers in the DHT routing table this node holds no connection '
              'to. Known addresses rather than live paths — worth showing '
              'when you are asking who could be dialled, not who is.',
          value: showUnconnected,
          onChanged: onShowUnconnected,
        ),
      if (clientRows > 0 || showDhtClients)
        FilterToggle(
          label: 'Show DHT clients',
          tooltip:
              'Peers that query the DHT without serving it. They are never '
              'routing hops — typically hivemind/Python processes, or nodes '
              'reachable only via a relay.',
          value: showDhtClients,
          onChanged: onShowDhtClients,
        ),
      // Same appear-when-useful rule as the checkboxes: offered once this
      // node advertises a KwaaiNet protocol, and held open while a selection
      // is active even if the node stops advertising it.
      if (protocolChoices.isNotEmpty || selectedProtocols.isNotEmpty)
        _ProtocolFilter(
          choices: protocolChoices,
          selected: selectedProtocols,
          onToggle: onToggleProtocol,
          onClear: onClearProtocols,
        ),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < toggles.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          toggles[i],
        ],
      ],
    );
  }
}

/// Drop-down narrowing the table to peers advertising selected KwaaiNet
/// protocols.
///
/// Only our own `/kwaai/…` protocols are offered — the libp2p machinery
/// (identify, kad, relay, …) is advertised by every peer, so filtering on it
/// would select everything while tripling the list's length. The choices come
/// from what *this node* serves: that is the set the operator is comparing the
/// network against, and it needs no knowledge of what exists elsewhere.
///
/// Nothing checked means no filtering. With boxes checked, a peer stays listed
/// if it advertises **any** checked family — the faceted-filter convention,
/// and the useful one: "who serves storage or inference" is a real question,
/// "who serves both" rarely is. Matching is by family ([protocolFamily]), so a
/// peer on a different version still counts.
///
/// The popup wears [kwaaiMenuStyle] so it reads as the same control as the
/// app's other drop-downs rather than a stock Material menu — same surface,
/// same tight rows. Toggling a row keeps the menu open; each protocol's gloss
/// rides its row as a tooltip rather than a second line, which is what keeps
/// the rows one line tall.
class _ProtocolFilter extends StatefulWidget {
  const _ProtocolFilter({
    required this.choices,
    required this.selected,
    required this.onToggle,
    required this.onClear,
  });

  /// Family → an advertised full id, kept for [describeProtocol] — its
  /// wildcard keys match versioned ids, not families.
  final Map<String, String> choices;

  final Set<String> selected;
  final void Function(String family, bool selected) onToggle;
  final VoidCallback onClear;

  @override
  State<_ProtocolFilter> createState() => _ProtocolFilterState();
}

class _ProtocolFilterState extends State<_ProtocolFilter> {
  /// Owned rather than taken from the builder: the "Show all peers" row lives
  /// in the overlay, where the builder's controller is out of reach.
  final _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kwaai = context.kwaai;
    final active = widget.selected.isNotEmpty;
    // A ticked family this node no longer advertises stays listed — removing
    // it would strand a filter the user can see the effect of but not undo.
    final families = {...widget.choices.keys, ...widget.selected}.toList()
      ..sort();

    final color = active
        ? kwaai.accentPrimary
        : theme.textTheme.labelSmall?.color;

    return MenuAnchor(
      controller: _menu,
      // Below the trigger, unlike KwaaiDropdown's selected-row-over-trigger
      // anchoring — this menu has no "current value" row to line up.
      style: kwaaiMenuStyle(context, alignment: AlignmentDirectional.bottomStart),
      menuChildren: [
        KwaaiMenuSurface(
          children: [
            if (active)
              _ProtocolMenuRow(
                label: 'Show all peers',
                onTap: () {
                  _menu.close();
                  widget.onClear();
                },
              ),
            for (final family in families)
              _ProtocolMenuRow(
                label: family,
                mono: true,
                checked: widget.selected.contains(family),
                // Same gloss the connections panel shows, minus ids that only
                // describe themselves.
                tooltip: switch (widget.choices[family]) {
                  final id? when describeProtocol(id) != id =>
                    describeProtocol(id),
                  _ => null,
                },
                // Not closing here is the point — picking two protocols
                // should not cost two round trips through the drop-down.
                onTap: () => widget.onToggle(
                  family,
                  !widget.selected.contains(family),
                ),
              ),
          ],
        ),
      ],
      builder: (context, controller, _) => Tooltip(
        message:
            'Show only peers advertising any of the checked KwaaiNet '
            'protocols. Nothing checked shows every peer. Only peers with a '
            'completed identify can match — routing-only entries never do.',
        child: InkWell(
          onTap: () => controller.isOpen ? controller.close() : controller.open(),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  active
                      ? 'Protocols (${widget.selected.length})'
                      : 'Protocols',
                  style: theme.textTheme.labelSmall?.copyWith(color: color),
                ),
                Icon(Icons.arrow_drop_down, size: 16, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One row of the protocol filter menu, shaped like [KwaaiDropdown]'s rows —
/// tight single-line padding, an accent hover pill with a left/right gutter —
/// but multi-select: a checkbox mark in the leading slot, and tapping does not
/// close the menu.
class _ProtocolMenuRow extends StatefulWidget {
  const _ProtocolMenuRow({
    required this.label,
    required this.onTap,
    this.checked,
    this.mono = false,
    this.tooltip,
  });

  final String label;
  final VoidCallback onTap;

  /// Checkbox state, or null for a plain action row ("Show all peers") whose
  /// leading slot stays empty so its label still aligns with the ids.
  final bool? checked;

  /// Monospace label — protocol ids are things you grep for.
  final bool mono;

  final String? tooltip;

  @override
  State<_ProtocolMenuRow> createState() => _ProtocolMenuRowState();
}

class _ProtocolMenuRowState extends State<_ProtocolMenuRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kwaai = context.kwaai;
    final fg = _hovered ? Colors.white : theme.colorScheme.onSurface;
    final style = theme.textTheme.bodySmall?.copyWith(
      height: 1.0,
      color: fg,
      fontFamily: widget.mono ? 'Menlo' : null,
      fontFamilyFallback: widget.mono
          ? const ['Consolas', 'monospace']
          : null,
    );

    final row = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: _hovered ? kwaai.accentPrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                // Fixed-width slot keeps labels aligned across rows, checkbox
                // or not. An icon rather than a Material Checkbox: it follows
                // the hover pill's foreground for free, and costs no ink
                // controller in an often-rebuilt overlay.
                SizedBox(
                  width: 16,
                  child: switch (widget.checked) {
                    null => null,
                    true => Icon(
                      Icons.check_box,
                      size: 14,
                      color: _hovered ? fg : kwaai.accentPrimary,
                    ),
                    false => Icon(
                      Icons.check_box_outline_blank,
                      size: 14,
                      color: _hovered
                          ? fg
                          : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  },
                ),
                const SizedBox(width: 4),
                Text(widget.label, style: style),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip == null) return row;
    return Tooltip(message: widget.tooltip!, child: row);
  }
}

class _Caption extends StatelessWidget {
  const _Caption({required this.title, this.detail, this.trailing});

  final String title;
  final String? detail;

  /// Optional control shown on the caption bar, after the title.
  final Widget? trailing;

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
        // Title (and any control) left, summary hard against the right edge —
        // enforced by the Spacer below, not by spaceBetween, which would
        // distribute the slack and push the control away from the title.
        children: [
          Text(title, style: style),
          // Sits immediately after the title, with the Spacer pushing the
          // summary to the right edge. The gap is fixed rather than flexible
          // so the control keeps its position as the summary text changes.
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          // Expanded, and no Spacer: a Spacer takes flex 1 and a Flexible
          // text takes another, so the slack was split between them and the
          // summary sat mid-bar. One flexible child claiming all of it, with
          // the text aligned inside, puts it on the right edge — and it still
          // ellipsises when the bar is too narrow.
          Expanded(
            child: Text(
              detail ?? '',
              style: theme.textTheme.bodySmall,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
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

/// How the connection reaches the peer, and which side opened it.
///
/// One cell rather than two: the arrow was pointing right whatever the
/// direction, so it was decoration next to a column that carried the actual
/// fact. Now it points the way the dial went — out for a connection we opened,
/// in for one they opened — and the word beside it says only what the arrow
/// cannot.
///
/// A hole-punched path is labelled "p2p" rather than folded into "direct",
/// because the two are not the same achievement: a plain direct path means
/// there was no NAT in the way, while a punched one means a NAT was traversed.
/// On a node reporting private reachability that is the difference between
/// "nothing works" and "hole punching is working". The mechanism is DCUtR;
/// "p2p" is what it means to the reader.
class _PathCell extends StatelessWidget {
  const _PathCell({
    required this.kind,
    this.dcutr = false,
    this.direction,
    this.bothDirections = false,
  });

  final pbenum.PeerConnKind kind;
  final bool dcutr;

  /// "inbound" / "outbound", or null when there is no connection to describe.
  final String? direction;

  /// The peer holds connections both ways, so one arrow cannot describe it.
  /// Only ever set on the collapsed row, which summarises every connection;
  /// a row in the connections panel is a single path with a single direction.
  final bool bothDirections;

  @override
  Widget build(BuildContext context) {
    final kwaai = context.kwaai;
    final relayed = kind == pbenum.PeerConnKind.PEER_CONN_KIND_RELAY;
    final (label, color) = relayed
        ? ('relay', kwaai.semanticWarning)
        : dcutr
        ? ('p2p', kwaai.accentPrimary)
        : ('direct', kwaai.statusRunning);

    final inbound = direction == 'inbound';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          // Direction matters for a relayed path too, and differently: an
          // outbound relay is us reaching a peer we cannot dial directly,
          // while an inbound one is a peer reaching us through a relay we
          // hold a reservation with. Those are different facts about who is
          // behind what, so the arrow points either way here as well.
          bothDirections
              ? Icons.swap_horiz
              : inbound
              ? Icons.arrow_back
              : Icons.arrow_forward,
          size: 14,
          color: color,
        ),
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

    // Configured role first, then the observed DHT one. They are independent
    // axes, so a configured peer that is also client-mode reads "bootstrap ·
    // client" rather than having one fact hide the other.
    final configured = row.isBootstrap
        ? ('bootstrap', kwaai.accentPrimary)
        : row.isTrustedRelay
        ? ('trusted relay', kwaai.semanticInfo)
        : null;

    if (configured == null && !row.isDhtClient) {
      return Text('—', style: theme.textTheme.bodySmall);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (configured != null)
          Text(
            configured.$1,
            style: theme.textTheme.bodySmall?.copyWith(color: configured.$2),
          ),
        if (configured != null && row.isDhtClient)
          Text(' · ', style: theme.textTheme.bodySmall),
        if (row.isDhtClient)
          Tooltip(
            message:
                'Queries the DHT but does not serve it — never a routing '
                'hop. Common for hivemind/Python peers and for nodes that are '
                'only reachable via a relay.',
            child: Text(
              'client',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              ),
            ),
          ),
      ],
    );
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
