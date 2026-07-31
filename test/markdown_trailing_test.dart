import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/ui/theme/theme_variants.dart';
import 'package:kwaainet_gui/src/ui/widgets/kwaai_markdown_body.dart';

/// The streaming dots were originally an inline `WidgetSpan` and had to
/// stay that way through the markdown migration: when they were moved
/// to a row beneath the text they visibly dropped to their own line.
///
/// These tests assert the *geometry* rather than mere presence — a
/// trailing marker that renders but sits below the last line would pass
/// a `findsOneWidget` check while being exactly the bug in question.
Widget _host(Widget child) => MaterialApp(
  theme: buildKwaaiTheme(ThemeVariantKey.kwaai, Brightness.dark),
  home: Scaffold(
    // Roomy enough that a short paragraph stays on one line, so a
    // second line in the results means wrapping we didn't ask for.
    body: SizedBox(width: 600, child: child),
  ),
);

const _markerKey = Key('trailing-marker');

Widget _marker() => const SizedBox(key: _markerKey, width: 12, height: 8);

void main() {
  testWidgets('trailing marker sits on the last line, not below it',
      (tester) async {
    await tester.pumpWidget(
      _host(KwaaiMarkdownBody(text: 'Hello world', trailing: _marker())),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(_markerKey), findsOneWidget);

    final textRect = tester.getRect(find.textContaining('Hello').first);
    final markerRect = tester.getRect(find.byKey(_markerKey));

    // Inline means: to the right of where the text starts, and
    // vertically overlapping it — not stacked underneath.
    expect(markerRect.left, greaterThan(textRect.left));
    expect(markerRect.top, lessThan(textRect.bottom),
        reason: 'marker dropped below the final line of text');
  });

  testWidgets('marker trails the end of a multi-line paragraph',
      (tester) async {
    // Long enough to wrap, so this verifies the marker follows the
    // *last* line rather than being pinned after the first.
    const long =
        'While there is no definitive evidence of the existence of aliens, '
        'there are many reasons to believe that the possibility of life '
        'existing elsewhere in the universe is quite high, and this '
        'sentence is padded so it certainly wraps across several lines.';

    await tester.pumpWidget(
      _host(KwaaiMarkdownBody(text: long, trailing: _marker())),
    );
    await tester.pumpAndSettle();

    final textRect = tester.getRect(find.textContaining('aliens').first);
    final markerRect = tester.getRect(find.byKey(_markerKey));

    // Confirm the paragraph really did wrap, otherwise this test would
    // silently degrade into the single-line case above.
    expect(textRect.height, greaterThan(30),
        reason: 'test text should wrap onto multiple lines');

    // The marker belongs to the final line: its vertical centre sits in
    // the bottom portion of the paragraph's box, and it starts after
    // the left edge rather than beginning a fresh line.
    expect(markerRect.center.dy, greaterThan(textRect.center.dy),
        reason: 'marker should follow the last line, not an earlier one');
    expect(markerRect.top, lessThan(textRect.bottom),
        reason: 'marker dropped below the paragraph');
  });

  testWidgets('no sentinel leaks into the rendered text when trailing is null',
      (tester) async {
    await tester.pumpWidget(_host(const KwaaiMarkdownBody(text: 'Plain text')));
    await tester.pumpAndSettle();

    // The private-use sentinel must never be visible to the user.
    expect(find.textContaining(''), findsNothing);
    expect(find.byKey(_markerKey), findsNothing);
  });

  testWidgets('markdown formatting still renders around the marker',
      (tester) async {
    await tester.pumpWidget(
      _host(
        KwaaiMarkdownBody(
          text: '**Bold lead** and some trailing prose',
          trailing: _marker(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The sentinel sits directly against the final word, so this also
    // guards against it swallowing adjacent text or breaking the parse.
    expect(find.byKey(_markerKey), findsOneWidget);
    expect(find.textContaining('Bold lead'), findsWidgets);
    expect(find.textContaining('trailing prose'), findsWidgets);
  });

  testWidgets('unclosed markdown mid-stream still renders with a marker',
      (tester) async {
    // A realistic mid-stream snapshot: bold opened but not yet closed.
    await tester.pumpWidget(
      _host(
        KwaaiMarkdownBody(
          text: '1. **Arguments for the ex',
          trailing: _marker(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(_markerKey), findsOneWidget);
  });
}
