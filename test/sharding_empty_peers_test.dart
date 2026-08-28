import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/chat/generated/kwaai.pb.dart' as pb;
import 'package:kwaainet_gui/src/daemon/block_coverage_state.dart';
import 'package:kwaainet_gui/src/ui/pages/sharding_tab.dart';
import 'package:kwaainet_gui/src/ui/theme/theme_variants.dart';

pb.BlockPeer _peer(String id, int start, int end) => pb.BlockPeer()
  ..peerId = id
  ..startBlock = start
  ..endBlock = end
  ..publicName = '$id@nat-test';

/// [empty] peers announcing the placeholder `[0, 1)` range a node that
/// never loaded a shard publishes, plus [serving] real 8-block servers.
pb.BlockCoverageUpdate _update({int empty = 8, int serving = 0}) =>
    pb.BlockCoverageUpdate()
      ..serverTime = '2026-08-27T12:00:00Z'
      ..model = 'unsloth/Llama-3.1-8B-Instruct'
      ..dhtPrefix = 'Llama-3-1-8B-Instruct'
      ..totalBlocks = 32
      ..peers.addAll([
        for (var i = 0; i < empty; i++)
          _peer('12D3KooWEmptyPeerNumber${i}xxxxxxxxxxxxxxxxxxxx', 0, 1),
        for (var i = 0; i < serving; i++)
          _peer(
            '12D3KooWServingPeerNumber${i}xxxxxxxxxxxxxxxxxxx',
            i * 8,
            i * 8 + 8,
          ),
      ]);

Widget _host(pb.BlockCoverageUpdate update) => ProviderScope(
  overrides: [
    blockCoverageProvider.overrideWith((ref) => Stream.value(update)),
  ],
  child: MaterialApp(
    theme: buildKwaaiTheme(ThemeVariantKey.kwaai, Brightness.dark),
    home: const Scaffold(
      body: SizedBox(width: 1100, height: 700, child: ShardingTab()),
    ),
  ),
);

Finder _textWith(String fragment) => find.byWidgetPredicate(
  (w) => w is Text && (w.data ?? '').contains(fragment),
);

void main() {
  group('isEmptyPeer', () {
    test('flags a range one block wide or narrower', () {
      expect(isEmptyPeer(_peer('p', 0, 1)), isTrue);
      expect(isEmptyPeer(_peer('p', 0, 0)), isTrue);
      expect(isEmptyPeer(_peer('p', 4, 4)), isTrue);
    });

    test('passes any real assignment', () {
      // The narrowest value in VALID_BLOCK_COUNTS is 4.
      expect(isEmptyPeer(_peer('p', 0, 4)), isFalse);
      expect(isEmptyPeer(_peer('p', 24, 32)), isFalse);
    });
  });

  group('empty peers', () {
    testWidgets('are not counted as coverage', (tester) async {
      await tester.pumpWidget(_host(_update()));
      await tester.pumpAndSettle();

      // The bug this filter fixes: eight peers announcing [0, 1) painted
      // block 0 green and claimed a block nothing serves.
      expect(_textWith('0/32 blocks covered, 0 peer(s)'), findsOneWidget);
    });

    testWidgets('are hidden from the table, with the count shown', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_update()));
      await tester.pumpAndSettle();

      expect(find.text('Show empty peers'), findsOneWidget);
      expect(_textWith('8 empty hidden'), findsOneWidget);
      expect(_textWith('EmptyPeerNumber'), findsNothing);
    });

    testWidgets('come back, and count, once the box is ticked', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_update()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show empty peers'));
      await tester.pumpAndSettle();

      expect(_textWith('EmptyPeerNumber'), findsWidgets);
      expect(_textWith('1/32 blocks covered, 8 peer(s)'), findsOneWidget);
      expect(_textWith('empty hidden'), findsNothing);
    });

    testWidgets('leave real servers alone', (tester) async {
      await tester.pumpWidget(_host(_update(empty: 2, serving: 4)));
      await tester.pumpAndSettle();

      expect(_textWith('32/32 blocks'), findsOneWidget);
      expect(_textWith('4 peer(s)'), findsOneWidget);
    });

    testWidgets('offer no toggle when the network has none', (tester) async {
      await tester.pumpWidget(_host(_update(empty: 0, serving: 4)));
      await tester.pumpAndSettle();

      expect(find.text('Show empty peers'), findsNothing);
    });
  });
}
