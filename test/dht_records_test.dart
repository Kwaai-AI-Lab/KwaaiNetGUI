import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/chat/generated/kwaai.pb.dart' as pb;
import 'package:kwaainet_gui/src/chat/kwaai_rpc_client.dart';
import 'package:kwaainet_gui/src/chat/session_client.dart';
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

pb.DhtValueView _value(String rendered) => pb.DhtValueView()
  ..msgpackType = 'map'
  ..rendered = rendered
  ..rawBytes = Int64(rendered.length)
  ..decoded = true;

pb.DhtLookupPeer _peer(String id, pb.DhtLookupOutcome outcome) =>
    pb.DhtLookupPeer()
      ..peerId = id
      ..outcome = outcome
      ..elapsedMs = 12;

/// Answers the detail and lookup requests from canned replies, and counts
/// them. Closed at birth: that stops the probe loop (a pending timer fails a
/// widget test) and nothing here reaches the session.
class _FakeClient extends KwaaiRpcClient {
  _FakeClient({required this.detail, required this.lookup}) {
    close();
  }

  final pb.DhtRecordsReply detail;
  final pb.DhtLookupReply lookup;

  /// Thrown instead of [lookup] when set — e.g. a daemon-side CANCELLED.
  Object? lookupError;
  int detailCalls = 0;
  int lookupCalls = 0;

  @override
  Future<pb.DhtRecordsReply> dhtRecords({
    bool includeValues = false,
    List<String> keyIds = const [],
  }) async {
    detailCalls++;
    return detail;
  }

  @override
  Future<pb.DhtLookupReply> dhtLookup(
    String key, {
    int timeoutSecs = 0,
    required void Function(int? operationId) onOperationId,
  }) async {
    lookupCalls++;
    onOperationId(7);
    if (lookupError != null) throw lookupError!;
    return lookup;
  }
}

/// A named regular record with a value, and a lookup where one peer found
/// it, one did not, and one never answered.
_FakeClient _fakeClient({pb.DhtRecord? detailRecord}) {
  final record =
      detailRecord ??
      (_record(keyId: 'ff01', keyName: '_petals.models')
        ..value = _value('{"llama": 32}'));
  final client = _FakeClient(
    detail: _reply([record]),
    lookup: pb.DhtLookupReply()
      ..key = '_petals.models'
      ..keyId = 'ff01'
      ..peers.addAll([
        _peer('12D3KooWFoundPeer', pb.DhtLookupOutcome.DHT_LOOKUP_OUTCOME_FOUND)
          ..record = record,
        _peer(
          '12D3KooWMissingPeer',
          pb.DhtLookupOutcome.DHT_LOOKUP_OUTCOME_NOT_FOUND,
        ),
        _peer('12D3KooWDeadPeer', pb.DhtLookupOutcome.DHT_LOOKUP_OUTCOME_ERROR)
          ..error = 'dial timed out',
      ])
      ..record = record,
  );
  return client;
}

/// Counts how many times the listing was (re)requested, and can make every
/// request after the first fail.
class _Listing {
  int requests = 0;
  Object? errorAfterFirst;
}

Widget _host(
  pb.DhtRecordsReply reply, {
  _Listing? listing,
  _FakeClient? client,
  bool connected = true,
  double width = 1100,
}) => ProviderScope(
  overrides: [
    dhtRecordsProvider.overrideWith((ref) {
      final n = ++(listing ?? _Listing()).requests;
      final err = listing?.errorAfterFirst;
      return n > 1 && err != null ? Stream.error(err) : Stream.value(reply);
    }),
    kwaaiRpcConnectionProvider.overrideWith(
      (ref) => Stream.value(
        connected ? RpcConnection.connected : RpcConnection.disconnected,
      ),
    ),
    kwaaiRpcClientProvider.overrideWithValue(client ?? _fakeClient()),
  ],
  child: MaterialApp(
    theme: buildKwaaiTheme(ThemeVariantKey.kwaai, Brightness.dark),
    home: Scaffold(
      body: SizedBox(width: width, height: 800, child: const DhtTab()),
    ),
  ),
);

pb.DhtRecord _named() => _record(keyId: 'ff01', keyName: '_petals.models');

Finder _textWith(String fragment) => find.byWidgetPredicate(
  (w) => w is Text && (w.data ?? '').contains(fragment),
);

final _refresh = find.widgetWithIcon(IconButton, Icons.refresh);

bool _refreshEnabled(WidgetTester tester) =>
    tester.widget<IconButton>(_refresh).onPressed != null;

Future<void> _runLookup(WidgetTester tester) async {
  await tester.tap(find.text('Lookup'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), '_petals.models');
  await tester.tap(find.text('Look up'));
  await tester.pumpAndSettle();
}

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

  test('expiryLine reads as a sentence either side of now', () {
    expect(expiryLine(240), 'Expires in 4m');
    expect(expiryLine(-90), 'Expired 1m ago');
  });

  test('previewOf bounds what the inline preview lays out', () {
    final long = 'x' * (kValuePreviewChars + 10);
    expect(previewOf('short'), 'short');
    expect(previewOf(long).length, kValuePreviewChars + 1);
    expect(previewOf(long).endsWith('…'), isTrue);
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
      // The note must not call a cut-short listing complete.
      expect(_textWith('true answer about this node'), findsOneWidget);
      expect(_textWith('complete answer'), findsNothing);
    });

    testWidgets('claims no truncation when the listing is whole', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_reply([_record(keyId: 'ff01')])));
      await tester.pumpAndSettle();

      expect(_textWith('cut short'), findsNothing);
      expect(_textWith('1 records · '), findsOneWidget);
      expect(_textWith('true and complete answer'), findsOneWidget);
    });

    testWidgets('marks an expired record in the table and the detail', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          _reply([_named()..expiresInSecs = -90]),
          client: _fakeClient(detailRecord: _named()..expiresInSecs = -90),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('expired 1m ago'), findsOneWidget);

      await tester.tap(find.text('_petals.models'));
      await tester.pumpAndSettle();
      expect(_textWith('Expired 1m ago ('), findsOneWidget);
      expect(_textWith('Expires expired'), findsNothing);
    });

    testWidgets('labels an undecoded value opaque in panel and dialog', (
      tester,
    ) async {
      final blob = _value('hex:deadbeef')..decoded = false;
      await tester.pumpWidget(
        _host(
          _reply([_named()]),
          client: _fakeClient(detailRecord: _named()..value = blob),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('_petals.models'));
      await tester.pumpAndSettle();
      expect(find.text('opaque — shown as hex'), findsOneWidget);

      await tester.tap(find.byTooltip('Open value'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: _textWith('not decoded, shown as hex'),
        ),
        findsOneWidget,
      );
    });
  });

  group('stale listing', () {
    testWidgets('a failed refresh keeps the rows but says so', (tester) async {
      final listing = _Listing()
        ..errorAfterFirst = SessionOpError(
          code: 6,
          message: 'dht_records is not available on this p2p backend',
        );
      await tester.pumpWidget(_host(_reply([_named()]), listing: listing));
      await tester.pumpAndSettle();
      expect(_textWith('The last refresh failed'), findsNothing);

      await tester.tap(_refresh);
      await tester.pumpAndSettle();
      expect(listing.requests, 2);
      expect(find.text('_petals.models'), findsOneWidget);
      expect(_textWith('The last refresh failed'), findsOneWidget);
      expect(_textWith('showing the listing from'), findsOneWidget);
    });

    testWidgets('a lost daemon is said, not implied by silence', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_reply([_named()]), connected: false));
      await tester.pumpAndSettle();
      expect(find.text('_petals.models'), findsOneWidget);
      expect(_textWith('The daemon is unreachable'), findsOneWidget);
    });
  });

  group('modes', () {
    testWidgets('switching swaps the bands and clears the selection', (
      tester,
    ) async {
      final client = _fakeClient();
      final listing = _Listing();
      await tester.pumpWidget(
        _host(_reply([_named()]), listing: listing, client: client),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('_petals.models'));
      await tester.pumpAndSettle();
      expect(find.text('{"llama": 32}'), findsOneWidget);

      await tester.tap(find.text('Lookup'));
      await tester.pumpAndSettle();
      // Band 1 is now the lookup fields, band 2 has no table yet, and the
      // detail panel is gone. Nothing was requested by the switch itself.
      expect(_textWith('The local store is the only thing'), findsNothing);
      expect(find.text('Look up'), findsOneWidget);
      expect(find.text('KEY'), findsNothing);
      expect(find.text('{"llama": 32}'), findsNothing);
      expect(client.detailCalls, 1);
      expect(client.lookupCalls, 0);
      expect(listing.requests, 1);

      await tester.tap(find.text('Local'));
      await tester.pumpAndSettle();
      expect(_textWith('The local store is the only thing'), findsOneWidget);
      expect(find.text('KEY'), findsOneWidget);
      expect(find.text('{"llama": 32}'), findsNothing);
      expect(listing.requests, 1);
    });

    testWidgets('lookup fills one table with all three outcomes', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(_reply([_record(keyId: 'ff01')]), client: _fakeClient()),
      );
      await tester.pumpAndSettle();
      await _runLookup(tester);

      expect(find.text('found'), findsOneWidget);
      expect(find.text('not found'), findsOneWidget);
      expect(find.text('no answer'), findsOneWidget);
      expect(find.text('dial timed out'), findsOneWidget);
      expect(find.text('freshest answer'), findsOneWidget);
      expect(_textWith('1 found · 1 not found · 1 no answer'), findsOneWidget);

      await tester.tap(find.text('found'));
      await tester.pumpAndSettle();
      expect(find.text('{"llama": 32}'), findsOneWidget);

      await tester.tap(find.text('no answer'));
      await tester.pumpAndSettle();
      expect(find.text('{"llama": 32}'), findsNothing);
      expect(
        _textWith('No answer from this peer: dial timed out'),
        findsOneWidget,
      );
    });

    // `in_cache` is meaningless in a lookup reply; nothing was stored here.
    testWidgets('a lookup answer claims no tier', (tester) async {
      await tester.pumpWidget(_host(_reply([_record(keyId: 'ff01')])));
      await tester.pumpAndSettle();
      await _runLookup(tester);
      await tester.tap(find.text('found'));
      await tester.pumpAndSettle();
      expect(_textWith('· primary'), findsNothing);
      expect(_textWith('value · 2.0 KB'), findsOneWidget);
    });

    testWidgets('a lookup answer without subkey values says so', (
      tester,
    ) async {
      final client = _fakeClient(
        detailRecord: _record(
          keyId: 'ff02',
          keyName: '_petals.models',
          kind: pb.DhtRecordKind.DHT_RECORD_KIND_DICTIONARY,
          subkeyCount: 3,
        ),
      );
      await tester.pumpWidget(
        _host(_reply([_record(keyId: 'ff02')]), client: client),
      );
      await tester.pumpAndSettle();
      await _runLookup(tester);
      await tester.tap(find.text('found'));
      await tester.pumpAndSettle();
      expect(_textWith('did not include its 3 subkey values'), findsOneWidget);
      expect(_textWith('holds no subkeys'), findsNothing);
    });

    testWidgets('a cancelled lookup is not an error', (tester) async {
      final client = _fakeClient()
        ..lookupError = SessionOpError(code: 4, message: 'cancelled');
      await tester.pumpWidget(
        _host(_reply([_record(keyId: 'ff01')]), client: client),
      );
      await tester.pumpAndSettle();
      await _runLookup(tester);
      expect(find.text('Lookup cancelled.'), findsOneWidget);
      expect(find.text('cancelled'), findsNothing);
      expect(_refreshEnabled(tester), isTrue);
    });

    testWidgets('band 1 fits a 560px window', (tester) async {
      await tester.pumpWidget(
        _host(_reply([_record(keyId: 'ff01')]), width: 560),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Lookup'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Look up'), findsOneWidget);
    });
  });

  group('refresh', () {
    testWidgets('re-requests the listing and clears the selection', (
      tester,
    ) async {
      final reply = _reply([_named()]);
      final listing = _Listing();
      await tester.pumpWidget(
        _host(reply, listing: listing, client: _fakeClient()),
      );
      await tester.pumpAndSettle();
      expect(listing.requests, 1);

      await tester.tap(find.text('_petals.models'));
      await tester.pumpAndSettle();
      expect(find.text('{"llama": 32}'), findsOneWidget);

      await tester.tap(_refresh);
      await tester.pumpAndSettle();
      expect(listing.requests, 2);
      expect(find.text('{"llama": 32}'), findsNothing);
      expect(find.text('_petals.models'), findsOneWidget);
    });

    testWidgets('is disabled in Lookup mode until a lookup has run', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_reply([_record(keyId: 'ff01')])));
      await tester.pumpAndSettle();
      expect(_refreshEnabled(tester), isTrue);

      await tester.tap(find.text('Lookup'));
      await tester.pumpAndSettle();
      expect(_refreshEnabled(tester), isFalse);
    });

    testWidgets('re-runs the last lookup and clears the selection', (
      tester,
    ) async {
      final client = _fakeClient();
      await tester.pumpWidget(
        _host(_reply([_record(keyId: 'ff01')]), client: client),
      );
      await tester.pumpAndSettle();
      await _runLookup(tester);
      expect(client.lookupCalls, 1);
      expect(_refreshEnabled(tester), isTrue);

      await tester.tap(find.text('found'));
      await tester.pumpAndSettle();
      expect(find.text('{"llama": 32}'), findsOneWidget);

      await tester.tap(_refresh);
      await tester.pumpAndSettle();
      expect(client.lookupCalls, 2);
      expect(find.text('{"llama": 32}'), findsNothing);
      expect(find.text('found'), findsOneWidget);
    });
  });

  group('value dialog', () {
    testWidgets('shows the whole rendered value', (tester) async {
      final long = '{"x": "${'y' * 400}"}';
      final client = _fakeClient(
        detailRecord: _record(keyId: 'ff01', keyName: '_petals.models')
          ..value = _value(long),
      );
      await tester.pumpWidget(
        _host(
          _reply([_record(keyId: 'ff01', keyName: '_petals.models')]),
          client: client,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('_petals.models'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Open value'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(
        find.descendant(of: find.byType(Dialog), matching: find.text(long)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: _textWith('msgpack map'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('titles a subkey value with the subkey', (tester) async {
      final client = _fakeClient(
        detailRecord:
            _record(
                keyId: 'ff02',
                keyName: 'Llama.0',
                kind: pb.DhtRecordKind.DHT_RECORD_KIND_DICTIONARY,
                subkeyCount: 1,
              )
              ..subkeys.add(
                pb.DhtSubkey()
                  ..subkey = '12D3KooWServer'
                  ..expiresInSecs = 60
                  ..valueBytes = Int64(9)
                  ..value = _value('[1, 2, 3]'),
              ),
      );
      await tester.pumpWidget(
        _host(
          _reply([
            _record(
              keyId: 'ff02',
              keyName: 'Llama.0',
              kind: pb.DhtRecordKind.DHT_RECORD_KIND_DICTIONARY,
              subkeyCount: 1,
            ),
          ]),
          client: client,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Llama.0'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Open value'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Llama.0 · 12D3KooWServer'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('[1, 2, 3]'),
        ),
        findsOneWidget,
      );
    });
  });
}
