import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/daemon/bootstrap_health.dart';
import 'package:kwaainet_gui/src/ui/theme/theme_variants.dart';
import 'package:kwaainet_gui/src/ui/widgets/bootstrap_down_banner.dart';

Widget _host(BootstrapHealth? health) {
  return ProviderScope(
    overrides: [
      bootstrapHealthProvider.overrideWith((ref) => Stream.value(health)),
    ],
    child: MaterialApp(
      theme: buildKwaaiTheme(ThemeVariantKey.kwaai, Brightness.light),
      // Same shape as the real mount in main.dart: above the Navigator
      // there is no Scaffold, only the Material wrapper.
      builder: (context, child) => Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: const BootstrapDownBanner(),
      ),
      home: const SizedBox.shrink(),
    ),
  );
}

void main() {
  testWidgets('renders the red bar with counts when bootstraps are down', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const BootstrapHealth(
          total: 2,
          reachable: 0,
          downFor: Duration(minutes: 2),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.textContaining('0 of 2 bootstrap peers reachable'),
      findsOneWidget,
    );
  });

  testWidgets('collapses to nothing while healthy', (tester) async {
    await tester.pumpWidget(
      _host(const BootstrapHealth(total: 2, reachable: 2)),
    );
    await tester.pump();
    expect(find.textContaining('bootstrap'), findsNothing);
  });

  testWidgets('collapses while inside the startup grace period', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const BootstrapHealth(
          total: 2,
          reachable: 0,
          downFor: Duration(seconds: 5),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('bootstrap'), findsNothing);
  });
}
