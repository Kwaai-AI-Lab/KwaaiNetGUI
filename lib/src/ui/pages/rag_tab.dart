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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: _RagHeader(kbs: kbs, selected: kb),
        ),
        Divider(height: 1, color: context.kwaai.divider),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            children: [
              if (remote) ...[
                const _RagNotice(
                  message:
                      'This knowledge base lives on another node. Remote KBs '
                      'aren\'t supported yet, so it can\'t be added to or '
                      'searched from here.',
                ),
                const SizedBox(height: 14),
              ],
              _IngestSection(kb: kb, enabled: !remote),
              const SizedBox(height: 18),
              _DocumentsSection(kb: kb),
              const SizedBox(height: 18),
              _QuerySection(kb: kb, enabled: !remote),
            ],
          ),
        ),
      ],
    );
  }
}

/// Title, KB picker, and the "New…" affordance.
class _RagHeader extends ConsumerWidget {
  const _RagHeader({required this.kbs, required this.selected});

  final List<pb.RagKb> kbs;
  final pb.RagKb selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = selected.docs.length;
    final model = selected.embedModel;
    final subtitle = [
      '$docs ${docs == 1 ? 'document' : 'documents'}',
      if (model.isNotEmpty) model,
    ].join(' · ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Knowledge base',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const Spacer(),
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
        Tooltip(
          message: 'New knowledge base',
          child: IconButton(
            icon: const Icon(Icons.add, size: 18),
            onPressed: () => _newKbDialog(context, ref),
          ),
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

/// Drop target + file picker, and the queue of in-flight ingests.
class _IngestSection extends ConsumerStatefulWidget {
  const _IngestSection({required this.kb, required this.enabled});

  final pb.RagKb kb;
  final bool enabled;

  @override
  ConsumerState<_IngestSection> createState() => _IngestSectionState();
}

class _IngestSectionState extends ConsumerState<_IngestSection> {
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

    final zone = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
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
            size: 22,
            color: onSurface.withValues(alpha: widget.enabled ? 0.6 : 0.3),
          ),
          const SizedBox(height: 8),
          Text(
            widget.enabled
                ? 'Drop files here to add them'
                : 'Adding documents is disabled for remote knowledge bases',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: onSurface.withValues(alpha: widget.enabled ? 0.7 : 0.4),
            ),
          ),
          if (widget.enabled) ...[
            const SizedBox(height: 10),
            KwaaiButton(
              label: 'Browse…',
              variant: KwaaiButtonVariant.secondary,
              onPressed: _browse,
            ),
            const SizedBox(height: 6),
            Text(
              kRagSupportedExtensions.join(' · '),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Documents', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        // DropTarget wraps rather than replaces the zone so the same
        // container renders identically in tests, where no platform channel
        // for drag-and-drop exists.
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
        if (jobs.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final j in jobs) _IngestJobRow(job: j),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () =>
                  ref.read(ragIngestQueueProvider.notifier).clearFinished(),
              child: const Text('Clear finished'),
            ),
          ),
        ],
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

    Widget trailing;
    switch (job.status) {
      case RagJobStatus.queued:
        trailing = Text(
          'Queued',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
        );
      case RagJobStatus.running:
        trailing = Text(
          ragPhaseLabel(job.phase, done: job.done, total: job.total),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
        );
      case RagJobStatus.done:
        trailing = Text(
          '${job.chunksIngested} chunks · ${job.vectorsUploaded} vectors',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.kwaai.semanticSuccess),
        );
      case RagJobStatus.failed:
        trailing = Text(
          job.error ?? 'Failed',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.kwaai.semanticError),
        );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  job.name,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Align(alignment: Alignment.centerRight, child: trailing),
              ),
            ],
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

/// The documents already in the selected KB.
class _DocumentsSection extends StatelessWidget {
  const _DocumentsSection({required this.kb});

  final pb.RagKb kb;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    if (kb.docs.isEmpty) {
      return Text(
        'No documents yet. Add one above to make it searchable.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: onSurface.withValues(alpha: 0.6),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('In this KB', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final d in kb.docs)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 15,
                  color: onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    d,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
      ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Search', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        Row(
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
        if (_busy) ...[
          const SizedBox(height: 12),
          const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
        ],
        if (err != null) ...[
          const SizedBox(height: 12),
          _RagAlert(message: err),
        ],
        if (results != null && !_busy) ...[
          const SizedBox(height: 12),
          RagResultList(chunks: results),
        ],
      ],
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
          SelectableText(
            chunk.text,
            maxLines: 12,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
