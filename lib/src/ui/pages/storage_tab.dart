import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/generated/kwaai.pb.dart' as pb;
import '../../daemon/daemon_state.dart';
import '../../daemon/storage_state.dart';
import '../theme/kwaai_theme.dart';
import '../widgets/kwaai_dropdown.dart';
import '../widgets/service_status_view.dart';

/// How long without an update before the view is marked stale.
///
/// The daemon suppresses discovery rounds that would say nothing new but
/// still sends an unchanged snapshot every 60 s, so silence up to that
/// point is normal and healthy. This threshold clears that heartbeat with
/// enough margin to absorb a slow DHT round or a probe phase that ran to
/// its timeout without crying wolf — past it, the daemon has missed a
/// beat it promised to send.
///
/// Keep this comfortably above the daemon's HEARTBEAT (grpc_server.rs),
/// which storage discovery shares with block coverage. If that interval
/// changes, this has to move with it — the relationship is asserted in
/// `test/storage_staleness_test.dart`, which is why this is public.
const storageStaleAfter = Duration(seconds: 100);

/// How often to re-evaluate staleness while no updates arrive.
const storageStaleTick = Duration(seconds: 5);

/// Height of the capacity cylinder. Enough to read the per-node segments
/// and their labels as distinct bands, without the bar dominating a view
/// whose substance is the table below it.
const _cylinderHeight = 44.0;

/// Height of the table's caption bar. Fixed rather than intrinsic so the
/// bar is identical with and without the "Show all" button — the button
/// fits the bar, not the other way round. Mirrors the Sharding tab.
const _captionBarHeight = 28.0;

/// Settings tab visualising the network's VPK storage: how much capacity
/// is out there, how much of it this node can actually reach, and which
/// nodes hold it — the same view `kwaainet vpk discover` prints in the
/// terminal.
///
/// Data arrives through [storageDiscoveryProvider]. The first round
/// delivers two updates: the DHT registry (fast) and then the same nodes
/// with reachability resolved (slow, because unreachable nodes cost a
/// full dial timeout). The first is rendered immediately with the status
/// column pending, so the table is never blank while probes are in
/// flight.
///
/// Later rounds only arrive when something actually changed, plus a
/// heartbeat while it doesn't — which is what [storageStaleAfter]
/// measures against. That is why the pending state is only ever seen
/// once: re-running it every round would flicker the status column back
/// to "checking" on a table that is already correct.
class StorageTab extends ConsumerStatefulWidget {
  const StorageTab({super.key});

  @override
  ConsumerState<StorageTab> createState() => _StorageTabState();
}

class _StorageTabState extends ConsumerState<StorageTab> {
  /// Peer id highlighted in the table and the cylinder. Null = nothing
  /// highlighted.
  String? _selectedPeerId;

  /// Trust tier a node must be at, exactly, to appear in the table and
  /// the cylinder. Null = no filter (the default: show everything).
  _TrustTier? _tierFilter;

  /// Last update we rendered. The subscription is torn down and re-opened
  /// across daemon reconnects; holding the last snapshot keeps the view
  /// stable (rather than flashing back to a spinner) through the gap.
  pb.StorageUpdate? _last;

  /// When [_last] arrived, for the staleness check.
  ///
  /// Local arrival time rather than the update's own `server_time`: the
  /// question is "how long since this daemon last told us anything",
  /// which a clock skew between the two machines shouldn't distort.
  DateTime? _lastArrived;

  /// Drives a rebuild while no updates are arriving, so the staleness cue
  /// can appear during silence. Nothing else would rebuild the view.
  Timer? _staleTicker;

  @override
  void initState() {
    super.initState();
    _staleTicker = Timer.periodic(storageStaleTick, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _staleTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final discovery = ref.watch(storageDiscoveryProvider);
    final fresh = discovery.valueOrNull;
    if (fresh != null) {
      _last = fresh;
      _lastArrived = DateTime.now();
    }
    final update = _last;

    if (update == null) {
      // Reachability, not the local PID: with KWAAINET_GRPC_PORT set the
      // daemon runs elsewhere and has no PID on this machine.
      final running = ref.watch(daemonAvailableProvider);
      return ServiceStatusView(
        headline: running
            ? 'Querying the network for storage nodes…'
            : unavailableHeadline(),
        spinner: running,
        subtitle: running ? null : Text(unavailableHint('see storage')),
      );
    }

    // Filtering and ordering happen once, here: the cylinder and the
    // table read the same list so the two halves can never disagree
    // about what is shown.
    final tier = _tierFilter;
    final peers = orderStoragePeers(
      tier == null
          ? update.peers
          : update.peers.where((p) => p.trustTier == tier.wire),
    );

    final totals = StorageTotals.of(peers);

    final arrived = _lastArrived;
    final staleFor = arrived == null
        ? null
        : DateTime.now().difference(arrived);
    final stale = staleFor != null && staleFor > storageStaleAfter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: _StorageHeader(
            totals: totals,
            probesPending: update.probesPending,
            stale: stale,
            staleFor: staleFor,
            tierFilter: _tierFilter,
            onTierFilterChanged: (v) => setState(() {
              _tierFilter = v;
              // A node hidden by the new filter must not stay selected —
              // the cylinder would keep dimming around a row the user can
              // no longer see.
              _selectedPeerId = null;
            }),
          ),
        ),
        Divider(height: 1, color: context.kwaai.divider),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: _CapacityCylinder(
            peers: peers,
            totals: totals,
            selectedPeerId: _selectedPeerId,
          ),
        ),
        Expanded(
          child: _TableSection(
            peers: peers,
            probesPending: update.probesPending,
            selectedPeerId: _selectedPeerId,
            onSelectPeer: _togglePeer,
            filtered: tier != null,
            onClearFilter: () => setState(() {
              _tierFilter = null;
              _selectedPeerId = null;
            }),
          ),
        ),
      ],
    );
  }

  void _togglePeer(String peerId) => setState(() {
    _selectedPeerId = _selectedPeerId == peerId ? null : peerId;
  });
}

/// The daemon's trust tiers, in ascending order — mirrors `TrustTier` in
/// kwaai-cli's reputation store, and the same enum the Sharding tab
/// filters by. Declaration order is the ranking, which is what the filter
/// dropdown lists them by.
enum _TrustTier {
  unknown('UNKNOWN', 'Unknown'),
  known('KNOWN', 'Known'),
  verified('VERIFIED', 'Verified'),
  trusted('TRUSTED', 'Trusted');

  const _TrustTier(this.wire, this.label);

  /// The string the daemon puts on the wire in `StoragePeer.trust_tier`.
  final String wire;

  /// How the tier is written in the UI. Separate from [wire] so the
  /// filter still matches the daemon's own casing while the dropdown
  /// reads as prose rather than as a constant.
  final String label;
}

/// Parses a wire tier. Null for the empty string the daemon sends when
/// the local reputation system is disabled, and for any tier a newer
/// daemon adds that this build doesn't know.
_TrustTier? _tierOf(String wire) {
  for (final t in _TrustTier.values) {
    if (t.wire == wire) return t;
  }
  return null;
}

/// Capacity split three ways: used and free on the nodes this daemon can
/// reach, and the advertised total of the ones it cannot.
///
/// Used comes from the probe (advertised total minus reported free), so
/// it only exists for nodes that answered. An unreachable node's split is
/// unknowable from here — all that is known is what it claims to have in
/// total, which is why it forms its own zone rather than being folded
/// into either of the other two.
///
/// Public so `test/storage_staleness_test.dart` can pin the split — the
/// three zones have to add up to the classified total whatever the nodes
/// report, including the degenerate cases.
class StorageTotals {
  const StorageTotals({
    required this.advertisedGb,
    required this.usedGb,
    required this.freeGb,
    required this.unreachableGb,
    required this.tenants,
    required this.reachableCount,
    required this.unreachableCount,
    required this.pendingCount,
  });

  factory StorageTotals.of(List<pb.StoragePeer> peers) {
    var advertised = 0.0;
    var used = 0.0;
    var free = 0.0;
    var unreachable = 0.0;
    var tenants = 0;
    var reachableCount = 0;
    var unreachableCount = 0;
    var pendingCount = 0;

    for (final p in peers) {
      advertised += p.capacityGb;
      tenants += p.tenantCount;
      switch (p.reachability) {
        case pb.StorageReachability.STORAGE_REACHABILITY_REACHABLE:
          free += p.capacityGbFree;
          // Clamped: a node whose reported free space exceeds its
          // advertised capacity would otherwise contribute negative used
          // space and shrink the bar.
          used += (p.capacityGb - p.capacityGbFree).clamp(0.0, p.capacityGb);
          reachableCount++;
        case pb.StorageReachability.STORAGE_REACHABILITY_UNREACHABLE:
          unreachable += p.capacityGb;
          unreachableCount++;
        default:
          // Still being probed. Counted in the node tally and the
          // advertised total, but not yet in any of the three zones —
          // which of them it belongs to is exactly what is unknown.
          pendingCount++;
      }
    }

    return StorageTotals(
      advertisedGb: advertised,
      usedGb: used,
      freeGb: free,
      unreachableGb: unreachable,
      tenants: tenants,
      reachableCount: reachableCount,
      unreachableCount: unreachableCount,
      pendingCount: pendingCount,
    );
  }

  final double advertisedGb;
  final double usedGb;
  final double freeGb;
  final double unreachableGb;
  final int tenants;
  final int reachableCount;
  final int unreachableCount;
  final int pendingCount;

  /// Capacity on nodes that answered a probe — the part of the network
  /// this daemon could actually store to.
  double get reachableGb => usedGb + freeGb;

  int get nodeCount => reachableCount + unreachableCount + pendingCount;
}

/// A peer's slice of one zone: how much of the zone it holds, and how far
/// into the zone that slice starts.
///
/// Both in GB — the cylinder divides them by the zone's total to get the
/// fractions it draws with.
class CapacityBand {
  const CapacityBand({required this.amountGb, required this.offsetGb});

  static const none = CapacityBand(amountGb: 0, offsetGb: 0);

  final double amountGb;
  final double offsetGb;
}

/// Locate [peerId]'s free space within the free zone.
///
/// The zone is the reachable peers laid end to end in [peers] order — the
/// same order the table shows — so a peer's band lands at its own place
/// in that run rather than at the zone's left edge. Unreachable and
/// still-probing peers are skipped: they contribute nothing to free
/// space, so they take up no room in the zone either.
///
/// Returns [CapacityBand.none] when nothing is selected, when the selected
/// peer isn't reachable, or when it has no free space to point at.
///
/// Public so `test/storage_staleness_test.dart` can pin the placement —
/// an offset that ignored ordering would still look plausible on screen.
CapacityBand freeBandFor(List<pb.StoragePeer> peers, String? peerId) =>
    _bandFor(
      peers,
      peerId,
      pb.StorageReachability.STORAGE_REACHABILITY_REACHABLE,
      (p) => p.capacityGbFree,
    );

/// The same, for the unreachable zone.
///
/// Selecting an unreachable node should point at it too — it is the one
/// case where the table says "this capacity exists but you cannot use it"
/// and the bar could show *which* of it. The figure is the node's
/// advertised total, because an unreachable node reports no used/free
/// split; that is the whole of its contribution to the zone.
CapacityBand unreachableBandFor(List<pb.StoragePeer> peers, String? peerId) =>
    _bandFor(
      peers,
      peerId,
      pb.StorageReachability.STORAGE_REACHABILITY_UNREACHABLE,
      (p) => p.capacityGb,
    );

CapacityBand _bandFor(
  List<pb.StoragePeer> peers,
  String? peerId,
  pb.StorageReachability zone,
  double Function(pb.StoragePeer) amount,
) {
  if (peerId == null) return CapacityBand.none;
  var offset = 0.0;
  for (final p in peers) {
    if (p.reachability != zone) continue;
    if (p.peerId == peerId) {
      return CapacityBand(amountGb: amount(p), offsetGb: offset);
    }
    offset += amount(p);
  }
  return CapacityBand.none;
}

/// Orders the node list: reachable first, then those still being probed,
/// then the unreachable. Capacity this daemon can actually use belongs at
/// the top of the table and at the left of the cylinder.
///
/// Ties keep the daemon's own name-then-peer-id order rather than relying
/// on the sort being stable, so a row only moves when its reachability
/// does — the probe phase resolving is the one reshuffle the user sees.
///
/// Public so `test/storage_order_test.dart` can pin it.
List<pb.StoragePeer> orderStoragePeers(Iterable<pb.StoragePeer> peers) {
  final ordered = peers.toList();
  ordered.sort((a, b) {
    final byReach = _reachRank(a).compareTo(_reachRank(b));
    if (byReach != 0) return byReach;
    final byName = a.publicName.compareTo(b.publicName);
    return byName != 0 ? byName : a.peerId.compareTo(b.peerId);
  });
  return ordered;
}

int _reachRank(pb.StoragePeer p) => switch (p.reachability) {
  pb.StorageReachability.STORAGE_REACHABILITY_REACHABLE => 0,
  pb.StorageReachability.STORAGE_REACHABILITY_UNREACHABLE => 2,
  _ => 1,
};

/// Formats a GB figure the way the CLI does: one decimal place, and TB
/// once the number would otherwise run to four digits.
String formatCapacity(double gb) {
  if (gb >= 1000) return '${(gb / 1000).toStringAsFixed(1)} TB';
  return '${gb.toStringAsFixed(1)} GB';
}

/// Coarse "how long ago" for the staleness label. Rounded deliberately:
/// the exact second is noise, and a value that ticks every second would
/// pull the eye back to a number that isn't changing meaningfully.
String describeStorageStaleness(Duration? d) {
  if (d == null) return 'a while';
  final mins = d.inMinutes;
  if (mins < 2) return '${d.inSeconds}s';
  if (mins < 60) return '${mins}m';
  final hours = d.inHours;
  return hours < 24 ? '${hours}h' : '${d.inDays}d';
}

/// Capacity summary + status badge, then the trust filter.
class _StorageHeader extends StatelessWidget {
  const _StorageHeader({
    required this.totals,
    required this.probesPending,
    required this.stale,
    required this.staleFor,
    required this.tierFilter,
    required this.onTierFilterChanged,
  });

  final StorageTotals totals;
  final bool probesPending;

  /// The daemon has gone quiet for longer than a discovery round, so what
  /// is shown is no longer known to be current.
  final bool stale;

  /// How long since the last update arrived. Null before the first one.
  final Duration? staleFor;
  final _TrustTier? tierFilter;
  final ValueChanged<_TrustTier?> onTierFilterChanged;

  @override
  Widget build(BuildContext context) {
    final kwaai = context.kwaai;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    // Staleness outranks everything: a confident green figure on data the
    // daemon has stopped confirming is the one genuinely misleading state
    // here. While probes are still in flight the badge stays neutral —
    // the reachable figure is mid-computation, not final.
    final IconData icon;
    final Color iconColor;
    if (stale) {
      icon = Icons.cloud_off;
      iconColor = onSurfaceVariant;
    } else if (probesPending) {
      icon = Icons.sync;
      iconColor = onSurfaceVariant;
    } else if (totals.reachableCount > 0) {
      icon = Icons.cloud_done;
      iconColor = kwaai.semanticSuccess;
    } else {
      icon = Icons.cloud_off;
      iconColor = kwaai.semanticWarning;
    }

    // Leads with free space: of the three zones that is the one a user
    // acts on. The advertised total follows as the denominator, so the
    // gap between them stays visible rather than being implied.
    final summary = probesPending
        ? '${formatCapacity(totals.advertisedGb)} advertised across '
              '${totals.nodeCount} node(s) — checking reachability…'
        : '${formatCapacity(totals.freeGb)} free of '
              '${formatCapacity(totals.advertisedGb)} advertised across '
              '${totals.nodeCount} node(s)';

    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                summary,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                stale
                    ? 'No update for ${describeStorageStaleness(staleFor)} — '
                          'the daemon has gone quiet'
                    : '${totals.tenants} tenant(s) · '
                          '${totals.reachableCount} reachable · '
                          '${totals.unreachableCount} unreachable',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _TrustFilter(value: tierFilter, onChanged: onTierFilterChanged),
      ],
    );
  }
}

/// Filters the view to one trust tier. Matches the Sharding tab's filter
/// so a peer is found the same way in both views: exact tier, listed
/// highest-first, with "All peers" as the default.
class _TrustFilter extends StatelessWidget {
  const _TrustFilter({required this.value, required this.onChanged});

  final _TrustTier? value;
  final ValueChanged<_TrustTier?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Filter nodes by trust tier',
      child: KwaaiDropdown<_TrustTier?>(
        value: value,
        items: [
          const KwaaiDropdownItem(value: null, label: 'All peers'),
          for (final tier in _TrustTier.values.reversed)
            KwaaiDropdownItem(value: tier, label: tier.label),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

/// Horizontal capacity bar spanning the width of the page, divided into
/// three aggregate zones: used, free, and unreachable.
///
/// The zones read left to right as descending confidence — space
/// confirmed in use, space confirmed available, and space that is merely
/// advertised because this daemon cannot reach the node holding it. Only
/// the first two are confirmed: an unreachable node's used/free split is
/// unknowable from here, which is why its capacity forms its own zone
/// rather than being folded into either of the others.
///
/// Selecting a peer highlights its share of the free zone, so a node's
/// contribution to what is actually available reads against the network
/// total rather than in isolation.
class _CapacityCylinder extends StatelessWidget {
  const _CapacityCylinder({
    required this.peers,
    required this.totals,
    required this.selectedPeerId,
  });

  final List<pb.StoragePeer> peers;
  final StorageTotals totals;
  final String? selectedPeerId;

  @override
  Widget build(BuildContext context) {
    final kwaai = context.kwaai;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    // The bar is proportioned over what has actually been classified.
    // Nodes still being probed are deliberately excluded: they belong to
    // one of the three zones, but which one is exactly what is not yet
    // known, and guessing would make the bar jump when the answer lands.
    final classified = totals.usedGb + totals.freeGb + totals.unreachableGb;

    if (peers.isEmpty || classified <= 0) {
      return Container(
        height: _cylinderHeight,
        decoration: BoxDecoration(
          color: kwaai.divider.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(_cylinderHeight / 2),
        ),
        alignment: Alignment.center,
        child: Text(
          totals.pendingCount > 0
              ? 'Checking reachability…'
              : 'No storage capacity discovered',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: onSurfaceVariant),
        ),
      );
    }

    // Where the selected node's free space sits *within* the free zone.
    //
    // The zone is treated as the reachable peers laid end to end in the
    // table's own order, so a node's band lands at its own place in that
    // run rather than always at the left edge. Two selections in a row
    // then read as different positions, and the band's offset is a stable
    // property of the node rather than an artefact of it being selected.
    final selected = selectedPeerId == null
        ? null
        : peers.where((p) => p.peerId == selectedPeerId).firstOrNull;

    final band = freeBandFor(peers, selectedPeerId);
    final downBand = unreachableBandFor(peers, selectedPeerId);
    final selectedLabel = (selected?.publicName.isEmpty ?? true)
        ? selected?.peerId
        : selected?.publicName;

    return ClipRRect(
      borderRadius: BorderRadius.circular(_cylinderHeight / 2),
      child: SizedBox(
        height: _cylinderHeight,
        child: Row(
          children: [
            _CapacityZone(
              flex: totals.usedGb / classified,
              color: onSurfaceVariant,
              label: 'used',
              amount: totals.usedGb,
              dimmed: selectedPeerId != null,
            ),
            _CapacityZone(
              flex: totals.freeGb / classified,
              color: kwaai.semanticSuccess,
              label: 'free',
              amount: totals.freeGb,
              dimmed: selectedPeerId != null,
              // The selected node's slice of this zone, and where it
              // starts — both as fractions of the zone itself.
              highlightFraction: totals.freeGb > 0
                  ? band.amountGb / totals.freeGb
                  : 0.0,
              highlightOffset: totals.freeGb > 0
                  ? band.offsetGb / totals.freeGb
                  : 0.0,
              highlightLabel: selectedLabel,
            ),
            _CapacityZone(
              flex: totals.unreachableGb / classified,
              color: kwaai.semanticWarning,
              label: 'unreachable',
              amount: totals.unreachableGb,
              dimmed: selectedPeerId != null,
              // Selecting an unreachable node highlights its share here,
              // the same way a reachable one is picked out of free.
              highlightFraction: totals.unreachableGb > 0
                  ? downBand.amountGb / totals.unreachableGb
                  : 0.0,
              highlightOffset: totals.unreachableGb > 0
                  ? downBand.offsetGb / totals.unreachableGb
                  : 0.0,
              highlightLabel: selectedLabel,
            ),
          ],
        ),
      ),
    );
  }
}

/// One zone of the capacity bar.
///
/// Zones with nothing in them collapse entirely rather than lingering as
/// a sliver: unlike the per-node segments this replaced, a zero-width
/// zone carries no information and is not clickable, so there is nothing
/// to keep on screen.
class _CapacityZone extends StatelessWidget {
  const _CapacityZone({
    required this.flex,
    required this.color,
    required this.label,
    required this.amount,
    required this.dimmed,
    this.highlightFraction = 0.0,
    this.highlightOffset = 0.0,
    this.highlightLabel,
  });

  final double flex;
  final Color color;
  final String label;
  final double amount;

  /// A peer is selected, so this zone recedes unless it holds the
  /// highlight. Contrast-only, matching the Sharding grid's treatment.
  final bool dimmed;

  /// Share of *this zone* belonging to the selected peer, in [0, 1].
  final double highlightFraction;

  /// Where that share starts within the zone, in [0, 1]. Lets the band
  /// sit at the peer's own position rather than at the zone's left edge.
  final double highlightOffset;

  final String? highlightLabel;

  @override
  Widget build(BuildContext context) {
    if (flex <= 0) return const SizedBox.shrink();

    final hasHighlight = highlightFraction > 0;
    // A dimmed zone still reads as itself, just quieter — except where it
    // holds the highlight, which stays at full strength.
    final alpha = dimmed && !hasHighlight ? 0.32 : 0.85;

    // Amount first: the number is what the eye is looking for, and it
    // lines up across zones rather than starting at a different offset in
    // each one.
    final text = '${formatCapacity(amount)} $label';

    return Expanded(
      // Rounded to permille: Expanded needs an int, and truncating to
      // whole percent would lose zones smaller than 1% of the bar.
      flex: (flex * 1000).round().clamp(1, 1000),
      child: Tooltip(
        message: hasHighlight && highlightLabel != null
            ? '$text\n${formatCapacity(amount * highlightFraction)} '
                  'on $highlightLabel'
            : text,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: color.withValues(alpha: alpha * 0.38)),
            // The selected peer's share, at full saturation and placed at
            // that peer's own offset within the zone.
            if (hasHighlight)
              LayoutBuilder(
                builder: (context, c) {
                  final start = highlightOffset.clamp(0.0, 1.0) * c.maxWidth;
                  // Floored at a hairline so a peer with very little free
                  // space still shows where it sits, rather than
                  // vanishing into a sub-pixel band.
                  final width = (highlightFraction.clamp(0.0, 1.0) * c.maxWidth)
                      .clamp(2.0, math.max(c.maxWidth - start, 2.0))
                      .toDouble();
                  return Stack(
                    children: [
                      Positioned(
                        left: start,
                        top: 0,
                        bottom: 0,
                        width: width,
                        child: ColoredBox(color: color.withValues(alpha: 0.95)),
                      ),
                    ],
                  );
                },
              ),
            // Label, shown only where the zone is wide enough to hold it
            // without clipping mid-glyph.
            LayoutBuilder(
              builder: (context, c) => c.maxWidth < 78
                  ? const SizedBox.shrink()
                  : Center(
                      child: Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface
                              .withValues(alpha: dimmed ? 0.5 : 0.9),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Caption bar + node table.
class _TableSection extends StatelessWidget {
  const _TableSection({
    required this.peers,
    required this.probesPending,
    required this.selectedPeerId,
    required this.onSelectPeer,
    required this.filtered,
    required this.onClearFilter,
  });

  final List<pb.StoragePeer> peers;
  final bool probesPending;
  final String? selectedPeerId;
  final ValueChanged<String> onSelectPeer;
  final bool filtered;
  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context) {
    final kwaai = context.kwaai;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: _captionBarHeight,
          decoration: BoxDecoration(
            // A step darker than the section behind it, so the caption
            // reads as a header band rather than as the table's first
            // row. Derived from the divider colour so it tracks both
            // light and dark themes.
            color: kwaai.divider.withValues(alpha: 0.28),
            border: Border(
              top: BorderSide(color: kwaai.divider),
              bottom: BorderSide(color: kwaai.divider),
            ),
          ),
          padding: const EdgeInsets.only(left: 16, right: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  filtered
                      ? '${peers.length} node(s) — filtered'
                      : 'All storage nodes — ${peers.length}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (filtered) _ShowAllButton(onPressed: onClearFilter),
            ],
          ),
        ),
        Expanded(
          child: _StorageNodeTable(
            peers: peers,
            probesPending: probesPending,
            selectedPeerId: selectedPeerId,
            onSelectPeer: onSelectPeer,
            emptyMessage: filtered
                ? 'No nodes match this filter.'
                : 'No VPK storage nodes found in the DHT.',
          ),
        ),
      ],
    );
  }
}

/// Clears the reachability filter. Deliberately not a [TextButton.icon]:
/// that carries a 36px minimum height and its own vertical padding, which
/// would force the caption bar taller the moment a filter is applied.
class _ShowAllButton extends StatelessWidget {
  const _ShowAllButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = context.kwaai.accentPrimary;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.clear, size: 13, color: accent),
              const SizedBox(width: 4),
              Text(
                'Show all',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wide node table — the gRPC twin of the `kwaainet vpk discover`
/// terminal output. Clicking a row selects that node, highlighting its
/// segment in the cylinder.
class _StorageNodeTable extends StatelessWidget {
  const _StorageNodeTable({
    required this.peers,
    required this.probesPending,
    required this.selectedPeerId,
    required this.onSelectPeer,
    required this.emptyMessage,
  });

  final List<pb.StoragePeer> peers;
  final bool probesPending;
  final String? selectedPeerId;
  final ValueChanged<String> onSelectPeer;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (peers.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final kwaai = context.kwaai;
    final headStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      letterSpacing: 0.6,
    );
    final cellStyle = Theme.of(context).textTheme.bodySmall;
    final monoStyle = cellStyle?.copyWith(
      fontFamily: 'Menlo',
      fontFamilyFallback: const ['Consolas', 'monospace'],
    );
    final selectedFill = kwaai.accentPrimary.withValues(alpha: 0.16);

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
              columnSpacing: 24,
              horizontalMargin: 16,
              showCheckboxColumn: false,
              columns: [
                DataColumn(label: Text('STATUS', style: headStyle)),
                DataColumn(label: Text('NAME', style: headStyle)),
                DataColumn(
                  label: Text('CAPACITY', style: headStyle),
                  numeric: true,
                ),
                DataColumn(
                  label: Text('FREE', style: headStyle),
                  numeric: true,
                ),
                DataColumn(
                  label: Text('TENANTS', style: headStyle),
                  numeric: true,
                ),
                DataColumn(label: Text('MODE', style: headStyle)),
                DataColumn(label: Text('VERSION', style: headStyle)),
                DataColumn(label: Text('TRUST', style: headStyle)),
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
                      DataCell(_ReachabilityCell(peer: p)),
                      DataCell(
                        Text(
                          p.publicName.isEmpty ? '—' : p.publicName,
                          style: cellStyle,
                        ),
                      ),
                      DataCell(
                        Text(formatCapacity(p.capacityGb), style: cellStyle),
                      ),
                      DataCell(
                        Text(
                          // Free space comes from the probe, so it only
                          // means anything once the node has answered.
                          p.reachability ==
                                  pb
                                      .StorageReachability
                                      .STORAGE_REACHABILITY_REACHABLE
                              ? formatCapacity(p.capacityGbFree)
                              : '—',
                          style: cellStyle,
                        ),
                      ),
                      DataCell(Text('${p.tenantCount}', style: cellStyle)),
                      DataCell(
                        Text(p.mode.isEmpty ? '—' : p.mode, style: cellStyle),
                      ),
                      DataCell(
                        Text(
                          p.vpkVersion.isEmpty ? '—' : p.vpkVersion,
                          style: cellStyle,
                        ),
                      ),
                      DataCell(_TrustCell(peer: p)),
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

/// Reachability as a coloured dot + label, matching the CLI's 🟢/🟡.
///
/// The pending state is deliberately distinct from unreachable: during
/// the probe phase nothing is yet known, and showing those rows as
/// failures would be wrong for the second or two before they answer.
class _ReachabilityCell extends StatelessWidget {
  const _ReachabilityCell({required this.peer});

  final pb.StoragePeer peer;

  @override
  Widget build(BuildContext context) {
    final kwaai = context.kwaai;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    final (Color color, String label) = switch (peer.reachability) {
      pb.StorageReachability.STORAGE_REACHABILITY_REACHABLE => (
        kwaai.semanticSuccess,
        'Reachable',
      ),
      pb.StorageReachability.STORAGE_REACHABILITY_UNREACHABLE => (
        kwaai.semanticWarning,
        'Unreachable',
      ),
      _ => (onSurfaceVariant, 'Checking…'),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Trust tier label, tinted by tier, with the numeric score in a tooltip.
/// Renders "—" when the local reputation system is disabled.
///
/// Mirrors the Sharding tab's tint ramp so a peer reads the same in both
/// views: only the top tier gets the success colour, and the two middle
/// tiers stay distinguishable from it.
class _TrustCell extends StatelessWidget {
  const _TrustCell({required this.peer});

  final pb.StoragePeer peer;

  @override
  Widget build(BuildContext context) {
    if (peer.trustTier.isEmpty) {
      return Text('—', style: Theme.of(context).textTheme.bodySmall);
    }
    final kwaai = context.kwaai;
    final color = switch (_tierOf(peer.trustTier)) {
      _TrustTier.trusted => kwaai.semanticSuccess,
      _TrustTier.verified => kwaai.semanticInfo,
      _TrustTier.known => kwaai.semanticWarning,
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
    };
    return Tooltip(
      message: 'score ${peer.trustScore.toStringAsFixed(2)}',
      child: Text(
        peer.trustTier,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
