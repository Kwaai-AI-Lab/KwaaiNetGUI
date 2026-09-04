import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/chat/generated/kwaai.pb.dart' as pb;
import 'package:kwaainet_gui/src/chat/generated/kwaai.pbenum.dart' as pbenum;
import 'package:kwaainet_gui/src/daemon/peers_state.dart';
import 'package:kwaainet_gui/src/ui/pages/peers_tab.dart';
import 'package:kwaainet_gui/src/ui/theme/theme_variants.dart';

Widget _host(String ipv6) {
  final update = pb.NetworkUpdate()
    ..serverTime = '2026-08-01T12:00:00Z'
    ..reason = pbenum.UpdateReason.UPDATE_REASON_PEERS
    ..selfStatus = (pb.SelfStatus()
      ..peerId = '12D3KooWSelfExamplePeerIdentifier'
      ..reachability = 'public'
      ..reachabilitySource = 'autonat'
      ..announceable = true
      ..ipv6 = ipv6);
  return ProviderScope(
    overrides: [peersProvider.overrideWith((ref) => Stream.value(update))],
    child: MaterialApp(
      theme: buildKwaaiTheme(ThemeVariantKey.kwaai, Brightness.dark),
      home: const Scaffold(
        body: SizedBox(width: 900, height: 700, child: PeersTab()),
      ),
    ),
  );
}

/// `SelfStatus.ipv6` arrives as a string, and one of its values is "the
/// daemon never said" — an older daemon leaves the field unset, which reaches
/// the GUI as ''. That has to render like an explicit "off", because a chip
/// would be a claim about something never reported.
void main() {
  group('ipv6Chip', () {
    test('says nothing when IPv6 is off or unreported', () {
      expect(ipv6Chip(''), isNull);
      expect(ipv6Chip('off'), isNull);
    });

    test('an active listener is a plain running-tint chip', () {
      final chip = ipv6Chip('active');
      expect(chip?.label, 'IPv6');
      expect(chip?.warn, isFalse);
    });

    test('an unmet request warns', () {
      // The one state worth interrupting for: the user asked for IPv6 and the
      // daemon is running without it.
      final chip = ipv6Chip('unavailable');
      expect(chip?.label, 'IPv6 unavailable');
      expect(chip?.warn, isTrue);
    });

    test('an unrecognised value renders nothing rather than guessing', () {
      expect(ipv6Chip('enabled'), isNull);
      expect(ipv6Chip('ACTIVE'), isNull);
      expect(ipv6Chip('true'), isNull);
    });
  });

  group('the header chip', () {
    testWidgets('appears beside the reachability badge when active', (
      tester,
    ) async {
      await tester.pumpWidget(_host('active'));
      await tester.pump();
      expect(find.text('IPv6'), findsOneWidget);
      expect(find.text('Public · via autonat'), findsOneWidget);
    });

    testWidgets('an older daemon sending no value adds nothing', (
      tester,
    ) async {
      await tester.pumpWidget(_host(''));
      await tester.pump();
      expect(find.textContaining('IPv6'), findsNothing);
    });

    testWidgets('an unmet request is spelled out', (tester) async {
      await tester.pumpWidget(_host('unavailable'));
      await tester.pump();
      expect(find.text('IPv6 unavailable'), findsOneWidget);
    });
  });
}
