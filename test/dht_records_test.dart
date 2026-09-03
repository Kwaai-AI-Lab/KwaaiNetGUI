import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/chat/generated/kwaai.pb.dart' as pb;
import 'package:kwaainet_gui/src/daemon/dht_state.dart';
import 'package:kwaainet_gui/src/ui/pages/dht_tab.dart';
import 'package:kwaainet_gui/src/ui/theme/theme_variants.dart';

pb.DhtRecord _record({
  required String keyId,
  String keyName = '',
  bool inCache = false,
  pb.DhtRecordKind kind = pb.DhtRecordKind.DHT_RECORD_KIND_REGULAR,
  int subkeyCount = 0,
  double expiresInSecs = 300,
}) => pb.DhtRecord()
  ..keyId = keyId
  ..keyName = keyName
  ..inCache = inCache
  ..kind = kind
  ..subkeyCount = subkeyCount
  ..valueBytes = Int64(2048)
  ..expiration = 1756900000
  ..expiresInSecs = expiresInSecs;

pb.DhtRecordsReply _reply(List<pb.DhtRecord> records, {int? totalRecords}) =>
    pb.DhtRecordsReply()
      ..serverTime = '2026-09-03T12:00:00Z'
      ..records.addAll(records)
      ..totalRecords = totalRecords ?? records.length
      ..knownKeys.add(
        pb.DhtKnownKey()
          ..name = '_petals.models'
          ..keyId = 'aa11',
      );

Widget _host(pb.DhtRecordsReply reply) => ProviderScope(
  overrides: [dhtRecordsProvider.overrideWith((ref) => Stream.value(reply))],
  child: MaterialApp(
    theme: buildKwaaiTheme(ThemeVariantKey.kwaai, Brightness.dark),
    home: const Scaffold(
      body: SizedBox(width: 1100, height: 800, child: DhtTab()),
    ),
  ),
);

Finder _textWith(String fragment) => find.byWidgetPredicate(
  (w) => w is Text && (w.data ?? '').contains(fragment),
);

void main() {
  group('formatExpiry', () {
    test('counts down in the largest useful unit', () {
      expect(formatExpiry(45), 'in 45s');
      expect(formatExpiry(240), 'in 4m');
      expect(formatExpiry(7200), 'in 2h');
      expect(formatExpiry(172800), 'in 2d');
    });

    // A lookup answer carries the answering peer's clock, and a dictionary
    // keeps subkeys past their expiration.
    test('reads an expired record as expired, not as a negative countdown', () {
      expect(formatExpiry(-90), 'expired 1m ago');
    });
  });

  group('recordLabel', () {
    test('prefers the plaintext name', () {
      expect(
        recordLabel(_record(keyId: 'ab' * 20, keyName: '_petals.models')),
        '_petals.models',
      );
    });

    // A DHT id is SHA1(msgpack(name)) and cannot be inverted, so an unnamed
    // record has nothing to show but its id.
    test('falls back to a shortened id when the node cannot name the key', () {
      expect(recordLabel(_record(keyId: 'ab' * 20)), 'abababababababab…');
    });
  });

  test('a key in both tiers is two records, not one duplicate', () {
    final primary = _record(keyId: 'ff01');
    final cached = _record(keyId: 'ff01', inCache: true);
    expect(
      recordSelectionKey(primary),
      isNot(equals(recordSelectionKey(cached))),
    );
  });

  group('DhtTab', () {
    testWidgets('says the listing is this node only', (tester) async {
      await tester.pumpWidget(_host(_reply([_record(keyId: 'ff01')])));
      await tester.pumpAndSettle();

      expect(_textWith('The local store is the only thing'), findsOneWidget);
      expect(_textWith('says nothing about the network'), findsOneWidget);
    });

    testWidgets('lists both tiers of a key held twice', (tester) async {
      await tester.pumpWidget(
        _host(
          _reply([
            _record(keyId: 'ff01', keyName: '_petals.models'),
            _record(keyId: 'ff01', keyName: '_petals.models', inCache: true),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('_petals.models'), findsNWidgets(2));
      expect(find.text('primary'), findsOneWidget);
      expect(find.text('cache'), findsOneWidget);
    });

    // `subkey_count` says nothing about what a record is: it is 0 for every
    // regular value, so `kind` is the discriminator.
    testWidgets('distinguishes an empty dictionary from a value', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          _reply([
            _record(keyId: 'ff01'),
            _record(
              keyId: 'ff02',
              kind: pb.DhtRecordKind.DHT_RECORD_KIND_DICTIONARY,
            ),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('value'), findsOneWidget);
      expect(find.text('dictionary'), findsOneWidget);
      // The value's subkey cell is blank; the dictionary's is a real zero.
      expect(find.text('—'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('says so when the listing was cut short', (tester) async {
      await tester.pumpWidget(
        _host(_reply([_record(keyId: 'ff01')], totalRecords: 812)),
      );
      await tester.pumpAndSettle();

      expect(_textWith('Showing 1 of 812 records'), findsOneWidget);
      expect(_textWith('1 of 812 records · '), findsOneWidget);
    });

    testWidgets('claims no truncation when the listing is whole', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_reply([_record(keyId: 'ff01')])));
      await tester.pumpAndSettle();

      expect(_textWith('cut short'), findsNothing);
      expect(_textWith('1 records · '), findsOneWidget);
    });
  });
}
