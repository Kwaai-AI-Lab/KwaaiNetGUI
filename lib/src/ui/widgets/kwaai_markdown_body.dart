import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/custom_widgets/markdown_config.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/kwaai_theme.dart';

/// Marker appended to the markdown source to reserve a slot for the
/// trailing widget. Uses Unicode private-use-area codepoints, which
/// carry no meaning in markdown and will not occur in model output, so
/// it can't be produced accidentally by a response or be reinterpreted
/// as markup mid-stream.
const _kTrailingSentinel = '';

/// Maps [_kTrailingSentinel] back to a caller-supplied widget as an
/// inline span, so the marker flows with the final line of text instead
/// of being stacked beneath the rendered body.
class _TrailingSentinel extends InlineMd {
  _TrailingSentinel(this.child);

  final Widget child;

  @override
  RegExp get exp => RegExp(_kTrailingSentinel);

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    GptMarkdownConfig config,
  ) => WidgetSpan(
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    child: child,
  );
}

/// Renders assistant output as markdown.
///
/// The daemon streams plain markdown, so a mid-stream snapshot is
/// routinely malformed — an unclosed `**`, a half-written table row, a
/// code fence with no terminator. [GptMarkdown] is used precisely
/// because it degrades gracefully on that partial input rather than
/// throwing or flashing raw syntax, so no "repair the markdown" pass is
/// needed before handing text to it.
///
/// Only assistant messages go through here. User text is rendered
/// verbatim by the caller — someone typing `2 * 3 * 4` into the composer
/// means asterisks, not emphasis.
class KwaaiMarkdownBody extends StatelessWidget {
  const KwaaiMarkdownBody({super.key, required this.text, this.trailing});

  final String text;

  /// Marker tacked onto the end of the rendered text — the streaming
  /// dots or the truncation splat.
  ///
  /// It has to join the *inline flow* of the final line rather than sit
  /// in a row underneath, so the dots keep trailing the last word the
  /// way they did before markdown rendering. That's done by appending a
  /// sentinel to the source and mapping it back to this widget with a
  /// custom inline component; see [_TrailingSentinel].
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = Theme.of(context).textTheme.bodyMedium!.copyWith(
      color: scheme.onSurface,
      // Markdown output is dense with lists and headings; a little extra
      // leading keeps stacked block elements legible.
      height: 1.45,
    );

    // Appending the sentinel to the source (rather than composing a
    // widget after the fact) is what keeps the marker on the same line
    // as the final word — the parser lays it out as part of that
    // paragraph's span run.
    final source = trailing == null ? text : '$text$_kTrailingSentinel';

    return GptMarkdown(
      source,
      style: base,
      inlineComponents: trailing == null
          ? null
          : [
              // First match wins, so the sentinel is checked before the
              // stock components and can't be reinterpreted as markup.
              _TrailingSentinel(trailing!),
              ...MarkdownComponent.inlineComponents,
            ],
      onLinkTap: (url, title) => _openLink(url),
      highlightBuilder: (context, inlineCode, style) =>
          _InlineCode(code: inlineCode, style: style),
      codeBuilder: (context, name, code, closed) =>
          _CodeBlock(language: name, code: code),
      // Tables are left to the package default, which already wraps them
      // in a horizontal scroll view — so a wide table never forces the
      // transcript itself to scroll sideways.
    );
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    // Model output is untrusted: only hand http(s) to the OS handler so a
    // hallucinated `file:` or custom-scheme link can't launch something
    // unexpected on the user's machine.
    if (uri == null) return;
    if (uri.scheme != 'http' && uri.scheme != 'https') return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// `inline code` — tinted chip that stays on the text baseline.
class _InlineCode extends StatelessWidget {
  const _InlineCode({required this.code, required this.style});

  final String code;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        code,
        style: style.copyWith(
          fontFamily: 'monospace',
          fontSize: (style.fontSize ?? 14) * 0.92,
        ),
      ),
    );
  }
}

/// Fenced code block with a language label and a copy affordance.
///
/// Horizontally scrollable rather than wrapped: wrapped code is
/// misleading, since a soft-wrapped line reads as two statements.
class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.language, required this.code});

  final String language;
  final String code;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mono = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      color: scheme.onSurface,
      height: 1.4,
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.06),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.10)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header only earns its vertical space when there's a language
          // to label; a bare fence gets the copy button alone.
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 4, 0),
            child: Row(
              children: [
                Text(
                  language.isEmpty ? '' : language,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                _CopyButton(code: code),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(code, style: mono),
            ),
          ),
        ],
      ),
    );
  }
}

/// Copy-to-clipboard button that confirms in place by swapping to a
/// check for a beat — a SnackBar would be heavy for something this small
/// and would cover the composer.
class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.code});

  final String code;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      iconSize: 14,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(),
      visualDensity: VisualDensity.compact,
      tooltip: _copied ? 'Copied' : 'Copy code',
      icon: Icon(
        _copied ? Icons.check : Icons.copy_outlined,
        color: _copied ? context.kwaai.accentPrimary : scheme.onSurfaceVariant,
      ),
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: widget.code));
        if (!context.mounted) return;
        setState(() => _copied = true);
        await Future<void>.delayed(const Duration(seconds: 2));
        // The widget can be disposed while the confirmation is showing —
        // a long response can rebuild the transcript out from under it.
        if (!mounted) return;
        setState(() => _copied = false);
      },
    );
  }
}
