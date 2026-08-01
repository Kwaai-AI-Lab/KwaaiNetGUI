import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/generated/kwaai.pb.dart' as pb;
import '../../daemon/block_coverage_state.dart';
import '../../daemon/daemon_state.dart';
import '../theme/kwaai_theme.dart';
import '../widgets/kwaai_dropdown.dart';
import '../widgets/service_status_view.dart';

/// Grid cell sizing. The minimum is the smallest cell that still reads as
/// a distinct box at a glance; the maximum is well past "bigger than an
/// icon", which is where the user asked the grid to stop growing on its
/// own. The default sits at the slider's midpoint.
const _minCellSize = 8.0;
const _maxCellSize = 72.0;
const _defaultCellSize = (_minCellSize + _maxCellSize) / 2;

/// Floor on the table's share of the viewport. The grid may take at most
/// the rest, however large the cells are — the table never gets squeezed
/// out of existence by the slider.
const _minTableHeight = 180.0;

/// How long without an update before the view is marked stale.
///
/// The daemon suppresses updates that would say nothing new but still
/// sends an unchanged snapshot every 60 s, so silence up to that point is
/// normal and healthy. This threshold clears that heartbeat with enough
/// margin to absorb a slow tick or a busy DHT round without crying wolf —
/// past it, the daemon has missed a beat it promised to send.
///
/// Keep this comfortably above the daemon's HEARTBEAT (grpc_server.rs).
/// If that interval changes, this has to move with it — the relationship
/// between the two is asserted in `test/coverage_staleness_test.dart`,
/// which is why this is public.
const staleAfter = Duration(seconds: 100);

/// How often to re-evaluate staleness while no updates arrive.
const staleTick = Duration(seconds: 5);

/// Height of the table's caption bar. Fixed rather than intrinsic so the
/// bar is identical with and without the "Show all" button — the button
/// fits the bar, not the other way round.
const _captionBarHeight = 28.0;

/// Settings tab visualising how the model is sharded across the network:
/// which peers serve which blocks, and where the gaps are. A viewport-filling
/// grid of blocks coloured by how many peers serve each one, over a peer
/// table (the same view `kwaainet shard chain` prints in the terminal).
///
/// Data arrives through [blockCoverageProvider], a gRPC subscription the
/// daemon pushes to whenever coverage changes — plus a heartbeat while it
/// doesn't, which is what [staleAfter] measures against.
class ShardingTab extends ConsumerStatefulWidget {
  const ShardingTab({super.key});

  @override
  ConsumerState<ShardingTab> createState() => _ShardingTabState();
}

class _ShardingTabState extends ConsumerState<ShardingTab> {
  /// Block whose peers the table is filtered to. Null = show every peer.
  int? _selectedBlock;

  /// Peer id highlighted in the table; its served blocks are outlined in
  /// the grid. Null = nothing highlighted.
  String? _selectedPeerId;

  /// Hides the grid so the table gets the whole viewport. The table is
  /// always present — this toggle is only about the grid.
  bool _tableOnly = false;

  /// Trust tier a peer must be at, exactly, to appear in the grid counts
  /// and the table. Null = no filter (the default: show everything).
  _TrustTier? _tierFilter;

  /// Target edge length of a grid cell, in logical pixels. Drives the
  /// grid/table split: the grid claims exactly the height its blocks need
  /// at this size and the table gets everything left over.
  double _cellSize = _defaultCellSize;

  /// Last update we rendered. The subscription is torn down and re-opened
  /// across daemon reconnects; holding the last snapshot keeps the view
  /// stable (rather than flashing back to a spinner) through the gap.
  pb.BlockCoverageUpdate? _last;

  /// When [_last] arrived, for the staleness check.
  ///
  /// Local arrival time rather than the update's own `server_time`: the
  /// question is "how long since this daemon last told us anything",
  /// which a clock skew between the two machines shouldn't distort.
  DateTime? _lastArrived;

  /// Drives a rebuild while no updates are arriving.
  ///
  /// The daemon suppresses updates that would say nothing new, so a
  /// healthy stable network is legitimately silent. Nothing else would
  /// rebuild this view during that silence, so without a tick the
  /// staleness cue could never appear.
  Timer? _staleTicker;

  @override
  void initState() {
    super.initState();
    _staleTicker = Timer.periodic(
      staleTick,
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
    final coverage = ref.watch(blockCoverageProvider);
    final fresh = coverage.valueOrNull;
    if (fresh != null) {
      _last = fresh;
      _lastArrived = DateTime.now();
    }
    final update = _last;

    if (update == null) {
      final running =
          ref.watch(daemonStatusProvider).valueOrNull?.running ?? false;
      return ServiceStatusView(
        headline: running
            ? 'Querying the network for block coverage…'
            : 'Daemon is not running',
        spinner: running,
        subtitle: running
            ? null
            : const Text('Start it from the Status tab to see coverage.'),
      );
    }

    // Trust filtering happens once, here: everything downstream (grid
    // colours, coverage counts, the table) reads the same peer list so
    // the two halves can never disagree about what is being shown.
    final tier = _tierFilter;
    final peers = tier == null
        ? update.peers
        : update.peers
            .where((p) => p.trustTier == tier.wire)
            .toList(growable: false);
    final counts = _peerCounts(peers, update.totalBlocks);
    final covered = counts.where((c) => c > 0).length;

    // A block filter that no longer matches anything (the peer serving it
    // dropped out, or the trust filter excluded it) still narrows the
    // table correctly — it just yields an empty list, which reads as
    // "nobody serves this block" rather than silently showing everything.
    final block = _selectedBlock;
    final tablePeers = block == null
        ? peers
        : peers
            .where((p) => p.startBlock <= block && block < p.endBlock)
            .toList(growable: false);

    // Silence is normal — the daemon only sends when something changed —
    // but it promises an unchanged snapshot every heartbeat. Past the
    // threshold that promise has been broken, so what is on screen is no
    // longer known to be current and the header says so.
    final arrived = _lastArrived;
    final staleFor = arrived == null ? null : DateTime.now().difference(arrived);
    final stale = staleFor != null && staleFor > staleAfter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: _CoverageHeader(
            update: update,
            coveredBlocks: covered,
            peerCount: peers.length,
            stale: stale,
            staleFor: staleFor,
            tableOnly: _tableOnly,
            tierFilter: _tierFilter,
            cellSize: _cellSize,
            // The slider only sizes the grid, which table-only mode
            // hides — so it hides with it rather than sitting inert.
            showCellSize: !_tableOnly,
            onViewChanged: (v) => setState(() => _tableOnly = v),
            onTierFilterChanged: (v) => setState(() => _tierFilter = v),
            onCellSizeChanged: (v) => setState(() => _cellSize = v),
          ),
        ),
        Divider(height: 1, color: context.kwaai.divider),
        Expanded(
          child: _tableOnly
              ? _TableSection(
                  peers: tablePeers,
                  selectedBlock: block,
                  selectedPeerId: _selectedPeerId,
                  onSelectPeer: _togglePeer,
                  onClearBlock: () => setState(() => _selectedBlock = null),
                )
              : _GridAndTable(
                  totalBlocks: update.totalBlocks,
                  counts: counts,
                  cellSize: _cellSize,
                  selectedBlock: block,
                  highlightedBlocks: _blocksServedBy(peers, _selectedPeerId),
                  onSelectBlock: _toggleBlock,
                  tablePeers: tablePeers,
                  selectedPeerId: _selectedPeerId,
                  onSelectPeer: _togglePeer,
                  onClearBlock: () => setState(() => _selectedBlock = null),
                ),
        ),
      ],
    );
  }

  /// Selecting a block drops any peer selection: the two are competing
  /// filters on the same table, and leaving the peer selected would keep
  /// the grid dimmed to a range the user has just navigated away from.
  void _toggleBlock(int block) => setState(() {
        _selectedBlock = _selectedBlock == block ? null : block;
        _selectedPeerId = null;
      });

  void _togglePeer(String peerId) => setState(() {
        _selectedPeerId = _selectedPeerId == peerId ? null : peerId;
      });
}

/// The daemon's trust tiers, in ascending order — mirrors `TrustTier` in
/// kwaai-cli's reputation store. Declaration order is the ranking, which
/// is what the filter dropdown lists them by.
enum _TrustTier {
  unknown('UNKNOWN', 'Unknown'),
  known('KNOWN', 'Known'),
  verified('VERIFIED', 'Verified'),
  trusted('TRUSTED', 'Trusted');

  const _TrustTier(this.wire, this.label);

  /// The string the daemon puts on the wire in `BlockPeer.trust_tier`.
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

/// Coarse "how long ago" for the staleness label. Rounded deliberately:
/// the exact second is noise, and a value that ticks every second would
/// pull the eye back to a number that isn't changing meaningfully.
String describeStaleness(Duration? d) {
  if (d == null) return 'a while';
  final mins = d.inMinutes;
  if (mins < 2) return '${d.inSeconds}s';
  if (mins < 60) return '${mins}m';
  final hours = d.inHours;
  return hours < 24 ? '${hours}h' : '${d.inDays}d';
}

/// Block indices served by [peerId], for grid highlighting. A peer can
/// appear more than once in the DHT (separate announced ranges), so this
/// unions every matching entry rather than taking the first.
Set<int> _blocksServedBy(List<pb.BlockPeer> peers, String? peerId) {
  if (peerId == null) return const {};
  final blocks = <int>{};
  for (final p in peers) {
    if (p.peerId != peerId) continue;
    for (var b = p.startBlock; b < p.endBlock; b++) {
      blocks.add(b);
    }
  }
  return blocks;
}

/// Model prefix, coverage summary + full-coverage check mark, then the
/// controls: trust filter, cell-size slider, grid/table toggle.
class _CoverageHeader extends StatelessWidget {
  const _CoverageHeader({
    required this.update,
    required this.coveredBlocks,
    required this.peerCount,
    required this.stale,
    required this.staleFor,
    required this.tableOnly,
    required this.tierFilter,
    required this.cellSize,
    required this.showCellSize,
    required this.onViewChanged,
    required this.onTierFilterChanged,
    required this.onCellSizeChanged,
  });

  final pb.BlockCoverageUpdate update;
  final int coveredBlocks;
  final int peerCount;

  /// The daemon has missed the heartbeat it promised, so what is shown is
  /// no longer known to be current.
  final bool stale;

  /// How long since the last update arrived. Null before the first one.
  final Duration? staleFor;
  final bool tableOnly;
  final _TrustTier? tierFilter;
  final double cellSize;
  final bool showCellSize;
  final ValueChanged<bool> onViewChanged;
  final ValueChanged<_TrustTier?> onTierFilterChanged;
  final ValueChanged<double> onCellSizeChanged;

  @override
  Widget build(BuildContext context) {
    final kwaai = context.kwaai;
    // Recomputed from the filtered counts rather than read off the wire:
    // with the trust filter on, `update.fullCoverage` would describe a
    // set of peers the user isn't looking at.
    final full = update.totalBlocks > 0 && coveredBlocks == update.totalBlocks;

    // Staleness outranks coverage in the icon. A green check on data the
    // daemon has stopped confirming is the one genuinely misleading state
    // here — it reads as "verified good right now" when the truth is
    // "unknown". The counts stay on screen, but the badge stops vouching
    // for them.
    final IconData icon;
    final Color iconColor;
    if (stale) {
      icon = Icons.cloud_off;
      iconColor = Theme.of(context).colorScheme.onSurfaceVariant;
    } else if (full) {
      icon = Icons.check_circle;
      iconColor = kwaai.semanticSuccess;
    } else {
      icon = Icons.error_outline;
      iconColor = kwaai.semanticWarning;
    }

    final summary = full
        ? 'Full model coverage — '
            '$coveredBlocks/${update.totalBlocks} blocks, '
            '$peerCount peer(s)'
        : '$coveredBlocks/${update.totalBlocks} blocks '
            'covered, $peerCount peer(s)';

    return Row(
      children: [
        Tooltip(
          message: stale
              ? 'No update from the daemon in ${describeStaleness(staleFor)} — '
                  'this may no longer be accurate'
              : 'Live',
          child: Icon(icon, size: 22, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                update.dhtPrefix,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                stale
                    ? '$summary · last seen ${describeStaleness(staleFor)} ago'
                    : summary,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: stale
                          ? kwaai.semanticWarning
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _TrustFilter(value: tierFilter, onChanged: onTierFilterChanged),
        if (showCellSize) ...[
          const SizedBox(width: 12),
          _CellSizeSlider(value: cellSize, onChanged: onCellSizeChanged),
        ],
        const SizedBox(width: 12),
        _ViewToggle(tableOnly: tableOnly, onChanged: onViewChanged),
      ],
    );
  }
}

/// Trust-tier filter. Null selects "All peers" — the default — and each
/// tier below that shows only peers at exactly that tier.
class _TrustFilter extends StatelessWidget {
  const _TrustFilter({required this.value, required this.onChanged});

  final _TrustTier? value;
  final ValueChanged<_TrustTier?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Filter peers by trust tier',
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

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.tableOnly, required this.onChanged});

  final bool tableOnly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final accent = context.kwaai.accentPrimary;
    Widget button(
        IconData icon, bool selected, VoidCallback onTap, String tooltip) {
      return Tooltip(
        message: tooltip,
        child: Material(
          color: selected ? accent.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                icon,
                size: 18,
                color: selected
                    ? accent
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(
          Icons.grid_view,
          !tableOnly,
          () => onChanged(false),
          'Grid and table',
        ),
        const SizedBox(width: 4),
        button(
          Icons.table_rows_outlined,
          tableOnly,
          () => onChanged(true),
          'Table only',
        ),
      ],
    );
  }
}

/// Compact horizontal slider controlling grid cell size, led by a grid
/// icon. Nothing brackets its right end — the view toggle's grid icon
/// sits immediately there and would read as part of the slider.
class _CellSizeSlider extends StatelessWidget {
  const _CellSizeSlider({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Tooltip(
      message: 'Block size',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 18px matches the view-toggle icons alongside it.
          Icon(Icons.grid_on, size: 18, color: muted),
          SizedBox(
            width: 108,
            child: SliderTheme(
              // Slimmed down from the default: this sits inline in a
              // header row, not in a settings form.
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: value,
                min: _minCellSize,
                max: _maxCellSize,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid over table, split by how much height the grid actually needs at
/// the current cell size rather than by a fixed fraction.
///
/// The grid lays out at (or just under) [cellSize] and takes only the
/// height that requires; the table gets the remainder, floored at
/// [_minTableHeight] so a large cell size can't squeeze it away. Once the
/// grid would need more than that remainder, it scrolls instead of
/// growing.
class _GridAndTable extends StatelessWidget {
  const _GridAndTable({
    required this.totalBlocks,
    required this.counts,
    required this.cellSize,
    required this.selectedBlock,
    required this.highlightedBlocks,
    required this.onSelectBlock,
    required this.tablePeers,
    required this.selectedPeerId,
    required this.onSelectPeer,
    required this.onClearBlock,
  });

  final int totalBlocks;
  final List<int> counts;
  final double cellSize;
  final int? selectedBlock;
  final Set<int> highlightedBlocks;
  final ValueChanged<int> onSelectBlock;
  final List<pb.BlockPeer> tablePeers;
  final String? selectedPeerId;
  final ValueChanged<String> onSelectPeer;
  final VoidCallback onClearBlock;

  static const _gridPadding = EdgeInsets.all(16);
  static const _spacing = 3.0;

  @override
  Widget build(BuildContext context) {
    if (totalBlocks == 0) {
      return const Center(child: Text('Model has no blocks to display.'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = math.max(
          constraints.maxWidth - _gridPadding.horizontal,
          1.0,
        );
        final h = math.max(constraints.maxHeight, 1.0);

        // Pack as many whole cells per row as fit at the requested size,
        // then shrink the cell slightly to divide the width exactly — so
        // the grid is always flush left-to-right.
        final cols =
            ((w + _spacing) / (cellSize + _spacing)).floor().clamp(1, totalBlocks);
        final rows = (totalBlocks / cols).ceil();
        final cell = (w - _spacing * (cols - 1)) / cols;

        final wanted = rows * cell + _spacing * (rows - 1);
        final available = math.max(h - _minTableHeight, 0.0);
        // Grid height: what it wants, capped so the table keeps its
        // floor. `h` also caps it for viewports shorter than that floor.
        final gridHeight = math.min(
          math.min(wanted, available > 0 ? available : h),
          h,
        );
        final showLabel = cell > 26;

        return Column(
          children: [
            SizedBox(
              height: gridHeight + _gridPadding.vertical,
              child: Padding(
                padding: _gridPadding,
                child: GridView.builder(
                  // Scrolls only when the cells don't fit the capped
                  // height; otherwise this is a static, fully-visible
                  // grid.
                  physics: wanted > gridHeight
                      ? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: _spacing,
                    crossAxisSpacing: _spacing,
                  ),
                  itemCount: totalBlocks,
                  itemBuilder: (context, block) => _BlockCell(
                    block: block,
                    peerCount: counts[block],
                    selected: block == selectedBlock,
                    highlighted: highlightedBlocks.contains(block),
                    peerSelected: highlightedBlocks.isNotEmpty,
                    blockSelected: selectedBlock != null,
                    showLabel: showLabel,
                    onTap: () => onSelectBlock(block),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _TableSection(
                peers: tablePeers,
                selectedBlock: selectedBlock,
                selectedPeerId: selectedPeerId,
                onSelectPeer: onSelectPeer,
                onClearBlock: onClearBlock,
                topBorder: true,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BlockCell extends StatelessWidget {
  const _BlockCell({
    required this.block,
    required this.peerCount,
    required this.selected,
    required this.highlighted,
    required this.peerSelected,
    required this.blockSelected,
    required this.showLabel,
    required this.onTap,
  });

  final int block;
  final int peerCount;
  final bool selected;

  /// Served by the peer currently selected in the table.
  final bool highlighted;

  /// Whether a peer is selected at all — the cue is contrast between
  /// highlighted and not, which only means anything once one is.
  final bool peerSelected;

  /// Whether any block is selected, for the same reason.
  final bool blockSelected;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kwaai = context.kwaai;
    final color = peerCount == 0
        ? kwaai.semanticError
        : peerCount == 1
            ? kwaai.semanticWarning
            : kwaai.semanticSuccess;

    // Both selections are shown the same way: whatever is selected stays
    // at full strength and everything else drops right back, so the
    // emphasis reads as a shape. The two are mutually exclusive — picking
    // a block clears the peer — so at most one of them is ever dimming.
    final anySelection = peerSelected || blockSelected;
    final emphasised = highlighted || selected;
    final dimmed = anySelection && !emphasised;

    return Tooltip(
      waitDuration: const Duration(milliseconds: 500),
      message: 'Block $block — $peerCount peer(s)',
      child: Material(
        color: color.withValues(
          alpha: dimmed
              ? 0.16
              : emphasised
                  ? 1.0
                  : 0.85,
        ),
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onTap,
          child: Align(
            child: showLabel
                ? Text(
                    '$block',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          // White on a near-transparent cell is
                          // unreadable — the label recedes with it.
                          color: dimmed
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// The bottom (or, in table-only mode, whole-viewport) table section: a
/// caption saying what is being listed, plus the peer table.
class _TableSection extends StatelessWidget {
  const _TableSection({
    required this.peers,
    required this.selectedBlock,
    required this.selectedPeerId,
    required this.onSelectPeer,
    required this.onClearBlock,
    this.topBorder = false,
  });

  final List<pb.BlockPeer> peers;
  final int? selectedBlock;
  final String? selectedPeerId;
  final ValueChanged<String> onSelectPeer;
  final VoidCallback onClearBlock;
  final bool topBorder;

  @override
  Widget build(BuildContext context) {
    final kwaai = context.kwaai;
    final block = selectedBlock;
    return Container(
      decoration: BoxDecoration(
        color: topBorder ? kwaai.elevatedSurface : null,
        border: topBorder
            ? Border(top: BorderSide(color: kwaai.divider))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Caption bar. Fixed height so the row doesn't grow when the
          // "Show all" button appears — the button is sized to fit this
          // bar rather than the bar sized to fit the button.
          Container(
            height: _captionBarHeight,
            decoration: BoxDecoration(
              // A step darker than the section behind it, so the caption
              // reads as a header band rather than as the table's first
              // row. Derived from the divider colour so it tracks both
              // light and dark themes.
              color: kwaai.divider.withValues(alpha: 0.28),
              border: Border(bottom: BorderSide(color: kwaai.divider)),
            ),
            padding: const EdgeInsets.only(left: 16, right: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    block == null
                        ? 'All peers — ${peers.length}'
                        : 'Block $block — ${peers.length} peer(s)',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (block != null)
                  _ShowAllButton(onPressed: onClearBlock),
              ],
            ),
          ),
          Expanded(
            child: _PeerTable(
              peers: peers,
              selectedPeerId: selectedPeerId,
              onSelectPeer: onSelectPeer,
              emptyMessage: block == null
                  ? 'No block servers found in the DHT.'
                  : 'No peers are serving this block.',
            ),
          ),
        ],
      ),
    );
  }
}

/// Clears the block filter. Deliberately not a [TextButton.icon]: that
/// carries a 36px minimum height and its own vertical padding, which
/// would force the caption bar taller the moment a block is selected.
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
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: accent, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wide peer table — the gRPC twin of the `kwaainet shard chain`
/// terminal output: START, END, PEER ID, TRUST, NAME. Clicking a row
/// selects that peer, which highlights its blocks in the grid.
class _PeerTable extends StatelessWidget {
  const _PeerTable({
    required this.peers,
    required this.selectedPeerId,
    required this.onSelectPeer,
    required this.emptyMessage,
  });

  final List<pb.BlockPeer> peers;
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
                DataColumn(
                  label: Text('START', style: headStyle),
                  numeric: true,
                ),
                DataColumn(label: Text('END', style: headStyle), numeric: true),
                DataColumn(label: Text('PEER ID', style: headStyle)),
                DataColumn(label: Text('TRUST', style: headStyle)),
                DataColumn(label: Text('NAME', style: headStyle)),
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
                      DataCell(Text('${p.startBlock}', style: cellStyle)),
                      DataCell(Text('${p.endBlock}', style: cellStyle)),
                      DataCell(Text(p.peerId, style: monoStyle)),
                      DataCell(_TrustCell(peer: p)),
                      DataCell(
                        Text(
                          p.publicName.isEmpty ? '—' : p.publicName,
                          style: cellStyle,
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

/// Trust tier label, tinted by tier, with the numeric score in a tooltip.
/// Renders "—" when the local reputation system is disabled.
///
/// The daemon's four tiers ramp UNKNOWN → KNOWN → VERIFIED → TRUSTED, so
/// the tint ramps with them: only the top tier gets the success colour,
/// and the two middle tiers stay distinguishable from it.
class _TrustCell extends StatelessWidget {
  const _TrustCell({required this.peer});

  final pb.BlockPeer peer;

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
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Number of peers serving each block index.
List<int> _peerCounts(List<pb.BlockPeer> peers, int totalBlocks) {
  final counts = List<int>.filled(totalBlocks, 0);
  for (final p in peers) {
    final start = p.startBlock.clamp(0, totalBlocks);
    final end = p.endBlock.clamp(0, totalBlocks);
    for (var b = start; b < end; b++) {
      counts[b]++;
    }
  }
  return counts;
}
