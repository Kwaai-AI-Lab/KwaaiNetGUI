import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/ui/theme/theme_variants.dart';
import 'package:kwaainet_gui/src/ui/widgets/kwaai_dropdown.dart';

/// Re-picking the option a setting is already on is not an edit. Anything
/// that fires onChanged for it flags the setting dirty — in Settings, that
/// surfaces a "Restart the service" prompt for a change nobody made.
void main() {
  Widget host(String value, ValueChanged<String?> onChanged) => MaterialApp(
    theme: buildKwaaiTheme(ThemeVariantKey.native, Brightness.light),
    home: Scaffold(
      body: KwaaiDropdown<String>(
        value: value,
        onChanged: onChanged,
        items: const [
          KwaaiDropdownItem(value: 'a', label: 'Alpha'),
          KwaaiDropdownItem(value: 'b', label: 'Beta'),
        ],
      ),
    ),
  );

  Future<void> pick(WidgetTester tester, String label) async {
    await tester.tap(find.byType(KwaaiDropdown<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('dropdown: picking the selected item is a no-op', (tester) async {
    final picked = <String?>[];
    await tester.pumpWidget(host('a', picked.add));
    await pick(tester, 'Alpha');
    expect(picked, isEmpty);
  });

  testWidgets('dropdown: picking a different item still fires', (tester) async {
    final picked = <String?>[];
    await tester.pumpWidget(host('a', picked.add));
    await pick(tester, 'Beta');
    expect(picked, ['b']);
  });
}
