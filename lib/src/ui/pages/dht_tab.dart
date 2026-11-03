import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/generated/kwaai.pb.dart' as pb;
import '../../chat/kwaai_rpc_client.dart';
import '../../chat/session_client.dart';
import '../../daemon/daemon_state.dart';
import '../../daemon/dht_state.dart';
import '../theme/kwaai_theme.dart';
import '../widgets/service_status_view.dart';

/// Height of the table's caption bar. Fixed rather than intrinsic so the bar
/// is identical whatever it contains. Mirrors the Peers and VPK tabs.
const _captionBarHeight = 28.0;

/// What the listing is, close to `DhtRecordsRequest`'s own wording. Claims
/// completeness only when the daemon did not cut the listing short.
String localStoreNote({required bool truncated}) =>
    'These are the records this node holds. The local store is the only thing '
    'that can be enumerated — hivemind is a Kademlia DHT and Kademlia has no '
    'key-listing operation. What a node holds is whatever replication, caching '
    'and its own announces happened to land on it, so this is a true'
    '${truncated ? '' : ' and complete'} answer about this node and says '
    'nothing about the network’s key space.';

/// The daemon's p2p node has not started yet: UNAVAILABLE now, UNIMPLEMENTED
/// from earlier builds of `dht_records`. Transient, so the tab retries.
bool isNodeStarting(Object? error) =>
    error is SessionOpError &&
    (error.code == pb.Error_Code.UNAVAILABLE.value ||
        error.code == pb.Error_Code.UNIMPLEMENTED.value);

/// A daemon predating `dht_records` decodes the frame with no body. Matched on
/// the exact message: the code alone is also its reply to any malformed frame.
bool isDaemonTooOld(Object? error) =>
    error is SessionOpError &&
    error.code == pb.Error_Code.INVALID_ARGUMENT.value &&
    error.message == 'ClientFrame missing body';

/// Backoff between automatic retries while the node starts: 2s, 4s, 8s, then
/// every 15s.
Duration startingRetryDelay(int attempt) =>
    Duration(seconds: math.min(2 << math.min(attempt, 3), 15));

/// Settings tab for `dht_records`: a header, one table, and a detail panel.
/// The listing is one-shot; values are fetched per row.
class DhtTab extends ConsumerStatefulWidget {
  const DhtTab({super.key});

  @override
  ConsumerState<DhtTab> createState() => _DhtTabState();
}

class _DhtTabState extends ConsumerState<DhtTab> {
  /// Row currently expanded, as [recordSelectionKey]. Null = none.
  String? _selected;

  /// The selected record re-fetched with its values, and the state of that
  /// fetch. Separate from the listing's copy, which is metadata only.
  pb.DhtRecord? _detail;
  Object? _detailError;
  bool _detailLoading = false;

  /// Last listing we rendered. Held across a refresh so the table does not
  /// blank out while the new one is in flight.
  pb.DhtRecordsReply? _last;

  /// When [_last] arrived, for the stale banner.
  DateTime? _lastArrived;

  /// Pending automatic retry while the p2p node starts, and how many have run.
  Timer? _retryTimer;
  int _retryAttempt = 0;

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(dhtRecordsProvider, (_, next) {
      if (next.isLoading) return;
      if (next.hasError && isNodeStarting(next.error)) {
        _retryTimer?.cancel();
        _retryTimer = Timer(startingRetryDelay(_retryAttempt++), _retry);
      } else if (!next.hasError) {
        _retryAttempt = 0;
      }
    });
    final listing = ref.watch(dhtRecordsProvider);
    final fresh = listing.valueOrNull;
    if (fresh != null && !identical(fresh, _last)) {
      _last = fresh;
      _lastArrived = DateTime.now();
    }
    final reply = _last;

    if (reply == null) {
      final err = listing.error;
      if (err != null) {
        final starting = isNodeStarting(err);
        return ServiceStatusView(
          headline: starting
              ? 'The p2p node is still starting'
              : 'DHT records are not available',
          spinner: starting,
          subtitle: _UnavailableDetail(
            error: err,
            onRetry: listing.isLoading ? null : _retry,
          ),
        );
      }

      // Reachability, not the local PID: with KWAAINET_GRPC_PORT set the
      // daemon runs elsewhere and has no PID on this machine.
      final running = ref.watch(daemonAvailableProvider);
      return ServiceStatusView(
        headline: running
            ? 'Reading the local DHT store…'
            : unavailableHeadline(),
        spinner: running,
        subtitle: running ? null : Text(unavailableHint('see DHT records')),
      );
    }

    final divider = Divider(height: 1, color: context.kwaai.divider);
    final connected =
        ref.watch(kwaaiRpcConnectionProvider).valueOrNull ==
        RpcConnection.connected;
    // A refresh that failed, or a daemon that went away, must not leave the
    // old rows reading as current.
    final stale = !connected || listing.hasError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _LocalHeader(
                  shown: reply.records.length,
                  total: reply.totalRecords,
                  summary: _summary(reply),
                  truncated: reply.totalRecords > reply.records.length,
                ),
              ),
              const SizedBox(width: 12),
              // Gated on the connection too: while the daemon is away the
              // provider sits loading, and "unreachable" is the real reason.
              _RefreshButton(
                onPressed: connected && !listing.isLoading
                    ? _refreshLocal
                    : null,
              ),
            ],
          ),
        ),
        if (stale)
          _StaleBanner(
            arrived: _lastArrived,
            error: connected ? listing.error : null,
          ),
        divider,
        Expanded(child: _localBand(reply)),
        ..._detailBand(reply, divider),
      ],
    );
  }

  Widget _localBand(pb.DhtRecordsReply reply) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Caption(
          title: 'LOCAL RECORDS',
          detail: reply.serverTime.isEmpty
              ? null
              : 'Daemon time ${reply.serverTime}',
        ),
        Expanded(
          child: reply.records.isEmpty
              ? const _EmptyRow(
                  text: 'This node holds no DHT records right now.',
                )
              : _RecordTable(
                  records: reply.records,
                  selected: _selected,
                  onSelect: _select,
                ),
        ),
      ],
    );
  }

  /// The detail panel for the selected record.
  List<Widget> _detailBand(pb.DhtRecordsReply reply, Widget divider) {
    final selected = _selected;
    if (selected == null) return const [];
    final panel = _RecordDetail(
      summary: reply.records.firstWhere(
        (r) => recordSelectionKey(r) == selected,
        orElse: pb.DhtRecord.new,
      ),
      detail: _detail,
      loading: _detailLoading,
      error: _detailError,
      onClose: () => setState(_clearSelection),
    );
    return [
      divider,
      // Bounded and scrollable: a dictionary with one subkey per serving
      // peer is long, and the detail must not push the table off screen.
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: SingleChildScrollView(child: panel),
      ),
    ];
  }

  String _summary(pb.DhtRecordsReply reply) {
    final records = reply.records;
    final cached = records.where((r) => r.inCache).length;
    final dicts = records
        .where((r) => r.kind == pb.DhtRecordKind.DHT_RECORD_KIND_DICTIONARY)
        .length;
    final count = reply.totalRecords > records.length
        ? '${records.length} of ${reply.totalRecords} records'
        : '${records.length} records';
    return '$count · $dicts dictionaries · $cached cached';
  }

  void _clearSelection() {
    _selected = null;
    _detail = null;
    _detailError = null;
    _detailLoading = false;
  }

  void _refreshLocal() {
    setState(_clearSelection);
    _retry();
  }

  void _retry() {
    _retryTimer?.cancel();
    if (mounted) ref.invalidate(dhtRecordsProvider);
  }

  /// Expand a row, fetching its values — scoped to this key *and* tier, since
  /// a key held in both store and cache comes back twice.
  Future<void> _select(pb.DhtRecord record) async {
    final key = recordSelectionKey(record);
    if (_selected == key) {
      setState(_clearSelection);
      return;
    }
    setState(() {
      _selected = key;
      _detail = null;
      _detailError = null;
      _detailLoading = true;
    });
    try {
      final reply = await ref
          .read(kwaaiRpcClientProvider)
          .dhtRecords(includeValues: true, keyIds: [record.keyId]);
      if (!mounted || _selected != key) return;
      setState(() {
        _detail = reply.records
            .where((r) => recordSelectionKey(r) == key)
            .firstOrNull;
        _detailLoading = false;
      });
    } catch (e) {
      if (!mounted || _selected != key) return;
      setState(() {
        _detailError = e;
        _detailLoading = false;
      });
    }
  }
}

/// Row identity. The tier is part of it: a key held in both store and cache
/// is two records, not a duplicate.
String recordSelectionKey(pb.DhtRecord r) =>
    '${r.keyId}:${r.inCache ? 'cache' : 'primary'}';

/// The plaintext name when this node can derive one, else a shortened id —
/// an id is a hash and cannot be inverted, so unnamed is the normal case.
String recordLabel(pb.DhtRecord r) =>
    r.keyName.isNotEmpty ? r.keyName : shortKeyId(r.keyId);

String shortKeyId(String keyId) =>
    keyId.length <= 16 ? keyId : '${keyId.substring(0, 16)}…';

/// A subkey as a label. It is rendered like a value, so a peer id arrives as
/// a quoted JSON string; the quotes are not part of the name.
String subkeyLabel(String rendered) {
  try {
    final v = jsonDecode(rendered);
    if (v is String) return v;
  } on FormatException {
    // Not JSON: an older daemon, or a subkey that is not a string.
  }
  return rendered;
}

/// A countdown from `expires_in_secs`. Negative only for a subkey: the listing
/// filters expired records, but dictionaries keep expired subkeys.
String formatExpiry(double secs) {
  final rounded = secs.round();
  final magnitude = _magnitude(rounded.abs());
  return rounded < 0 ? 'expired $magnitude ago' : 'in $magnitude';
}

/// The expiry as a sentence: "Expires in 4m" or "Expired 1m ago".
String expiryLine(double secs) {
  final countdown = formatExpiry(secs);
  return secs.round() < 0
      ? '${countdown[0].toUpperCase()}${countdown.substring(1)}'
      : 'Expires $countdown';
}

String _magnitude(int secs) {
  if (secs < 60) return '${secs}s';
  if (secs < 3600) return '${secs ~/ 60}m';
  if (secs < 86400) return '${secs ~/ 3600}h';
  return '${secs ~/ 86400}d';
}

/// Value size, from `value_bytes` — stored bytes, not the wire size.
String formatValueBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String kindLabel(pb.DhtRecordKind kind) => switch (kind) {
  pb.DhtRecordKind.DHT_RECORD_KIND_DICTIONARY => 'dictionary',
  pb.DhtRecordKind.DHT_RECORD_KIND_REGULAR => 'value',
  _ => 'unknown',
};

/// An absolute expiration, local time. Shown beside the countdown because the
/// daemon's clock is not necessarily this machine's.
String formatEpoch(double epochSecs) {
  final t = DateTime.fromMillisecondsSinceEpoch((epochSecs * 1000).round())
      .toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} '
      '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

/// Re-requests the listing. Disabled while one is in flight or the daemon is
/// unreachable.
class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.refresh, size: 18),
      iconSize: 18,
      visualDensity: VisualDensity.compact,
      tooltip: 'Refresh',
      onPressed: onPressed,
    );
  }
}

/// The header: what the listing is, how much of it is shown, and the summary.
/// The note is not collapsible — it is the one thing about this view a reader
/// can most easily get wrong.
class _LocalHeader extends StatelessWidget {
  const _LocalHeader({
    required this.shown,
    required this.total,
    required this.summary,
    required this.truncated,
  });

  final bool truncated;

  final int shown;

  /// `total_records` — what matched before the daemon's limit was applied.
  final int total;

  final String summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 14,
              color: context.kwaai.semanticInfo,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'This node’s own store',
                style: theme.textTheme.labelLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(localStoreNote(truncated: truncated), style: muted),
        const SizedBox(height: 6),
        // A cut-short listing that reads as a whole one is the same failure
        // as implying the local store is the network.
        if (truncated)
          Row(
            children: [
              Icon(
                Icons.warning_amber_outlined,
                size: 14,
                color: context.kwaai.semanticWarning,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Showing $shown of $total records — the listing was '
                  'cut short at the daemon’s limit.',
                  style: muted?.copyWith(color: context.kwaai.semanticWarning),
                ),
              ),
            ],
          ),
        Text(summary, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// The record table. One row per stored record — including both copies of a
/// key held in the primary store and the cache.
class _RecordTable extends StatelessWidget {
  const _RecordTable({
    required this.records,
    required this.selected,
    required this.onSelect,
  });

  final List<pb.DhtRecord> records;
  final String? selected;
  final ValueChanged<pb.DhtRecord> onSelect;

  @override
  Widget build(BuildContext context) {
    final kwaai = context.kwaai;
    final theme = Theme.of(context);
    final headStyle = theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.6);
    final cellStyle = theme.textTheme.bodySmall;
    final monoStyle = _mono(context, cellStyle);
    final selectedFill = kwaai.accentPrimary.withValues(alpha: 0.16);

    // Vertical scroll outside, horizontal inside — the nesting the Peers and
    // VPK tables use, which is what gives the DataTable a bounded height to
    // lay out against.
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
                DataColumn(label: Text('KEY', style: headStyle)),
                DataColumn(label: Text('KIND', style: headStyle)),
                DataColumn(label: Text('TIER', style: headStyle)),
                DataColumn(
                  label: Text('SUBKEYS', style: headStyle),
                  numeric: true,
                ),
                DataColumn(
                  label: Text('SIZE', style: headStyle),
                  numeric: true,
                ),
                DataColumn(label: Text('EXPIRES', style: headStyle)),
              ],
              rows: [
                for (final r in records)
                  DataRow(
                    key: ValueKey(recordSelectionKey(r)),
                    selected: recordSelectionKey(r) == selected,
                    color: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? selectedFill
                          : null,
                    ),
                    onSelectChanged: (_) => onSelect(r),
                    cells: [
                      DataCell(
                        Text(
                          recordLabel(r),
                          style: r.keyName.isEmpty ? monoStyle : cellStyle,
                        ),
                      ),
                      DataCell(Text(kindLabel(r.kind), style: cellStyle)),
                      DataCell(_TierChip(inCache: r.inCache)),
                      DataCell(
                        Text(
                          // Meaningless for a regular value, which is why
                          // `kind` and not this column says what a record is.
                          // Counts expired subkeys too; nothing prunes them.
                          r.kind == pb.DhtRecordKind.DHT_RECORD_KIND_DICTIONARY
                              ? '${r.subkeyCount}'
                              : '—',
                          style: cellStyle,
                        ),
                      ),
                      DataCell(
                        Text(
                          formatValueBytes(r.valueBytes.toInt()),
                          style: cellStyle,
                        ),
                      ),
                      DataCell(
                        // Never negative: the listing filters expired records.
                        Text(formatExpiry(r.expiresInSecs), style: cellStyle),
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

/// Primary store vs cache. A cached record is here because another node's
/// `get` passed through this one, not because anyone chose to replicate onto it.
class _TierChip extends StatelessWidget {
  const _TierChip({required this.inCache});

  final bool inCache;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = inCache ? theme.colorScheme.onSurfaceVariant : null;
    return Text(
      inCache ? 'cache' : 'primary',
      style: theme.textTheme.bodySmall?.copyWith(color: color),
    );
  }
}

/// Everything known about the selected record, with the values fetched for
/// this row alone.
class _RecordDetail extends StatelessWidget {
  const _RecordDetail({
    required this.summary,
    required this.detail,
    required this.loading,
    required this.error,
    required this.onClose,
  });

  /// The listing's metadata for the row, shown while the value request is
  /// still in flight so the panel is never empty.
  final pb.DhtRecord summary;
  final pb.DhtRecord? detail;
  final bool loading;
  final Object? error;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75),
    );
    final record = detail ?? summary;
    final isDict = record.kind == pb.DhtRecordKind.DHT_RECORD_KIND_DICTIONARY;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  recordLabel(record),
                  style: theme.textTheme.labelLarge,
                ),
              ),
              _CopyButton(text: record.keyId, label: 'Key id'),
              _CloseButton(onPressed: onClose),
            ],
          ),
          Text(record.keyId, style: _mono(context, muted)),
          const SizedBox(height: 8),
          _RecordFacts(record: record),
          const SizedBox(height: 8),
          if (!loading && error == null && detail?.valuesTruncated == true) ...[
            _WarningLine(
              text: isDict
                  ? 'Values incomplete — showing ${detail!.subkeys.length} of '
                        '${detail!.subkeyCount} subkeys; the rest did not fit '
                        'in one reply.'
                  : 'Value withheld — it did not fit in this reply.',
            ),
            const SizedBox(height: 6),
          ],
          if (loading)
            Row(
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text('Fetching the stored value…', style: muted),
              ],
            )
          else if (error != null)
            Text('Could not read the value: ${_errorText(error)}', style: muted)
          else if (detail == null)
            Text('This record is no longer in the store.', style: muted)
          // A dictionary carries no top-level value — its values live per
          // subkey, which is how N peers announce under one key.
          else if (isDict)
            _SubkeyList(
              title: recordLabel(record),
              subkeyCount: detail!.subkeyCount,
              subkeys: detail!.subkeys,
              truncated: detail!.valuesTruncated,
            )
          else if (detail!.hasValue())
            _ValueView(title: recordLabel(record), value: detail!.value)
          // The warning above already says why; claim nothing further.
          else if (detail!.valuesTruncated)
            const SizedBox.shrink()
          else
            Text('The daemon returned no value for this record.', style: muted),
        ],
      ),
    );
  }
}

/// The record's metadata line: tier, kind, size and both expirations.
class _RecordFacts extends StatelessWidget {
  const _RecordFacts({required this.record});

  final pb.DhtRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75),
    );
    final r = record;
    final isDict = r.kind == pb.DhtRecordKind.DHT_RECORD_KIND_DICTIONARY;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${kindLabel(r.kind)} · ${r.inCache ? 'cache' : 'primary'}'
          ' · ${formatValueBytes(r.valueBytes.toInt())}'
          '${isDict ? ' · ${r.subkeyCount} subkeys' : ''}'
          '${r.hasDictMaxsize() ? ' of at most ${r.dictMaxsize}' : ''}',
          style: muted,
        ),
        Text(
          '${expiryLine(r.expiresInSecs)} (${formatEpoch(r.expiration)})',
          style: muted,
        ),
        // Hivemind never recomputes this on subkey expiry, so a value well
        // past the record's own expiration is normal rather than a fault.
        if (r.hasLatestExpiration())
          Text(
            'Latest subkey expiration ever stored '
            '${formatEpoch(r.latestExpiration)}',
            style: muted,
          ),
      ],
    );
  }
}

/// A dictionary's subkeys, each with its own expiration. Expired ones are
/// listed too — nothing prunes them.
class _SubkeyList extends StatelessWidget {
  const _SubkeyList({
    required this.title,
    required this.subkeyCount,
    required this.subkeys,
    required this.truncated,
  });

  /// The record's label, which each subkey's viewer titles itself with.
  final String title;
  final int subkeyCount;
  final List<pb.DhtSubkey> subkeys;

  /// The daemon withheld the subkeys past [subkeys]: a prefix, not the whole.
  final bool truncated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75),
    );
    if (subkeys.isEmpty) {
      return Text(
        subkeyCount > 0 || truncated
            ? 'This answer did not include its $subkeyCount subkey values.'
            : 'This dictionary holds no subkeys.',
        style: muted,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in subkeys) ...[
          Text(
            '${subkeyLabel(s.subkey)} · ${formatExpiry(s.expiresInSecs)} · '
            '${formatValueBytes(s.valueBytes.toInt())}',
            style: _mono(context, muted),
          ),
          const SizedBox(height: 2),
          _ValueView(
            title: '$title · ${subkeyLabel(s.subkey)}',
            value: s.value,
          ),
          const SizedBox(height: 8),
        ],
        if (truncated)
          Text(
            '${subkeyCount - subkeys.length} more not included in this reply.',
            style: muted,
          ),
      ],
    );
  }
}

/// A rendered msgpack value: structural, not semantic, so shown preformatted;
/// undecodable bytes are labelled opaque, not dressed up.
class _ValueView extends StatelessWidget {
  const _ValueView({required this.title, required this.value});

  /// What the full-size viewer is titled — the record, plus the subkey.
  final String title;
  final pb.DhtValueView value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kwaai = context.kwaai;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75),
    );
    final ext = value.hasExtCode() ? ' (ext ${value.extCode})' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'msgpack ${value.msgpackType}$ext · '
              '${formatValueBytes(value.rawBytes.toInt())} stored',
              style: muted,
            ),
            if (!value.decoded) ...[
              const SizedBox(width: 8),
              Icon(Icons.help_outline, size: 13, color: kwaai.semanticWarning),
              const SizedBox(width: 4),
              Text(
                'opaque — shown as hex',
                style: muted?.copyWith(color: kwaai.semanticWarning),
              ),
            ],
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.open_in_full, size: 13),
              iconSize: 13,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              tooltip: 'Open value',
              onPressed: () => showValueDialog(context, title, value),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: kwaai.inputBackground,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: kwaai.divider),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              previewOf(value.rendered),
              style: _mono(context, theme.textTheme.bodySmall),
              softWrap: false,
            ),
          ),
        ),
        if (value.rendered.length > kValuePreviewChars)
          Text(
            'Preview of ${value.rendered.length} characters — open to read '
            'it all.',
            style: muted,
          ),
      ],
    );
  }
}

/// How much of a rendered value the inline preview lays out. Values run to a
/// megabyte, and laying that out unwrapped is seconds of jank per selection.
const kValuePreviewChars = 2048;

String previewOf(String rendered, [int limit = kValuePreviewChars]) =>
    rendered.length <= limit ? rendered : '${rendered.substring(0, limit)}…';

/// Full-size viewer for a rendered value: the whole `rendered` string,
/// word-wrapped in a squarish box, with the same type / size / not-decoded
/// facts the inline preview shows so the dialog claims no more than it does.
Future<void> showValueDialog(
  BuildContext context,
  String title,
  pb.DhtValueView value,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => _ValueDialog(title: title, value: value),
  );
}

/// `rendered` pretty-printed, or null when it is not JSON. Only for a decoded
/// value — an undecoded one is raw hex and must never be parsed.
String? prettyJson(pb.DhtValueView value) {
  if (!value.decoded) return null;
  try {
    return const JsonEncoder.withIndent('  ')
        .convert(jsonDecode(value.rendered));
  } on FormatException {
    return null;
  }
}

class _ValueDialog extends StatefulWidget {
  const _ValueDialog({required this.title, required this.value});

  final String title;
  final pb.DhtValueView value;

  @override
  State<_ValueDialog> createState() => _ValueDialogState();
}

class _ValueDialogState extends State<_ValueDialog> {
  late final String? _pretty = prettyJson(widget.value);
  bool _raw = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kwaai = context.kwaai;
    final value = widget.value;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75),
    );
    final size = MediaQuery.sizeOf(context);
    // Squarish: the shorter viewport side bounds both axes.
    final side = 0.8 * (size.width < size.height ? size.width : size.height);
    final ext = value.hasExtCode() ? ' (ext ${value.extCode})' : '';
    final pretty = _pretty;
    final shown = pretty == null || _raw ? value.rendered : pretty;

    return Dialog(
      backgroundColor: kwaai.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: kwaai.divider),
      ),
      child: SizedBox(
        width: side,
        height: side,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (pretty != null) ...[
                    _RawToggle(
                      raw: _raw,
                      onChanged: (v) => setState(() => _raw = v),
                    ),
                    const SizedBox(width: 4),
                  ],
                  _CopyButton(text: shown, label: 'Value'),
                  _CloseButton(onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              Text(
                'msgpack ${value.msgpackType}$ext · '
                '${formatValueBytes(value.rawBytes.toInt())} stored'
                '${value.decoded ? '' : ' · not decoded, shown as hex'}',
                style: value.decoded
                    ? muted
                    : muted?.copyWith(color: kwaai.semanticWarning),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kwaai.inputBackground,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: kwaai.divider),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      shown,
                      style: _mono(context, theme.textTheme.bodySmall),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pretty / Raw switch for a value that parsed as JSON.
class _RawToggle extends StatelessWidget {
  const _RawToggle({required this.raw, required this.onChanged});

  final bool raw;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return SegmentedButton<bool>(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? context.kwaai.accentPrimary
              : onSurface.withValues(alpha: 0.12),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : onSurface.withValues(alpha: 0.6),
        ),
        side: const WidgetStatePropertyAll(BorderSide.none),
        visualDensity: VisualDensity.compact,
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        ),
        textStyle: WidgetStatePropertyAll(
          Theme.of(context).textTheme.labelSmall,
        ),
      ),
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: false, label: Text('Pretty')),
        ButtonSegment(value: true, label: Text('Raw')),
      ],
      selected: {raw},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// A one-line warning in the header's style.
class _WarningLine extends StatelessWidget {
  const _WarningLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warning = context.kwaai.semanticWarning;
    return Row(
      children: [
        Icon(Icons.warning_amber_outlined, size: 14, color: warning),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: warning),
          ),
        ),
      ],
    );
  }
}

/// Says the rows on screen are a snapshot the daemon can no longer vouch
/// for, and why.
class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.arrived, required this.error});

  final DateTime? arrived;

  /// The failed refresh, when the daemon is reachable but answered badly.
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kwaai = context.kwaai;
    final since = arrived == null
        ? ''
        : ' from ${_magnitude(DateTime.now().difference(arrived!).inSeconds)} '
              'ago';
    final why = error == null
        ? 'The daemon is unreachable'
        : 'The last refresh failed: ${_errorText(error)}';
    return Container(
      color: kwaai.semanticWarning.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_outlined,
            size: 14,
            color: kwaai.semanticWarning,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$why — showing the listing$since. It may no longer match the '
              'store.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: kwaai.semanticWarning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Secondary detail under the unavailable headline: what went wrong in words
/// the user can act on, and a way to try again.
class _UnavailableDetail extends StatelessWidget {
  const _UnavailableDetail({required this.error, required this.onRetry});

  final Object error;

  /// Null while a retry is in flight.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
    );
    final starting = isNodeStarting(error);
    final text = starting
        ? 'Its DHT store is not up yet. Retrying automatically.'
        : _errorText(error);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            '${text[0].toUpperCase()}${text.substring(1)}',
            style: muted,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: onRetry,
          child: Text(starting ? 'Retry now' : 'Retry'),
        ),
      ],
    );
  }
}

String _errorText(Object? error) => switch (error) {
  _ when isNodeStarting(error) => 'the p2p node is still starting',
  _ when isDaemonTooOld(error) =>
    'this daemon is too old to list DHT records — update kwaainet',
  SessionOpError e => e.message,
  null => 'unknown error',
  _ => error.toString(),
};

TextStyle? _mono(BuildContext context, TextStyle? base) => base?.copyWith(
  fontFamily: 'Menlo',
  fontFamilyFallback: const ['Consolas', 'monospace'],
);

/// Copies a value to the clipboard. Same trade as the Peers tab: a button
/// costs one build, selectable text costs a text-editing pipeline per line.
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

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.close, size: 14),
      iconSize: 14,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      tooltip: 'Close',
      onPressed: onPressed,
    );
  }
}

/// Caption bar over the table. Mirrors the Peers tab's.
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
