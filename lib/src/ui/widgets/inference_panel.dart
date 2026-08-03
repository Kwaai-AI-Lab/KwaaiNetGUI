import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/generated/kwaai.pb.dart' as pb;
import '../../chat/inference_events_state.dart';
import '../../chat/inference_log_rows.dart';
import '../theme/kwaai_theme.dart';
import 'kwaai_heading.dart';

/// Width of the panel.
///
/// Fixed rather than draggable: there is no splitter primitive in the app
/// yet, and one would need a persisted width, a drag affordance and
/// clamping to earn its place. This fits an elided peer id, a block range
/// and a duration on one line without wrapping.
const kInferencePanelWidth = 340.0;

/// How long a run may produce nothing before we conclude the daemon does
/// not know how to send events at all.
///
/// An old daemon ignores the unknown request field silently, so absence
/// over time is the only signal there is. The first event is emitted
/// before any network I/O, so a healthy daemon beats this comfortably.
const _oldDaemonGrace = Duration(seconds: 8);

/// Live view of how the current distributed answer is being produced.
///
/// Two registers, because a reader has two questions: the chain shows
/// *where the run is now*, the log shows *what just happened*. Either
/// alone loses one of them — a log makes the current position something
/// you have to reconstruct, and a chain hides the transient failures and
/// retries that are usually the reason you opened the panel.
class InferencePanel extends ConsumerStatefulWidget {
  const InferencePanel({super.key});

  @override
  ConsumerState<InferencePanel> createState() => _InferencePanelState();
}

class _InferencePanelState extends ConsumerState<InferencePanel> {
  final _scroll = ScrollController();

  /// Whether to keep pinning the log to the newest entry. Cleared when the
  /// user scrolls up — otherwise reading a past failure is impossible,
  /// since the next event yanks the viewport back down.
  bool _follow = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    const epsilon = 24.0;
    final atBottom =
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - epsilon;
    if (atBottom != _follow) setState(() => _follow = atBottom);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    final log = ref.watch(inferenceEventsProvider);

    // Follow the tail after the frame that added the row, so the extent is
    // the post-layout one.
    if (_follow) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    }

    return Container(
      width: kInferencePanelWidth,
      color: context.kwaai.cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(log: log),
          if (log.chain.isNotEmpty) _ChainView(log: log),
          const Divider(height: 1),
          Expanded(child: _EventLog(log: log, controller: _scroll)),
          if (!_follow)
            _JumpToLatest(
              onTap: () {
                setState(() => _follow = true);
                _scrollToEnd();
              },
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.log});

  final InferenceRunLog log;

  @override
  Widget build(BuildContext context) {
    final dim = Theme.of(context).colorScheme.onSurfaceVariant;
    final subtitle = log.model.isEmpty
        ? null
        : '${log.model}${log.totalBlocks > 0 ? ' · ${log.totalBlocks} blocks' : ''}';

    return Container(
      color: context.kwaai.elevatedSurface,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: KwaaiHeading('Inference')),
              if (log.running)
                SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: context.kwaai.accentPrimary,
                  ),
                ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: dim),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// The pinned route, one row per hop.
class _ChainView extends StatelessWidget {
  const _ChainView({required this.log});

  final InferenceRunLog log;

  @override
  Widget build(BuildContext context) {
    final dim = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'CHAIN · ${log.chain.length} hop${log.chain.length == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: dim,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          for (final hop in log.chain)
            _HopRow(
              hop: hop,
              status: log.hopStatus[hop.blockStart] ?? HopStatus.pending,
              ms: log.hopMs[hop.blockStart],
            ),
        ],
      ),
    );
  }
}

class _HopRow extends StatelessWidget {
  const _HopRow({required this.hop, required this.status, this.ms});

  final InferenceHopView hop;
  final HopStatus status;
  final double? ms;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dim = theme.colorScheme.onSurfaceVariant;
    final mono = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      fontSize: 11,
      color: dim,
    );

    // "you" reads faster than this node's own peer id, and which blocks we
    // serve ourselves is one of the first things you look for.
    final label = hop.isSelf
        ? 'you (local)'
        : (hop.peerName.isEmpty ? shortPeerId(hop.peerId) : hop.peerName);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _StatusDot(status: status),
          const SizedBox(width: 6),
          SizedBox(
            width: 52,
            child: Text(
              '${hop.blockStart}–${hop.blockEnd}',
              style: mono,
            ),
          ),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: hop.isSelf ? context.kwaai.accentPrimary : null,
              ),
            ),
          ),
          if (ms != null)
            Text('${ms!.round()}ms', style: mono)
          else if (status == HopStatus.inFlight)
            Text('…', style: mono),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final HopStatus status;

  @override
  Widget build(BuildContext context) {
    final k = context.kwaai;
    final color = switch (status) {
      HopStatus.pending => Theme.of(context).colorScheme.onSurfaceVariant
          .withValues(alpha: 0.35),
      HopStatus.inFlight => k.accentPrimary,
      HopStatus.ok => k.semanticSuccess,
      HopStatus.failed => k.semanticError,
    };
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Chronological event log.
class _EventLog extends StatelessWidget {
  const _EventLog({required this.log, required this.controller});

  final InferenceRunLog log;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    if (log.events.isEmpty) return _EmptyState(log: log);

    // Collapsed on the way to the screen rather than on the way in, so the
    // raw stream stays intact for anything else that wants it and a row
    // can still be revised in place when its answer arrives.
    final rows = collapseEvents(log.events);

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.symmetric(vertical: 6),
      // Rows are single-line and uniform, so a fixed extent lets the list
      // stay cheap at the full event cap without measuring each child.
      itemExtent: 20,
      itemCount: rows.length,
      itemBuilder: (context, i) => _LogRowView(row: rows[i]),
    );
  }
}

class _LogRowView extends StatelessWidget {
  const _LogRowView({required this.row});

  final LogRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dim = theme.colorScheme.onSurfaceVariant;
    final k = context.kwaai;

    // A pending row is deliberately *not* coloured: it has not succeeded or
    // failed yet, and colouring it would make an in-flight hop look like an
    // outcome. Transient failures stay amber because the run recovers from
    // them — only a terminal one is red.
    final color = switch (row.outcome) {
      RowOutcome.pending => null,
      RowOutcome.ok => null,
      RowOutcome.failed => row.failure == pb.HopFailure.HOP_FAILURE_TRANSIENT
          ? k.semanticWarning
          : k.semanticError,
    };

    final mono = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      fontSize: 11,
      color: color ?? dim,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(_elapsed(row.elapsedMs), style: mono?.copyWith(color: dim)),
          ),
          SizedBox(
            width: 58,
            child: Text(
              row.label.isEmpty ? '' : '${row.label} ${_glyph(row.outcome)}',
              style: mono,
            ),
          ),
          if (row.prefix.isNotEmpty) ...[
            SizedBox(
              width: 46,
              child: Text(
                row.prefix,
                style: mono?.copyWith(color: dim),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          Expanded(
            child: Text(
              row.detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mono?.copyWith(
                color: color ?? (row.isSelf ? k.accentPrimary : dim),
              ),
            ),
          ),
          if (row.trailing.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(row.trailing, style: mono),
          ],
        ],
      ),
    );
  }
}

/// The outcome marker: a request still awaiting its answer, or the answer.
String _glyph(RowOutcome outcome) => switch (outcome) {
  RowOutcome.pending => '→',
  RowOutcome.ok => '✓',
  RowOutcome.failed => '✗',
};

/// What to show when a run has produced no rows.
///
/// Stateful because one of the three cases is reached by the *passage of
/// time* rather than by an event: an old daemon sends nothing at all, so
/// nothing would otherwise prompt a rebuild and the "too old" message
/// would never appear. A timer supplies the missing tick.
class _EmptyState extends StatefulWidget {
  const _EmptyState({required this.log});

  final InferenceRunLog log;

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState> {
  Timer? _graceTimer;

  /// Set when the grace period for the current run has elapsed.
  ///
  /// Held as state set *by the timer* rather than recomputed from
  /// wall-clock on each build. The two are equivalent in production but
  /// not under a widget test, where the pump clock advances and
  /// `DateTime.now()` does not — and a check that cannot be tested is one
  /// that quietly stops working.
  bool _graceElapsed = false;

  @override
  void initState() {
    super.initState();
    _armGraceTimer();
  }

  @override
  void didUpdateWidget(_EmptyState oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.log.startedAt != widget.log.startedAt) _armGraceTimer();
  }

  /// Wake up once when the grace period for this run expires.
  void _armGraceTimer() {
    _graceTimer?.cancel();
    _graceTimer = null;
    _graceElapsed = false;
    if (widget.log.startedAt == null) return;
    _graceTimer = Timer(_oldDaemonGrace, () {
      if (mounted) setState(() => _graceElapsed = true);
    });
  }

  @override
  void dispose() {
    _graceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final dim = Theme.of(context).colorScheme.onSurfaceVariant;
    // Three states that all present as "no rows", and mean very different
    // things — see [_oldDaemonGrace].
    final waitedOut = _graceElapsed;

    final String message;
    if (!log.running && !log.sawAnyEvent) {
      message = 'Send a message to see how it is routed.';
    } else if (log.running && !log.sawAnyEvent && waitedOut) {
      message =
          'This daemon does not report inference events.\n'
          'Update it to see block-level routing.';
    } else {
      message = 'Waiting for the daemon…';
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: dim),
      ),
    );
  }
}

class _JumpToLatest extends StatelessWidget {
  const _JumpToLatest({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        color: context.kwaai.elevatedSurface,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          'Jump to latest ↓',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: context.kwaai.accentPrimary,
          ),
        ),
      ),
    );
  }
}

String _elapsed(int ms) {
  if (ms < 1000) return '${ms}ms';
  return '${(ms / 1000).toStringAsFixed(1)}s';
}
