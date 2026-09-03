import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/generated/kwaai.pb.dart' as pb;
import '../../chat/kwaai_rpc_client.dart';
import '../../chat/session_client.dart';
import '../../daemon/daemon_state.dart';
import '../../daemon/dht_state.dart';
import '../theme/kwaai_theme.dart';
import '../widgets/kwaai_button.dart';
import '../widgets/kwaai_dropdown.dart';
import '../widgets/kwaai_text_field.dart';
import '../widgets/service_status_view.dart';

/// Height of the table's caption bar. Fixed rather than intrinsic so the bar
/// is identical whatever it contains. Mirrors the Peers and VPK tabs.
const _captionBarHeight = 28.0;

/// What the listing is, in the proto's own words.
///
/// Kept close to the wording of `DhtRecordsRequest` in kwaai.proto rather than
/// paraphrased: a table of DHT keys invites the reading that it is the
/// network's key space, and nothing else on this page contradicts that.
const _localStoreNote =
    'These are the records this node holds. The local store is the only thing '
    'that can be enumerated — hivemind is a Kademlia DHT and Kademlia has no '
    'key-listing operation. What a node holds is whatever replication, caching '
    'and its own announces happened to land on it, so this is a true and '
    'complete answer about this node and says nothing about the network’s '
    'key space. To reach elsewhere, look up a key by name.';

/// `Error.Code.UNIMPLEMENTED` from kwaai.proto — the Go p2p path, which has no
/// hivemind store to enumerate.
const _unimplemented = 6;

/// Settings tab listing this node's hivemind DHT records and resolving a named
/// key across the network — the two halves of `dht_records` / `dht_lookup`.
///
/// Both are one-shot: the listing is fetched when the tab opens and on demand
/// thereafter, and no subscription is held. Values are deliberately not part
/// of the listing (they are the expensive half of the request) — selecting a
/// row re-requests that one record with `include_values`.
///
/// Requires the daemon to be running the native p2p stack; the Go p2p daemon
/// answers both operations UNIMPLEMENTED, which the page reports as an
/// unavailable view rather than an error.
class DhtTab extends ConsumerStatefulWidget {
  const DhtTab({super.key});

  @override
  ConsumerState<DhtTab> createState() => _DhtTabState();
}

class _DhtTabState extends ConsumerState<DhtTab> {
  /// Row currently expanded, as [recordSelectionKey]. Null = nothing selected.
  String? _selected;

  /// The selected record re-fetched with its values, and the state of that
  /// fetch. Separate from the listing's copy, which is metadata only.
  pb.DhtRecord? _detail;
  Object? _detailError;
  bool _detailLoading = false;

  /// Last listing we rendered. Held across a refresh so the table does not
  /// blank out while the new one is in flight.
  pb.DhtRecordsReply? _last;

  final _lookupController = TextEditingController();
  bool _lookupRunning = false;
  int? _lookupOpId;
  pb.DhtLookupReply? _lookupReply;
  Object? _lookupError;

  @override
  void dispose() {
    _lookupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listing = ref.watch(dhtRecordsProvider);
    final fresh = listing.valueOrNull;
    if (fresh != null && !identical(fresh, _last)) {
      _last = fresh;
    }
    final reply = _last;

    if (reply == null) {
      final err = listing.error;
      if (err != null) {
        return ServiceStatusView(
          headline: 'DHT records are not available',
          spinner: false,
          subtitle: _UnavailableDetail(error: err),
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

    final selected = _selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: _DhtHeader(
            records: reply.records,
            serverTime: reply.serverTime,
            refreshing: listing.isLoading,
            onRefresh: () {
              setState(_clearSelection);
              ref.invalidate(dhtRecordsProvider);
            },
          ),
        ),
        Divider(height: 1, color: context.kwaai.divider),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: _LookupBar(
            knownKeys: reply.knownKeys,
            controller: _lookupController,
            running: _lookupRunning,
            onRun: _runLookup,
            onCancel: _cancelLookup,
          ),
        ),
        if (_lookupReply != null || _lookupError != null) ...[
          Divider(height: 1, color: context.kwaai.divider),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: _LookupResult(
                reply: _lookupReply,
                error: _lookupError,
                onClose: () => setState(() {
                  _lookupReply = null;
                  _lookupError = null;
                }),
              ),
            ),
          ),
        ],
        Divider(height: 1, color: context.kwaai.divider),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Caption(title: 'LOCAL RECORDS', detail: _summary(reply.records)),
              Expanded(
                child: reply.records.isEmpty
                    ? const _EmptyRow(
                        text: 'This node holds no DHT records right now.',
                      )
                    : _RecordTable(
                        records: reply.records,
                        selected: selected,
                        onSelect: _select,
                      ),
              ),
            ],
          ),
        ),
        if (selected != null) ...[
          Divider(height: 1, color: context.kwaai.divider),
          // Bounded and scrollable: a dictionary with one subkey per serving
          // peer is long, and the detail must not push the table off screen.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: SingleChildScrollView(
              child: _RecordDetail(
                summary: reply.records.firstWhere(
                  (r) => recordSelectionKey(r) == selected,
                  orElse: pb.DhtRecord.new,
                ),
                detail: _detail,
                loading: _detailLoading,
                error: _detailError,
                onClose: () => setState(_clearSelection),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _summary(List<pb.DhtRecord> records) {
    final cached = records.where((r) => r.inCache).length;
    final dicts = records
        .where((r) => r.kind == pb.DhtRecordKind.DHT_RECORD_KIND_DICTIONARY)
        .length;
    return '${records.length} records · $dicts dictionaries · '
        '$cached cached';
  }

  void _clearSelection() {
    _selected = null;
    _detail = null;
    _detailError = null;
    _detailLoading = false;
  }

  /// Expand a row, fetching that one record's values.
  ///
  /// The listing is metadata-only by design, so the values are a second
  /// request scoped to this key — and to this *tier*, since a key held in both
  /// the primary store and the cache comes back twice.
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

  Future<void> _runLookup(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty || _lookupRunning) return;
    setState(() {
      _lookupRunning = true;
      _lookupReply = null;
      _lookupError = null;
      _lookupOpId = null;
    });
    try {
      final reply = await ref
          .read(kwaaiRpcClientProvider)
          .dhtLookup(trimmed, onOperationId: (id) => _lookupOpId = id);
      if (!mounted) return;
      setState(() {
        _lookupReply = reply;
        _lookupRunning = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lookupError = e;
        _lookupRunning = false;
      });
    }
  }

  /// Abort a running lookup daemon-side. Without the id there is nothing to
  /// cancel — dropping our own await would leave the daemon dialling peers.
  Future<void> _cancelLookup() async {
    final id = _lookupOpId;
    if (id == null) return;
    await ref.read(kwaaiRpcClientProvider).cancelOperation(id);
  }
}

/// Identifies a record among the listing's rows.
///
/// The tier is part of the identity: a key held in both the primary store and
/// the cache appears twice with independent expirations, and those are two
/// genuine records rather than a duplicate to fold away.
String recordSelectionKey(pb.DhtRecord r) =>
    '${r.keyId}:${r.inCache ? 'cache' : 'primary'}';

/// How a record is named in the table: its plaintext name when this node can
/// derive one, otherwise a shortened id.
///
/// Most records have no name and that is normal — a DHT id is SHA1(msgpack of
/// the name) and cannot be inverted, so anything replicated onto us for a
/// model we do not serve arrives as a hash and stays one.
String recordLabel(pb.DhtRecord r) =>
    r.keyName.isNotEmpty ? r.keyName : shortKeyId(r.keyId);

String shortKeyId(String keyId) =>
    keyId.length <= 16 ? keyId : '${keyId.substring(0, 16)}…';

/// A countdown, from `expires_in_secs`.
///
/// Negative is a real reading, not a bug: sweeping is periodic, so a listing
/// can legitimately see a record that has expired but not yet been removed.
String formatExpiry(double secs) {
  final rounded = secs.round();
  final magnitude = _magnitude(rounded.abs());
  return rounded < 0 ? 'expired $magnitude ago' : 'in $magnitude';
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

/// The tab's standing explanation of what is on screen, plus the refresh
/// control. The note is not collapsible — it is the one thing about this view
/// a reader can most easily get wrong.
class _DhtHeader extends StatelessWidget {
  const _DhtHeader({
    required this.records,
    required this.serverTime,
    required this.refreshing,
    required this.onRefresh,
  });

  final List<pb.DhtRecord> records;
  final String serverTime;
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75),
    );
    final expired = records.where((r) => r.expiresInSecs < 0).length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
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
                  Text(
                    'This node’s own store',
                    style: theme.textTheme.labelLarge,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(_localStoreNote, style: muted),
              if (serverTime.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  expired > 0
                      ? 'Daemon time $serverTime · $expired expired, '
                            'not yet swept'
                      : 'Daemon time $serverTime',
                  style: muted,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (refreshing)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          KwaaiButton(
            label: 'Refresh',
            icon: Icons.refresh,
            variant: KwaaiButtonVariant.secondary,
            onPressed: onRefresh,
          ),
      ],
    );
  }
}

/// Pick a known key or type any key name, and resolve it across the network.
///
/// The dropdown is the reverse table the daemon sends with the listing: an id
/// is SHA1(msgpack(name)) and cannot be inverted, so a key can only be looked
/// up by a name someone already knows.
class _LookupBar extends StatelessWidget {
  const _LookupBar({
    required this.knownKeys,
    required this.controller,
    required this.running,
    required this.onRun,
    required this.onCancel,
  });

  final List<pb.DhtKnownKey> knownKeys;
  final TextEditingController controller;
  final bool running;
  final ValueChanged<String> onRun;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text('Look up', style: theme.textTheme.bodySmall),
        const SizedBox(width: 10),
        if (knownKeys.isNotEmpty) ...[
          KwaaiDropdown<String>(
            items: [
              for (final k in knownKeys)
                KwaaiDropdownItem(value: k.name, label: k.name),
            ],
            value: knownKeys.any((k) => k.name == controller.text)
                ? controller.text
                : null,
            hintText: 'Known keys',
            enabled: !running,
            onChanged: (v) {
              if (v == null) return;
              controller.text = v;
              onRun(v);
            },
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: KwaaiTextField(
            controller: controller,
            hintText: 'or any key name, e.g. _petals.models',
            enabled: !running,
            onSubmitted: onRun,
          ),
        ),
        const SizedBox(width: 8),
        running
            ? KwaaiButton(
                label: 'Cancel',
                variant: KwaaiButtonVariant.secondary,
                onPressed: onCancel,
              )
            : KwaaiButton(
                label: 'Look up',
                onPressed: () => onRun(controller.text),
              ),
      ],
    );
  }
}

/// What each peer said, and the freshest record among them.
class _LookupResult extends StatelessWidget {
  const _LookupResult({
    required this.reply,
    required this.error,
    required this.onClose,
  });

  final pb.DhtLookupReply? reply;
  final Object? error;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75),
    );
    final r = reply;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r == null ? 'Lookup failed' : 'Lookup — ${r.key}',
                  style: theme.textTheme.labelLarge,
                ),
              ),
              _CloseButton(onPressed: onClose),
            ],
          ),
          if (r == null)
            Text(_errorText(error), style: muted)
          else ...[
            const SizedBox(height: 2),
            Text('key id ${r.keyId}', style: _mono(context, muted)),
            const SizedBox(height: 8),
            if (r.peers.isEmpty)
              Text('No peers were asked.', style: muted)
            else
              for (final p in r.peers) _LookupPeerLine(peer: p),
            const SizedBox(height: 8),
            if (r.hasRecord()) ...[
              Text('Freshest answer', style: theme.textTheme.labelSmall),
              const SizedBox(height: 4),
              _RecordFacts(record: r.record),
              if (r.record.hasValue()) ...[
                const SizedBox(height: 6),
                _ValueView(value: r.record.value),
              ],
              if (r.record.subkeys.isNotEmpty) ...[
                const SizedBox(height: 6),
                _SubkeyList(subkeys: r.record.subkeys),
              ],
            ] else
              Text('No peer held this key.', style: muted),
          ],
        ],
      ),
    );
  }
}

/// One peer's answer. The three outcomes stay visually distinct: a peer that
/// answered NOT_FOUND is a result, and folding it in with an unreachable peer
/// would erase the difference between "nobody has this" and "nobody answered".
class _LookupPeerLine extends StatelessWidget {
  const _LookupPeerLine({required this.peer});

  final pb.DhtLookupPeer peer;

  @override
  Widget build(BuildContext context) {
    final kwaai = context.kwaai;
    final theme = Theme.of(context);
    final (icon, color, label) = switch (peer.outcome) {
      pb.DhtLookupOutcome.DHT_LOOKUP_OUTCOME_FOUND => (
        Icons.check_circle,
        kwaai.semanticSuccess,
        'found',
      ),
      pb.DhtLookupOutcome.DHT_LOOKUP_OUTCOME_NOT_FOUND => (
        Icons.remove_circle_outline,
        kwaai.semanticWarning,
        'not found',
      ),
      pb.DhtLookupOutcome.DHT_LOOKUP_OUTCOME_ERROR => (
        Icons.error_outline,
        kwaai.semanticError,
        'no answer',
      ),
      _ => (Icons.help_outline, theme.dividerColor, 'unknown'),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          SizedBox(
            width: 74,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
          Expanded(
            child: Text(
              peer.error.isEmpty
                  ? peer.peerId
                  : '${peer.peerId} — ${peer.error}',
              style: _mono(context, theme.textTheme.bodySmall),
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text('${peer.elapsedMs} ms', style: theme.textTheme.bodySmall),
        ],
      ),
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
                          // Meaningless for a regular value, and 0 on a
                          // dictionary means every subkey has expired — the
                          // kind column is what tells those apart.
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
                        Text(
                          formatExpiry(r.expiresInSecs),
                          style: cellStyle?.copyWith(
                            color: r.expiresInSecs < 0
                                ? kwaai.semanticWarning
                                : null,
                          ),
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

/// Primary store vs cache. A cached record is here because a lookup passed
/// through this node, not because anyone chose to replicate onto it.
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
            _SubkeyList(subkeys: detail!.subkeys)
          else if (detail!.hasValue())
            _ValueView(value: detail!.value)
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
          '${kindLabel(r.kind)} · ${r.inCache ? 'cache' : 'primary'} '
          '· ${formatValueBytes(r.valueBytes.toInt())}'
          '${isDict ? ' · ${r.subkeyCount} subkeys' : ''}'
          '${r.hasDictMaxsize() ? ' of at most ${r.dictMaxsize}' : ''}',
          style: muted,
        ),
        Text(
          'Expires ${formatExpiry(r.expiresInSecs)} '
          '(${formatEpoch(r.expiration)})',
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

/// A dictionary's subkeys, each with its own expiration — independent of the
/// record's, which is the point of a dictionary.
class _SubkeyList extends StatelessWidget {
  const _SubkeyList({required this.subkeys});

  final List<pb.DhtSubkey> subkeys;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75),
    );
    if (subkeys.isEmpty) {
      return Text(
        'Every subkey has expired — the record is still here, its '
        'contents are not.',
        style: muted,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in subkeys) ...[
          Text(
            '${s.subkey} · ${formatExpiry(s.expiresInSecs)} · '
            '${formatValueBytes(s.valueBytes.toInt())}',
            style: _mono(context, muted),
          ),
          const SizedBox(height: 2),
          _ValueView(value: s.value),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// A decoded msgpack value.
///
/// Preformatted because the rendering is structural, not semantic: the daemon
/// decodes msgpack and shows what is there, without knowing that an Ext(64)
/// under a block key is a petals ServerInfo. When it could not decode at all,
/// the bytes are labelled as opaque rather than dressed up as meaningful.
class _ValueView extends StatelessWidget {
  const _ValueView({required this.value});

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
              value.rendered,
              style: _mono(context, theme.textTheme.bodySmall),
              softWrap: false,
            ),
          ),
        ),
      ],
    );
  }
}

/// Secondary detail under the unavailable headline: the daemon's own words,
/// plus the one fix we can name without guessing.
class _UnavailableDetail extends StatelessWidget {
  const _UnavailableDetail({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
    );
    final needsNative =
        error is SessionOpError &&
        (error as SessionOpError).code == _unimplemented;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            needsNative
                ? 'This daemon runs the Go p2p stack, which has no hivemind '
                      'store to enumerate.'
                : _errorText(error),
            style: muted,
            textAlign: TextAlign.center,
          ),
        ),
        if (needsNative) ...[
          const SizedBox(height: 10),
          SelectableText(
            'kwaainet config set native_p2p true',
            style: _mono(context, theme.textTheme.bodySmall),
          ),
        ],
      ],
    );
  }
}

String _errorText(Object? error) => switch (error) {
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
