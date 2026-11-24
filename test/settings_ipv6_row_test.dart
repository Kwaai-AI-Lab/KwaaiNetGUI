import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/daemon/config_file.dart';
import 'package:kwaainet_gui/src/ui/pages/settings_page.dart';
import 'package:kwaainet_gui/src/ui/theme/theme_variants.dart';
import 'package:kwaainet_gui/src/ui/widgets/kwaai_dropdown.dart';

/// IPv6 is the one Reachability setting that is not a switch: "auto" has to
/// stay distinct from an explicit "off", so the row has to carry three
/// choices and report the one that was picked.
Widget _host(
  Ipv6Mode? value,
  ValueChanged<Ipv6Mode> onChanged, {
  VoidCallback? onReset,
  String? hintText,
}) {
  return MaterialApp(
    theme: buildKwaaiTheme(ThemeVariantKey.kwaai, Brightness.dark),
    home: Scaffold(
      body: ChoiceRow<Ipv6Mode>(
        label: 'IPv6',
        value: value,
        hintText: hintText,
        onReset: onReset,
        items: const [
          KwaaiDropdownItem(value: Ipv6Mode.auto, label: 'Automatic'),
          KwaaiDropdownItem(value: Ipv6Mode.on, label: 'Required'),
          KwaaiDropdownItem(value: Ipv6Mode.off, label: 'Off'),
        ],
        onChanged: onChanged,
      ),
    ),
  );
}

void main() {
  testWidgets('shows the label and the current mode', (tester) async {
    await tester.pumpWidget(_host(Ipv6Mode.auto, (_) {}));
    expect(find.text('IPv6'), findsOneWidget);
    expect(find.text('Automatic'), findsOneWidget);
  });

  testWidgets('offers all three modes once opened', (tester) async {
    await tester.pumpWidget(_host(Ipv6Mode.auto, (_) {}));
    await tester.tap(find.byType(KwaaiDropdown<Ipv6Mode>));
    await tester.pumpAndSettle();
    // The trigger keeps showing the selection, so "Automatic" is now twice.
    expect(find.text('Automatic'), findsNWidgets(2));
    expect(find.text('Required'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
  });

  testWidgets('reports the picked mode', (tester) async {
    final picked = <Ipv6Mode>[];
    await tester.pumpWidget(_host(Ipv6Mode.auto, picked.add));
    await tester.tap(find.byType(KwaaiDropdown<Ipv6Mode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Off'));
    await tester.pumpAndSettle();
    expect(picked, [Ipv6Mode.off]);
  });

  testWidgets('unset shows the default as a hint, with nothing to reset', (
    tester,
  ) async {
    await tester.pumpWidget(_host(null, (_) {}, hintText: 'Automatic'));
    expect(find.text('Automatic'), findsOneWidget);
    expect(find.byIcon(Icons.undo), findsNothing);
  });

  testWidgets('set offers a reset', (tester) async {
    var reset = false;
    await tester.pumpWidget(
      _host(Ipv6Mode.auto, (_) {}, onReset: () => reset = true),
    );
    await tester.tap(find.byIcon(Icons.undo));
    expect(reset, isTrue);
  });
}
