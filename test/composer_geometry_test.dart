import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/ui/theme/theme_variants.dart';
import 'package:kwaainet_gui/src/ui/widgets/kwaai_chat_composer.dart';

/// The send/stop button should read as concentric with the composer
/// pill: an equal gap the whole way around the corner, not just at the
/// sides.
///
/// That holds only if the button's *rendered* box is the size we think
/// it is — Material's IconButton applies its own constraints and tap
/// target padding on top of `minimumSize`, so the maths is asserted
/// against real geometry rather than the declared values.
Widget _host({VoidCallback? onStop}) => MaterialApp(
  theme: buildKwaaiTheme(ThemeVariantKey.kwaai, Brightness.dark),
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 600,
        child: KwaaiChatComposer(
          controller: TextEditingController(),
          focusNode: FocusNode(),
          enabled: true,
          onSend: () {},
          onStop: onStop,
          hintText: 'Message kwaainet…',
        ),
      ),
    ),
  ),
);

/// The pill is the Container carrying the composer's rounded fill.
Finder _pill() => find.descendant(
  of: find.byType(KwaaiChatComposer),
  matching: find.byWidgetPredicate(
    (w) => w is Container && w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).borderRadius != null,
  ),
);

double _pillRadius(WidgetTester tester) {
  final container = tester.widget<Container>(_pill().first);
  final radius =
      (container.decoration as BoxDecoration).borderRadius as BorderRadius;
  return radius.topRight.x;
}

void main() {
  for (final streaming in [false, true]) {
    final label = streaming ? 'stop' : 'send';

    testWidgets('$label button is concentric with the composer pill',
        (tester) async {
      await tester.pumpWidget(_host(onStop: streaming ? () {} : null));
      await tester.pumpAndSettle();

      final button = find.descendant(
        of: find.byType(KwaaiChatComposer),
        matching: find.byIcon(
          streaming ? Icons.stop_rounded : Icons.arrow_upward,
        ),
      );
      expect(button, findsOneWidget);

      final pillRect = tester.getRect(_pill().first);
      // Measure the IconButton's own box, not the icon glyph's.
      final buttonRect = tester.getRect(
        find.ancestor(of: button, matching: find.byType(IconButton)).first,
      );

      final gapRight = pillRect.right - buttonRect.right;
      final gapTop = buttonRect.top - pillRect.top;
      final gapBottom = pillRect.bottom - buttonRect.bottom;

      // Equal on all three sides that touch the trailing corner — this
      // is what "concentric" means visually.
      expect(gapRight, moreOrLessEquals(gapTop, epsilon: 0.5),
          reason: 'right gap ($gapRight) should match top gap ($gapTop)');
      expect(gapBottom, moreOrLessEquals(gapTop, epsilon: 0.5),
          reason: 'bottom gap ($gapBottom) should match top gap ($gapTop)');

      // Concentric circles: outer radius - inner radius == the gap.
      final buttonRadius = buttonRect.height / 2;
      expect(_pillRadius(tester) - buttonRadius,
          moreOrLessEquals(gapTop, epsilon: 0.5),
          reason: 'pill radius minus button radius should equal the gap');
    });
  }

  testWidgets('swapping send for stop does not resize the pill',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    final idle = tester.getRect(_pill().first);

    await tester.pumpWidget(_host(onStop: () {}));
    await tester.pumpAndSettle();
    final streaming = tester.getRect(_pill().first);

    // The button swaps in place mid-stream; any size change here would
    // make the composer visibly jump on every send.
    expect(streaming.size, idle.size);
  });

  testWidgets('hint text is vertically centred in the pill',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    final pill = tester.getRect(_pill().first);
    final hint = tester.getRect(find.text('Message kwaainet…'));

    // The field's height is font-metric dependent and does not equal
    // the button diameter; the composer centres it in a min-height box
    // instead. If this drifts, the hint reads visibly high or low in
    // the pill (this regressed on macOS, where SF Pro's metrics differ
    // from the test font's — a symmetric result here is necessary but
    // not sufficient, so also eyeball a real build when touching this).
    expect(hint.top - pill.top,
        moreOrLessEquals(pill.bottom - hint.bottom, epsilon: 0.5),
        reason: 'hint should sit as far from the pill top as the bottom');
  });

  testWidgets('pill does not expand to fill a bounded-height parent',
      (tester) async {
    // Regression: the centring used a bare alignment, and Align fills
    // *bounded* height constraints — fine in the chat page's unbounded
    // Column, but ballooning the pill to the full height of any
    // fixed-height parent. heightFactor forces child-based sizing.
    await tester.pumpWidget(MaterialApp(
      theme: buildKwaaiTheme(ThemeVariantKey.kwaai, Brightness.dark),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 600,
            height: 400, // bounded, unlike the chat page
            child: Center(
              child: KwaaiChatComposer(
                controller: TextEditingController(),
                focusNode: FocusNode(),
                enabled: true,
                onSend: () {},
                hintText: 'Message kwaainet…',
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final pill = tester.getRect(_pill().first);
    expect(pill.height, lessThan(60),
        reason: 'a collapsed composer must stay one line tall even when '
            'its parent offers bounded height (got ${pill.height})');
  });
}
