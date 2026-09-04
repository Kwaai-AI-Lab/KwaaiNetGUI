import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/generated/kwaai.pb.dart' as pb;
import '../../chat/kwaai_rpc_client.dart';
import '../../chat/session_client.dart';
import '../../daemon/daemon_state.dart';
import '../../daemon/dht_state.dart';
import '../../window/window_focus.dart';
import '../theme/kwaai_theme.dart';
import '../widgets/kwaai_button.dart';
import '../widgets/kwaai_dropdown.dart';
import '../widgets/kwaai_text_field.dart';
import '../widgets/service_status_view.dart';
import 'settings_page.dart' show kSelectedUnfocusedFill;

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
    'nothing about the network’s key space. To reach elsewhere, look up a key '
    'by name.';

/// `Error.Code.CANCELLED` from kwaai.proto.
const _cancelled = 4;

/// `Error.Code.UNIMPLEMENTED` from kwaai.proto — the Go p2p path, which has no
/// hivemind store to enumerate.
const _unimplemented = 6;

/// Which of the two operations the tab is showing. One at a time: they answer
/// different questions ("what is here" vs "what is out there") and a page
/// showing both invited reading one as the other.
enum DhtMode { local, lookup }

/// Settings tab for `dht_records` / `dht_lookup`: a mode row, one table, and
/// a detail panel. Both operations are one-shot; values are fetched per row.
class DhtTab extends ConsumerStatefulWidget {
  const DhtTab({super.key});

  @override
  ConsumerState<DhtTab> createState() => _DhtTabState();
}

class _DhtTabState extends ConsumerState<DhtTab> {
  DhtMode _mode = DhtMode.local;

  /// Local row currently expanded, as [recordSelectionKey]. Null = none.
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

  final _lookupController = TextEditingController();
  bool _lookupRunning = false;
  bool _lookupCancelled = false;
  int? _lookupOpId;

  /// Cancel pressed before the daemon had allocated an id; honoured on arrival.
  bool _cancelRequested = false;

  late final KwaaiRpcClient _client;

  /// The key of the last lookup run, which is what Refresh re-runs.
  String? _lastLookupKey;
  pb.DhtLookupReply? _lookupReply;
  Object? _lookupError;

  /// Lookup row currently expanded, by peer id. Null = none.
  String? _selectedPeer;

  @override
  void initState() {
    super.initState();
    _client = ref.read(kwaaiRpcClientProvider);
  }

  @override
  void dispose() {
    // The lazy-mount contract: nothing keeps dialling once the tab is gone.
    if (_lookupRunning) _cancelLookup();
    _lookupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

    final local = _mode == DhtMode.local;
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
                child: local
                    ? _LocalHeader(
                        shown: reply.records.length,
                        total: reply.totalRecords,
                        summary: _summary(reply),
                        truncated: reply.totalRecords > reply.records.length,
                      )
                    : _LookupBar(
                        knownKeys: reply.knownKeys,
                        controller: _lookupController,
                        running: _lookupRunning,
                        onRun: _runLookup,
                        onCancel: _cancelLookup,
                      ),
              ),
              const SizedBox(width: 12),
              _ModeSegmented(mode: _mode, onChanged: _setMode),
              const SizedBox(width: 4),
              _RefreshButton(
                onPressed: local
                    ? (listing.isLoading ? null : _refreshLocal)
                    : (_lookupRunning || _lastLookupKey == null
                          ? null
                          : _refreshLookup),
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
        Expanded(child: local ? _localBand(reply) : _lookupBand()),
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

  Widget _lookupBand() {
    final reply = _lookupReply;
    final error = _lookupError;
    final Widget body;
    if (_lookupRunning) {
      body = const _EmptyRow(text: 'Asking peers…');
    } else if (_lookupCancelled) {
      body = const _EmptyRow(text: 'Lookup cancelled.');
    } else if (error != null) {
      body = Center(child: _UnavailableDetail(error: error));
    } else if (reply == null) {
      body = const _EmptyRow(
        text: 'Pick a known key or type one, then Look up.',
      );
    } else if (reply.peers.isEmpty) {
      body = const _EmptyRow(text: 'No peers were asked.');
    } else {
      body = _LookupTable(
        reply: reply,
        freshestPeer: freshestPeer(reply),
        selectedPeer: _selectedPeer,
        onSelect: _selectPeer,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Caption(
          title: reply == null ? 'LOOKUP' : 'LOOKUP — ${reply.key}',
          detail: reply == null ? null : _lookupSummary(reply),
        ),
        Expanded(child: body),
      ],
    );
  }

  /// Band 3: the selected local record, or the selected peer's answer.
  List<Widget> _detailBand(pb.DhtRecordsReply reply, Widget divider) {
    final Widget? panel;
    if (_mode == DhtMode.local) {
      final selected = _selected;
      panel = selected == null
          ? null
          : _RecordDetail(
              summary: reply.records.firstWhere(
                (r) => recordSelectionKey(r) == selected,
                orElse: pb.DhtRecord.new,
              ),
              detail: _detail,
              loading: _detailLoading,
              error: _detailError,
              onClose: () => setState(_clearSelection),
            );
    } else {
      final peer = _lookupReply?.peers
          .where((p) => p.peerId == _selectedPeer)
          .firstOrNull;
      if (peer == null) {
        panel = null;
      } else if (peer.hasRecord()) {
        panel = _RecordDetail(
          summary: peer.record,
          detail: peer.record,
          loading: false,
          error: null,
          local: false,
          onClose: () => setState(_clearSelection),
        );
      } else {
        panel = _NoRecordDetail(
          peer: peer,
          onClose: () => setState(_clearSelection),
        );
      }
    }
    if (panel == null) return const [];
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

  String _lookupSummary(pb.DhtLookupReply reply) {
    var found = 0;
    var missing = 0;
    var failed = 0;
    for (final p in reply.peers) {
      switch (p.outcome) {
        case pb.DhtLookupOutcome.DHT_LOOKUP_OUTCOME_FOUND:
          found++;
        case pb.DhtLookupOutcome.DHT_LOOKUP_OUTCOME_NOT_FOUND:
          missing++;
        default:
          failed++;
      }
    }
    return '$found found · $missing not found · $failed no answer';
  }

  /// Switching modes fires nothing: the listing is already held, and a lookup
  /// only ever runs from its button.
  void _setMode(DhtMode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _clearSelection();
    });
  }

  void _clearSelection() {
    _selected = null;
    _selectedPeer = null;
    _detail = null;
    _detailError = null;
    _detailLoading = false;
  }

  void _refreshLocal() {
    setState(_clearSelection);
    ref.invalidate(dhtRecordsProvider);
  }

  void _refreshLookup() {
    final key = _lastLookupKey;
    if (key == null) return;
    setState(_clearSelection);
    _runLookup(key);
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

  void _selectPeer(String peerId) => setState(() {
    _selectedPeer = _selectedPeer == peerId ? null : peerId;
  });

  Future<void> _runLookup(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty || _lookupRunning) return;
    setState(() {
      _lookupRunning = true;
      _lookupCancelled = false;
      _cancelRequested = false;
      _lastLookupKey = trimmed;
      _lookupReply = null;
      _lookupError = null;
      _lookupOpId = null;
      _selectedPeer = null;
    });
    try {
      final reply = await _client.dhtLookup(
        trimmed,
        onOperationId: (id) {
          _lookupOpId = id;
          if (_cancelRequested && id != null) _client.cancelOperation(id);
        },
      );
      if (!mounted) return;
      setState(() {
        _lookupReply = reply;
        _lookupRunning = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lookupCancelled = e is SessionOpError && e.code == _cancelled;
        _lookupError = _lookupCancelled ? null : e;
        _lookupRunning = false;
      });
    }
  }

  /// Abort a running lookup daemon-side — dropping our own await alone would
  /// leave the daemon dialling peers.
  void _cancelLookup() {
    _cancelRequested = true;
    final id = _lookupOpId;
    if (id != null) _client.cancelOperation(id);
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

/// The peer whose answer `DhtLookupReply.record` was taken from: the first
/// FOUND peer whose record carries the merged record's expiration. Null when
/// no peer had the key.
String? freshestPeer(pb.DhtLookupReply reply) {
  if (!reply.hasRecord()) return null;
  for (final p in reply.peers) {
    if (p.outcome == pb.DhtLookupOutcome.DHT_LOOKUP_OUTCOME_FOUND &&
        p.hasRecord() &&
        p.record.expiration == reply.record.expiration) {
      return p.peerId;
    }
  }
  return null;
}

/// A countdown from `expires_in_secs`. Negative is real: lookup answers carry
/// the peer's clock, and dictionaries keep expired subkeys.
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

/// Local / Lookup switch. Same primitive and colours as the main page's tab
/// selector, so the two read as one family of control.
class _ModeSegmented extends StatelessWidget {
  const _ModeSegmented({required this.mode, required this.onChanged});

  final DhtMode mode;
  final ValueChanged<DhtMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final accent = context.kwaai.accentPrimary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final focused = WindowFocusScope.of(context);
    final selectedFill = focused ? accent : kSelectedUnfocusedFill;
    final selectedFg = focused ? Colors.white : onSurface;
    final unselectedFill = onSurface.withValues(alpha: 0.12);
    final unselectedFg = onSurface.withValues(alpha: 0.6);

    return SegmentedButton<DhtMode>(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? selectedFill
              : unselectedFill,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? selectedFg : unselectedFg,
        ),
        side: const WidgetStatePropertyAll(BorderSide.none),
        visualDensity: VisualDensity.compact,
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        ),
      ),
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: DhtMode.local, label: Text('Local')),
        ButtonSegment(value: DhtMode.lookup, label: Text('Lookup')),
      ],
      selected: {mode},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// Re-runs whichever operation the current mode shows. Disabled while that
/// operation is in flight, and in Lookup mode until a lookup has been run.
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

/// Band 1 in Local mode: what the listing is, how much of it is shown, and
/// the summary. The note is not collapsible — it is the one thing about this
/// view a reader can most easily get wrong.
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

/// Band 1 in Lookup mode. The dropdown is the daemon's `known_keys` reverse
/// table — a key can only be looked up by name.
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
    final dropdown = knownKeys.isEmpty
        ? null
        : KwaaiDropdown<String>(
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
          );
    final field = Expanded(
      child: KwaaiTextField(
        controller: controller,
        hintText: 'or any key name, e.g. _petals.models',
        enabled: !running,
        onSubmitted: onRun,
      ),
    );
    final run = running
        ? KwaaiButton(
            label: 'Cancel',
            variant: KwaaiButtonVariant.secondary,
            onPressed: onCancel,
          )
        : KwaaiButton(
            label: 'Look up',
            onPressed: () => onRun(controller.text),
          );

    // Below the side-rail breakpoint the three controls no longer fit one
    // row beside the mode switch; the dropdown takes a row of its own.
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 420;
        if (narrow && dropdown != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              dropdown,
              const SizedBox(height: 6),
              Row(children: [field, const SizedBox(width: 8), run]),
            ],
          );
        }
        return Row(
          children: [
            if (dropdown != null) ...[dropdown, const SizedBox(width: 8)],
            field,
            const SizedBox(width: 8),
            run,
          ],
        );
      },
    );
  }
}

/// Band 2 in Lookup mode: one row per peer asked. NOT_FOUND is a result, and
/// stays visually distinct from a peer that never answered.
class _LookupTable extends StatelessWidget {
  const _LookupTable({
    required this.reply,
    required this.freshestPeer,
    required this.selectedPeer,
    required this.onSelect,
  });

  final pb.DhtLookupReply reply;

  /// The peer whose answer the reply's merged record came from, marked on
  /// its row rather than shown as a separate panel.
  final String? freshestPeer;
  final String? selectedPeer;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final kwaai = context.kwaai;
    final theme = Theme.of(context);
    final headStyle = theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.6);
    final cellStyle = theme.textTheme.bodySmall;
    final monoStyle = _mono(context, cellStyle);
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
                DataColumn(label: Text('OUTCOME', style: headStyle)),
                DataColumn(label: Text('PEER', style: headStyle)),
                DataColumn(label: Text('RTT', style: headStyle), numeric: true),
                DataColumn(label: Text('KIND', style: headStyle)),
                DataColumn(label: Text('EXPIRES', style: headStyle)),
                DataColumn(label: Text('DETAIL', style: headStyle)),
              ],
              rows: [
                for (final (i, p) in reply.peers.indexed)
                  DataRow(
                    // A peer can be listed twice (configured and in the
                    // routing table); the id alone would collide.
                    key: ValueKey('$i:${p.peerId}'),
                    selected: p.peerId == selectedPeer,
                    color: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? selectedFill
                          : null,
                    ),
                    onSelectChanged: (_) => onSelect(p.peerId),
                    cells: [
                      DataCell(_OutcomeCell(outcome: p.outcome)),
                      DataCell(
                        Row(
                          children: [
                            Text(shortKeyId(p.peerId), style: monoStyle),
                            _CopyButton(text: p.peerId, label: 'Peer id'),
                          ],
                        ),
                      ),
                      DataCell(Text('${p.elapsedMs} ms', style: cellStyle)),
                      DataCell(
                        Text(
                          p.hasRecord() ? kindLabel(p.record.kind) : '—',
                          style: cellStyle,
                        ),
                      ),
                      DataCell(
                        Text(
                          p.hasRecord()
                              ? formatExpiry(p.record.expiresInSecs)
                              : '—',
                          style: cellStyle?.copyWith(
                            color: p.hasRecord() && p.record.expiresInSecs < 0
                                ? kwaai.semanticWarning
                                : null,
                          ),
                        ),
                      ),
                      DataCell(
                        p.peerId == freshestPeer
                            ? Row(
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: 13,
                                    color: kwaai.semanticSuccess,
                                  ),
                                  const SizedBox(width: 4),
                                  Text('freshest answer', style: cellStyle),
                                ],
                              )
                            : Text(
                                p.error,
                                style: cellStyle,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
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

class _OutcomeCell extends StatelessWidget {
  const _OutcomeCell({required this.outcome});

  final pb.DhtLookupOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final kwaai = context.kwaai;
    final theme = Theme.of(context);
    final (icon, color, label) = switch (outcome) {
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
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: color)),
      ],
    );
  }
}

/// Band 3 for a lookup row that carries no record: says why.
class _NoRecordDetail extends StatelessWidget {
  const _NoRecordDetail({required this.peer, required this.onClose});

  final pb.DhtLookupPeer peer;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75),
    );
    final reason = switch (peer.outcome) {
      pb.DhtLookupOutcome.DHT_LOOKUP_OUTCOME_NOT_FOUND =>
        'This peer answered and does not hold the key.',
      pb.DhtLookupOutcome.DHT_LOOKUP_OUTCOME_ERROR =>
        'No answer from this peer: ${peer.error}',
      _ => 'This peer returned no record.',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  shortKeyId(peer.peerId),
                  style: _mono(context, theme.textTheme.labelLarge),
                ),
              ),
              _CloseButton(onPressed: onClose),
            ],
          ),
          Text(peer.peerId, style: _mono(context, muted)),
          const SizedBox(height: 8),
          Text(reason, style: muted),
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
    this.local = true,
    required this.onClose,
  });

  /// The listing's metadata for the row, shown while the value request is
  /// still in flight so the panel is never empty.
  final pb.DhtRecord summary;
  final pb.DhtRecord? detail;
  final bool loading;
  final Object? error;

  /// False for a lookup answer, which was never stored here and has no tier.
  final bool local;
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
          _RecordFacts(record: record, showTier: local),
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
            _SubkeyList(
              title: recordLabel(record),
              subkeyCount: detail!.subkeyCount,
              subkeys: detail!.subkeys,
            )
          else if (detail!.hasValue())
            _ValueView(title: recordLabel(record), value: detail!.value)
          else
            Text('The daemon returned no value for this record.', style: muted),
        ],
      ),
    );
  }
}

/// The record's metadata line: tier, kind, size and both expirations.
class _RecordFacts extends StatelessWidget {
  const _RecordFacts({required this.record, required this.showTier});

  final pb.DhtRecord record;
  final bool showTier;

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
          '${kindLabel(r.kind)}'
          '${showTier ? ' · ${r.inCache ? 'cache' : 'primary'}' : ''}'
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
  });

  /// The record's label, which each subkey's viewer titles itself with.
  final String title;
  final int subkeyCount;
  final List<pb.DhtSubkey> subkeys;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75),
    );
    // A lookup answer may omit the per-subkey values it counted.
    if (subkeys.isEmpty) {
      return Text(
        subkeyCount > 0
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
            '${s.subkey} · ${formatExpiry(s.expiresInSecs)} · '
            '${formatValueBytes(s.valueBytes.toInt())}',
            style: _mono(context, muted),
          ),
          const SizedBox(height: 2),
          _ValueView(title: '$title · ${s.subkey}', value: s.value),
          const SizedBox(height: 8),
        ],
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

String previewOf(String rendered) => rendered.length <= kValuePreviewChars
    ? rendered
    : '${rendered.substring(0, kValuePreviewChars)}…';

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

class _ValueDialog extends StatelessWidget {
  const _ValueDialog({required this.title, required this.value});

  final String title;
  final pb.DhtValueView value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kwaai = context.kwaai;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75),
    );
    final size = MediaQuery.sizeOf(context);
    // Squarish: the shorter viewport side bounds both axes.
    final side = 0.8 * (size.width < size.height ? size.width : size.height);
    final ext = value.hasExtCode() ? ' (ext ${value.extCode})' : '';

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
                      title,
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _CopyButton(text: value.rendered, label: 'Value'),
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
                      value.rendered,
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
