import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/generated/kwaai.pb.dart' as pb;
import '../../chat/kwaai_rpc_client.dart';
import '../../daemon/daemon_state.dart';
import '../../daemon/rag_state.dart';
import '../theme/kwaai_theme.dart';
import '../widgets/kwaai_button.dart';
import '../widgets/kwaai_dropdown.dart';
import '../widgets/kwaai_text_field.dart';
import '../widgets/service_status_view.dart';

/// Retrieval-augmented generation: knowledge bases, ingest, and retrieval.
///
/// Four states, in priority order — daemon unreachable, RAG absent from the
/// build, nothing initialised, and ready. They are ordered by how much they
/// preclude: there is no point offering to initialise a KB on a daemon that
/// cannot do RAG, and none at all when the daemon isn't answering.
///
/// "Nothing initialised" is a zero-length KB list rather than an error,
/// which is why it can't simply be folded into the error path: the daemon
/// is working fine and the remedy is a button, not a rebuild.
class RagTab extends ConsumerWidget {
  const RagTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reachability rather than a local PID: with KWAAINET_GRPC_PORT set the
    // daemon runs elsewhere and has no PID here. Matches the other tabs.
    final running = ref.watch(daemonAvailableProvider);
    if (!running) {
      return ServiceStatusView(
        headline: unavailableHeadline(),
        spinner: false,
        subtitle: Text(unavailableHint('use RAG')),
      );
    }

    final status = ref.watch(ragStatusProvider);
    return status.when(
      loading: () =>
          const ServiceStatusView(headline: 'Loading knowledge bases…'),
      error: (e, _) {
        if (isRagUnavailable(e)) {
          return const ServiceStatusView(
            headline: 'RAG isn\'t available in this daemon',
            spinner: false,
            subtitle: Text(
              'Rebuild the daemon with the storage and rag features, or '
              'update it to a version that includes them.',
              textAlign: TextAlign.center,
            ),
          );
        }
        return ServiceStatusView(
          headline: 'Couldn\'t load knowledge bases',
          spinner: false,
          subtitle: Text(ragErrorText(e), textAlign: TextAlign.center),
        );
      },
      data: (update) => update.kbs.isEmpty
          ? const _RagInitGate()
          : _RagReady(kbs: update.kbs),
    );
  }
}

/// Shown when RAG works but no knowledge base exists yet.
///
/// Deliberately a single button with no options: naming a KB or picking an
/// embedding model is a decision the first-time user has no basis to make,
/// and both can be done later from the ready state. Empty strings let the
/// daemon choose, which is what "default" means on the wire.
class _RagInitGate extends ConsumerStatefulWidget {
  const _RagInitGate();

  @override
  ConsumerState<_RagInitGate> createState() => _RagInitGateState();
}

class _RagInitGateState extends ConsumerState<_RagInitGate> {
  bool _busy = false;
  String? _error;

  Future<void> _init() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final reply = await ref.read(kwaaiRpcClientProvider).ragInit();
      if (!mounted) return;
      // Select what was actually created — the daemon resolves an empty
      // name to its own default, which need not be the string "default".
      ref.read(selectedKbProvider.notifier).state = reply.kb.name;
      ref.invalidate(ragStatusProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = ragErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const ServiceStatusView(
        headline: 'Setting up the knowledge base…',
        subtitle: Text(
          'Pulling the embedding model can take a few minutes the first time.',
          textAlign: TextAlign.center,
        ),
      );
    }

    final err = _error;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'RAG isn\'t set up yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Create a knowledge base to search your own documents. '
              'This needs Ollama running locally with an embedding model '
              'available.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (err != null) ...[
              const SizedBox(height: 14),
              _RagAlert(message: err),
            ],
            const SizedBox(height: 16),
            KwaaiButton(
              label: err == null ? 'Initialize RAG' : 'Retry',
              onPressed: _init,
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline alert, styled like the chat page's slow/error bars.
class _RagAlert extends StatelessWidget {
  const _RagAlert({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.kwaai.semanticError;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        border: Border.all(color: c.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 16, color: c),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: c),
            ),
          ),
        ],
      ),
    );
  }
}

/// Informational bar — same shape as [_RagAlert] in a non-alarming colour.
class _RagNotice extends StatelessWidget {
  const _RagNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.kwaai.semanticInfo;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        border: Border.all(color: c.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: c),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: c),
            ),
          ),
        ],
      ),
    );
  }
}

/// The populated view: pick a KB, add documents to it, search it.
class _RagReady extends ConsumerWidget {
  const _RagReady({required this.kbs});

  final List<pb.RagKb> kbs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedName = selectKb(kbs, ref.watch(selectedKbProvider));
    final kb = kbs.firstWhere(
      (k) => k.name == selectedName,
      orElse: () => kbs.first,
    );
    // Phase 1 serves only local KBs. A remote one is shown (hiding it would
    // be more confusing than explaining it) but neither ingests nor queries.
    final remote = kb.remote;

    // Results take the width they need to be readable; documents are a
    // fixed-width sidebar because a file list gains nothing from extra
    // room and the retrieved text loses by it.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (remote)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _RagNotice(
                    message:
                        'This knowledge base lives on another node. Remote KBs '
                        'aren\'t supported yet, so it can\'t be added to or '
                        'searched from here.',
                  ),
                ),
              // The query section owns both halves: results scroll in the
              // space left over, and the input sits on the bottom edge.
              // Splitting them into siblings here would mean lifting the
              // result state up for no gain — nothing else reads it.
              Expanded(child: _QuerySection(kb: kb, enabled: !remote)),
            ],
          ),
        ),
        VerticalDivider(width: 1, color: context.kwaai.divider),
        SizedBox(
          width: _kDocPanelWidth,
          child: _DocumentPanel(kb: kb, enabled: !remote),
        ),
      ],
    );
  }
}

/// Width of the documents sidebar.
///
/// Wide enough for a typical filename plus its delete button before
/// ellipsis, narrow enough to leave the results column the majority of a
/// default-sized window.
const double _kDocPanelWidth = 260;

/// KB picker plus the "New…" affordance, without any surrounding chrome.
///
/// Lives in the window's top bar rather than inside the tab, so switching
/// knowledge base reads as changing *what the whole tab is showing* — the
/// same altitude as switching between Chat and RAG right beside it. That
/// puts it outside this file's widget tree, hence public.
///
/// Renders nothing until the daemon reports at least one KB: the picker is
/// meaningless with nothing to pick, and the tab is showing its own
/// init/error state in that case anyway.
class RagKbPicker extends ConsumerWidget {
  const RagKbPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kbs =
        ref.watch(ragStatusProvider).valueOrNull?.kbs ?? const <pb.RagKb>[];
    if (kbs.isEmpty) return const SizedBox.shrink();

    final selectedName = selectKb(kbs, ref.watch(selectedKbProvider));
    final selected = kbs.firstWhere(
      (k) => k.name == selectedName,
      orElse: () => kbs.first,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KwaaiDropdown<String>(
          items: [
            for (final k in kbs)
              KwaaiDropdownItem(value: k.name, label: k.name),
          ],
          value: selected.name,
          onChanged: (v) {
            if (v != null) {
              ref.read(selectedKbProvider.notifier).state = v;
            }
          },
        ),
        const SizedBox(width: 8),
        // Labelled rather than a bare "+": in the title bar it sits beside
        // the tab strip, where a lone glyph reads as another piece of
        // window chrome instead of an action on the KB next to it.
        KwaaiButton(
          label: 'Create KB',
          variant: KwaaiButtonVariant.secondary,
          onPressed: () => _newKbDialog(context, ref),
        ),
      ],
    );
  }
}

/// Prompt for a KB name and create it.
///
/// Returns nothing: on success the status provider is invalidated and the
/// new KB selected, so the caller's tree updates on its own.
Future<void> _newKbDialog(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (ctx) => _NewKbDialog(controller: controller, ref: ref),
  );
  controller.dispose();
}

class _NewKbDialog extends StatefulWidget {
  const _NewKbDialog({required this.controller, required this.ref});

  final TextEditingController controller;
  final WidgetRef ref;

  @override
  State<_NewKbDialog> createState() => _NewKbDialogState();
}

class _NewKbDialogState extends State<_NewKbDialog> {
  String? _error;
  bool _busy = false;

  Future<void> _create() async {
    final name = widget.controller.text.trim();
    final invalid = validateKbName(name);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final reply = await widget.ref
          .read(kwaaiRpcClientProvider)
          .ragInit(kb: name);
      widget.ref.read(selectedKbProvider.notifier).state = reply.kb.name;
      widget.ref.invalidate(ragStatusProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ragErrorText(e);
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final err = _error;
    return AlertDialog(
      title: const Text('New knowledge base'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KwaaiTextField(
              controller: widget.controller,
              hintText: 'e.g. handbook',
              enabled: !_busy,
              onSubmitted: (_) => _busy ? null : _create(),
            ),
            if (err != null) ...[
              const SizedBox(height: 12),
              _RagAlert(message: err),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        KwaaiButton(label: 'Create', onPressed: _busy ? null : _create),
      ],
    );
  }
}

/// Why [name] is not usable as a KB name, or null when it is fine.
///
/// Names become directory names daemon-side, so whitespace and separators
/// are rejected here rather than being sent and failing with a less
/// specific INVALID_ARGUMENT.
String? validateKbName(String name) {
  if (name.isEmpty) return 'Enter a name.';
  if (name.contains(RegExp(r'\s'))) return 'Names can\'t contain spaces.';
  if (name.contains(RegExp(r'[/\\]'))) return 'Names can\'t contain slashes.';
  return null;
}

/// "2 documents · nomic-embed-text" — what a KB is, in one line.
///
/// The model is omitted when the daemon didn't report one rather than
/// rendering a dangling separator.
String _kbSubtitle(pb.RagKb kb) {
  final docs = kb.docs.length;
  return [
    '$docs ${docs == 1 ? 'document' : 'documents'}',
    if (kb.embedModel.isNotEmpty) kb.embedModel,
  ].join(' · ');
}

/// The right-hand sidebar: drop target, ingest queue, and the documents
/// already in the KB.
///
/// One widget rather than two stacked siblings because the three parts
/// share a scroll region and a single header — and because the queue is
/// the visual bridge between "I dropped a file" and "it is in the list".
class _DocumentPanel extends ConsumerStatefulWidget {
  const _DocumentPanel({required this.kb, required this.enabled});

  final pb.RagKb kb;
  final bool enabled;

  @override
  ConsumerState<_DocumentPanel> createState() => _DocumentPanelState();
}

class _DocumentPanelState extends ConsumerState<_DocumentPanel> {
  bool _hovering = false;

  void _enqueue(Iterable<String> paths) {
    final supported = paths.where(isSupportedRagFile).toList(growable: false);
    if (supported.isEmpty) return;
    ref
        .read(ragIngestQueueProvider.notifier)
        .enqueue(supported, kb: widget.kb.name);
  }

  Future<void> _browse() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: kRagSupportedExtensions,
    );
    if (result == null) return;
    _enqueue(result.files.map((f) => f.path).whereType<String>());
  }

  @override
  Widget build(BuildContext context) {
    final jobs = ref.watch(ragIngestQueueProvider);
    final accent = context.kwaai.accentPrimary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final active = widget.enabled && _hovering;

    // Compact next to the old full-width zone: in a 260px sidebar the
    // icon-and-two-lines version wastes vertical space the document list
    // wants. Browse stays because drag-and-drop is undiscoverable alone.
    final zone = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: active
            ? accent.withValues(alpha: 0.08)
            : onSurface.withValues(alpha: 0.03),
        border: Border.all(
          color: active ? accent : onSurface.withValues(alpha: 0.18),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.upload_file,
            size: 18,
            color: onSurface.withValues(alpha: widget.enabled ? 0.6 : 0.3),
          ),
          const SizedBox(height: 6),
          Text(
            widget.enabled
                ? 'Drop files here'
                : 'Adding documents is disabled for remote knowledge bases',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: onSurface.withValues(alpha: widget.enabled ? 0.7 : 0.4),
            ),
          ),
          if (widget.enabled) ...[
            const SizedBox(height: 8),
            KwaaiButton(
              label: 'Browse…',
              variant: KwaaiButtonVariant.secondary,
              onPressed: _browse,
            ),
          ],
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Documents',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              // Count and embedding model. The title bar's picker names
              // the KB but has no room to describe it, so the facts that
              // characterise it live here, above the list they describe.
              Text(
                _kbSubtitle(widget.kb),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              // DropTarget wraps rather than replaces the zone so the same
              // container renders identically in tests, where no platform
              // channel for drag-and-drop exists.
              if (widget.enabled)
                DropTarget(
                  onDragEntered: (_) => setState(() => _hovering = true),
                  onDragExited: (_) => setState(() => _hovering = false),
                  onDragDone: (detail) {
                    setState(() => _hovering = false);
                    _enqueue(detail.files.map((f) => f.path));
                  },
                  child: zone,
                )
              else
                zone,
            ],
          ),
        ),
        // Everything below the drop zone scrolls together: a long ingest
        // queue and a long document list compete for the same space, and
        // scrolling them as one keeps the queue visible while it drains.
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              if (jobs.isNotEmpty) ...[
                for (final j in jobs) _IngestJobRow(job: j),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => ref
                        .read(ragIngestQueueProvider.notifier)
                        .clearFinished(),
                    child: const Text('Clear finished'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              _DocumentList(kb: widget.kb, enabled: widget.enabled),
            ],
          ),
        ),
      ],
    );
  }
}

/// One file's ingest progress or outcome.
class _IngestJobRow extends StatelessWidget {
  const _IngestJobRow({required this.job});

  final RagIngestJob job;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.6);

    // Status sits on its own line under the name rather than beside it:
    // in a 260px sidebar a filename and "885 chunks · 885 vectors" both
    // want the full width, and sharing a row ellipsised the name away to
    // nothing.
    final String statusText;
    final Color statusColor;
    switch (job.status) {
      case RagJobStatus.queued:
        statusText = 'Queued';
        statusColor = muted;
      case RagJobStatus.running:
        statusText = ragPhaseLabel(job.phase, done: job.done, total: job.total);
        statusColor = muted;
      case RagJobStatus.done:
        statusText =
            '${job.chunksIngested} chunks · ${job.vectorsUploaded} vectors';
        statusColor = context.kwaai.semanticSuccess;
      case RagJobStatus.failed:
        statusText = job.error ?? 'Failed';
        statusColor = context.kwaai.semanticError;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            job.name,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 2),
          Text(
            statusText,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: statusColor),
          ),
          if (job.status == RagJobStatus.running) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              // Null fraction → indeterminate, which is right for the
              // extraction phase: it reports no counts because it is one
              // indivisible step, and 0/0 would render as a stuck bar.
              child: LinearProgressIndicator(value: job.fraction, minHeight: 4),
            ),
          ],
        ],
      ),
    );
  }
}

/// Human label for an ingest phase, with counts when the phase has them.
String ragPhaseLabel(
  pb.RagProgress_RagPhase phase, {
  int done = 0,
  int total = 0,
}) {
  final counts = total > 0 ? ' $done/$total' : '';
  switch (phase) {
    case pb.RagProgress_RagPhase.RAG_PHASE_EXTRACTING:
      return 'Extracting text';
    case pb.RagProgress_RagPhase.RAG_PHASE_EMBEDDING:
      return 'Embedding$counts';
    case pb.RagProgress_RagPhase.RAG_PHASE_UPLOADING:
      return 'Storing$counts';
    default:
      return 'Working';
  }
}

/// The documents already in the selected KB, each removable.
class _DocumentList extends StatelessWidget {
  const _DocumentList({required this.kb, required this.enabled});

  final pb.RagKb kb;

  /// False for remote KBs, which can't be deleted from any more than they
  /// can be ingested into.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    if (kb.docs.isEmpty) {
      return Text(
        'No documents yet. Add one above to make it searchable.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: onSurface.withValues(alpha: 0.6),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('In this KB', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        // Prefer `documents`, which carries chunk counts. A daemon that
        // predates that field sends only `docs`, so fall back to the bare
        // names and render them without a size line rather than showing
        // every document as "0 chunks".
        if (kb.documents.isNotEmpty)
          for (final d in kb.documents)
            _DocumentRow(
              kb: kb.name,
              doc: d.name,
              chunks: d.chunks,
              enabled: enabled,
            )
        else
          for (final d in kb.docs)
            _DocumentRow(kb: kb.name, doc: d, enabled: enabled),
      ],
    );
  }
}

/// One document row. The delete control appears on hover so a list of
/// filenames doesn't read as a column of buttons, and it is the row's own
/// state because hover is per-row.
class _DocumentRow extends ConsumerStatefulWidget {
  const _DocumentRow({
    required this.kb,
    required this.doc,
    required this.enabled,
    this.chunks,
  });

  final String kb;
  final String doc;
  final bool enabled;

  /// Chunks this document contributed, or null when the daemon is too old
  /// to report it — in which case no size line is shown at all, rather
  /// than claiming zero.
  final int? chunks;

  @override
  ConsumerState<_DocumentRow> createState() => _DocumentRowState();
}

class _DocumentRowState extends ConsumerState<_DocumentRow> {
  bool _hovering = false;
  bool _busy = false;

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text(
          '"${widget.doc}" and everything indexed from it will be removed '
          'from ${widget.kb}. This can\'t be undone — re-adding it means '
          'ingesting the file again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          KwaaiButton(
            label: 'Delete',
            variant: KwaaiButtonVariant.destructive,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(kwaaiRpcClientProvider)
          .ragDelete(docName: widget.doc, kb: widget.kb);
      // The row is about to disappear with the refreshed status, so don't
      // clear _busy — leaving it set keeps the spinner up for the frames
      // between the reply landing and the list rebuilding without it.
      ref.invalidate(ragStatusProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(content: Text('Couldn\'t delete: ${ragErrorText(e)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final showDelete = widget.enabled && (_hovering || _busy);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              // Nudged to sit on the name's line rather than centring
              // against the two-line block.
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                Icons.description_outlined,
                size: 15,
                color: onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tooltip(
                    message: widget.doc,
                    child: Text(
                      widget.doc,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  // Size on its own line: in a 260px sidebar it would
                  // otherwise eat the width the filename needs. Chunks and
                  // vectors are 1:1 by construction — one vector is stored
                  // per chunk — so one number is stated two ways rather
                  // than two numbers that could disagree.
                  if (widget.chunks case final n?)
                    Text(
                      '$n ${n == 1 ? 'chunk' : 'chunks'} · $n '
                      '${n == 1 ? 'vector' : 'vectors'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ),
            // Fixed-size slot either way, so the filename doesn't reflow
            // as the pointer moves down the list. Sized to the name line
            // so it aligns with it rather than the row's full height.
            SizedBox(
              width: 22,
              height: 18,
              child: !showDelete
                  ? null
                  : _busy
                  ? const Padding(
                      padding: EdgeInsets.all(4),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      tooltip: 'Delete document',
                      icon: const Icon(Icons.close, size: 14),
                      onPressed: _delete,
                      style: IconButton.styleFrom(
                        foregroundColor: context.kwaai.semanticError,
                        minimumSize: const Size(22, 22),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Search the selected KB and show the retrieved chunks.
class _QuerySection extends ConsumerStatefulWidget {
  const _QuerySection({required this.kb, required this.enabled});

  final pb.RagKb kb;
  final bool enabled;

  @override
  ConsumerState<_QuerySection> createState() => _QuerySectionState();
}

class _QuerySectionState extends ConsumerState<_QuerySection> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;
  List<pb.RagChunk>? _results;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final reply = await ref
          .read(kwaaiRpcClientProvider)
          .ragQuery(text: text, kb: widget.kb.name);
      if (!mounted) return;
      setState(() => _results = reply.chunks);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = ragErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final err = _error;

    // Results above, input pinned to the bottom edge — the composer
    // arrangement from the chat tab, and for the same reason: the thing
    // you type into should not move as answers accumulate above it.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _busy
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              : results == null
              ? _QueryPlaceholder(enabled: widget.enabled)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  children: [RagResultList(chunks: results)],
                ),
        ),
        if (err != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: _RagAlert(message: err),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: KwaaiTextField(
                  controller: _controller,
                  hintText: 'Ask something about these documents',
                  enabled: widget.enabled && !_busy,
                  onSubmitted: (_) => _run(),
                ),
              ),
              const SizedBox(width: 8),
              KwaaiButton(
                label: 'Query',
                onPressed: widget.enabled && !_busy ? _run : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// What fills the results area before the first query of a session.
class _QueryPlaceholder extends StatelessWidget {
  const _QueryPlaceholder({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.55);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          enabled
              ? 'Search this knowledge base to see matching passages here.'
              : 'Remote knowledge bases can\'t be searched from here yet.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted),
        ),
      ),
    );
  }
}

/// The retrieved-chunk list, given results.
///
/// Public and stateless — it takes chunks rather than fetching them — so
/// the result rendering can be exercised without a daemon. [_QuerySection]
/// owns the fetching and hands the outcome here.
class RagResultList extends StatelessWidget {
  const RagResultList({super.key, required this.chunks});

  final List<pb.RagChunk> chunks;

  @override
  Widget build(BuildContext context) {
    if (chunks.isEmpty) {
      return Text(
        'Nothing matched that query.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final c in chunks) _ChunkCard(chunk: c)],
    );
  }
}

/// One retrieved chunk: rank, score, provenance, and the text itself.
class _ChunkCard extends StatelessWidget {
  const _ChunkCard({required this.chunk});

  final pb.RagChunk chunk;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.6);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.03),
        border: Border.all(color: context.kwaai.divider),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '#${chunk.rank}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: muted,
                  fontFamily: kwaaiMonoFamily,
                  fontFamilyFallback: kwaaiMonoFallback,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                // Fixed precision, in mono: scores are compared down the
                // list, and a ragged number of decimals makes that harder
                // than it needs to be.
                chunk.score.toStringAsFixed(3),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.kwaai.accentPrimary,
                  fontFamily: kwaaiMonoFamily,
                  fontFamilyFallback: kwaaiMonoFallback,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  chunk.doc,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: muted),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#${chunk.chunkIndex}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: muted,
                    fontFamily: kwaaiMonoFamily,
                    fontFamilyFallback: kwaaiMonoFallback,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Unclipped: a chunk is the evidence for its score, and a
          // truncated one can cut off the very passage that explains why
          // it ranked. The card grows and the result list scrolls.
          SelectableText(
            chunk.text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
