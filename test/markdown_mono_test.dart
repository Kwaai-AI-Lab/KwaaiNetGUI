import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/ui/theme/kwaai_theme.dart';
import 'package:kwaainet_gui/src/ui/theme/theme_variants.dart';
import 'package:kwaainet_gui/src/ui/widgets/kwaai_markdown_body.dart';

/// Code in assistant output has to render fixed-width, or Python
/// indentation, ASCII tables, and aligned columns all read wrong.
///
/// The trap here is that `fontFamily: 'monospace'` *looks* like it says
/// so while doing nothing: Flutter's macOS engine resolves no such face
/// and silently falls back to the proportional UI font. Measured in a
/// real macOS window at 14px, `'monospace'` lays out "iii" at 10.4px and
/// "mmm" at 36.5px — exactly the default face — where `'Menlo'` gives
/// both 25.3px.
///
/// So these tests assert the *style* the widget builds rather than
/// measuring glyph widths. `flutter test` renders in Ahem, whose glyphs
/// are uniform by construction, so a width-based check reports
/// fixed-width for every family including the proportional default — it
/// would pass just as happily against the bug it is meant to catch.
Widget _host(Widget child) => MaterialApp(
  theme: buildKwaaiTheme(ThemeVariantKey.kwaai, Brightness.dark),
  home: Scaffold(body: SizedBox(width: 600, child: child)),
);

/// Styles of every widget in the tree whose text contains [needle].
///
/// Scans the whole tree rather than using `find.textContaining` because
/// gpt_markdown renders the three cases through different widgets:
/// prose becomes a bare [RichText], inline code a [Text], and a fenced
/// block a [SelectableText] whose data spans newlines. Matching on the
/// painted string covers all three without encoding that layout.
Iterable<TextStyle> _stylesFor(WidgetTester tester, String needle) {
  final styles = <TextStyle>[];
  for (final w in tester.allWidgets) {
    if (w is Text && (w.data ?? '').contains(needle) && w.style != null) {
      styles.add(w.style!);
    }
    if (w is SelectableText &&
        (w.data ?? '').contains(needle) &&
        w.style != null) {
      styles.add(w.style!);
    }
    if (w is RichText && w.text.toPlainText().contains(needle)) {
      final s = (w.text as TextSpan).style;
      if (s != null) styles.add(s);
    }
  }
  return styles;
}

void _expectMono(TextStyle style, String where) {
  expect(style.fontFamily, kwaaiMonoFamily, reason: '$where: wrong family');
  // The fallbacks are the whole point on non-macOS hosts — Menlo alone
  // renders proportionally anywhere it is absent, which is the same bug
  // one platform over.
  expect(
    style.fontFamilyFallback,
    containsAllInOrder(kwaaiMonoFallback),
    reason: '$where: missing platform fallbacks',
  );
}

void main() {
  test('the generic alias is never used as the family', () {
    // Guards the constant itself: 'monospace' is only ever valid as a
    // trailing fallback, never as the primary family.
    expect(kwaaiMonoFamily, isNot('monospace'));
    expect(kwaaiMonoFallback.last, 'monospace');
  });

  testWidgets('fenced code blocks render fixed-width', (tester) async {
    await tester.pumpWidget(
      _host(const KwaaiMarkdownBody(text: '```python\nx = 1\n```')),
    );
    await tester.pumpAndSettle();

    final styles = _stylesFor(tester, 'x = 1');
    expect(styles, isNotEmpty, reason: 'code block did not render');
    for (final s in styles) {
      _expectMono(s, 'code block');
    }
  });

  testWidgets('inline code renders fixed-width', (tester) async {
    await tester.pumpWidget(
      _host(const KwaaiMarkdownBody(text: 'call `np.linspace(0, 10)` here')),
    );
    await tester.pumpAndSettle();

    final styles = _stylesFor(tester, 'np.linspace');
    expect(styles, isNotEmpty, reason: 'inline code did not render');
    for (final s in styles) {
      _expectMono(s, 'inline code');
    }
  });

  testWidgets('prose around code keeps the proportional UI font',
      (tester) async {
    // The fix is scoped to code: widening it to the whole body would
    // render ordinary paragraphs in Menlo.
    await tester.pumpWidget(
      _host(const KwaaiMarkdownBody(text: 'ordinary paragraph text')),
    );
    await tester.pumpAndSettle();

    final styles = _stylesFor(tester, 'ordinary');
    expect(styles, isNotEmpty, reason: 'paragraph did not render');
    for (final s in styles) {
      expect(s.fontFamily, isNot(kwaaiMonoFamily), reason: 'prose went mono');
    }
  });
}
