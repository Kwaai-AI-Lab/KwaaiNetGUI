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
import 'package:kwaainet_gui/src/ui/widgets/kwaai_dropdown.dart';

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
  pb.DhtLookupReply lookup;

  /// Thrown instead of [lookup] when set — e.g. a daemon-side CANCELLED.
  Object? lookupError;

  /// Returned by every lookup after the first, when set.
  pb.DhtLookupReply? lookupSecond;
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
    return lookupCalls > 1 ? lookupSecond ?? lookup : lookup;
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

final _peerPicker = find.byType(KwaaiDropdown<int>);

/// Picks a peer from the open dropdown by (shortened) id.
Future<void> _pickPeer(WidgetTester tester, String shortId) async {
  await tester.tap(_peerPicker);
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(KwaaiMenuSurface),
      matching: find.text(shortId),
    ),
  );
  await tester.pumpAndSettle();
}

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

  test(
    'subkeyLabel strips the quotes of a JSON string, else keeps the text',
    () {
      expect(subkeyLabel('"12D3KooWServer"'), '12D3KooWServer');
      expect(subkeyLabel('42'), '42');
      expect(subkeyLabel('hex:deadbeef'), 'hex:deadbeef');
    },
  );

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

    testWidgets('lists every peer asked in the picker, icon and RTT only', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_reply([_record(keyId: 'ff01')])));
      await tester.pumpAndSettle();
      await _runLookup(tester);

      expect(_textWith('1 found · 1 not found · 1 no answer'), findsOneWidget);
      // The collapsed field shows the selected (freshest) peer.
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);

      await tester.tap(_peerPicker);
      await tester.pumpAndSettle();
      final menu = find.byType(KwaaiMenuSurface);
      expect(
        find.descendant(of: menu, matching: find.byIcon(Icons.check_circle)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: menu,
          matching: find.byIcon(Icons.remove_circle_outline),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: menu, matching: find.byIcon(Icons.error_outline)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: menu, matching: find.byIcon(Icons.star)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: menu, matching: find.text('12 ms')),
        findsNWidgets(3),
      );
      expect(find.text('found'), findsNothing);
      expect(find.text('not found'), findsNothing);
      expect(find.text('no answer'), findsNothing);

      await tester.tap(
        find.descendant(of: menu, matching: find.text('12D3KooWDeadPeer')),
      );
      await tester.pumpAndSettle();
      expect(
        _textWith('No answer from this peer: dial timed out'),
        findsOneWidget,
      );
    });

    testWidgets('a refresh keeps the chosen peer while it still answers', (
      tester,
    ) async {
      pb.DhtLookupPeer found(String id) =>
          _peer(id, pb.DhtLookupOutcome.DHT_LOOKUP_OUTCOME_FOUND)
            ..record = (_named()..value = _value('{"from": "$id"}'));
      pb.DhtLookupReply reply(pb.DhtLookupPeer second) => pb.DhtLookupReply()
        ..key = '_petals.models'
        ..keyId = 'ff01'
        ..peers.addAll([found('12D3KooWFirstPeer'), second])
        ..record = found('x').record;
      final client = _fakeClient()
        ..lookup = reply(found('12D3KooWOtherPeer'))
        ..lookupSecond = reply(found('12D3KooWOtherPeer'));
      await tester.pumpWidget(
        _host(_reply([_record(keyId: 'ff01')]), client: client),
      );
      await tester.pumpAndSettle();
      await _runLookup(tester);
      expect(_textWith('ENTRIES — 12D3KooWFirstPee'), findsOneWidget);

      await _pickPeer(tester, '12D3KooWOtherPee…');
      expect(_textWith('ENTRIES — 12D3KooWOtherPee'), findsOneWidget);

      await tester.tap(_refresh);
      await tester.pumpAndSettle();
      expect(client.lookupCalls, 2);
      expect(_textWith('ENTRIES — 12D3KooWOtherPee'), findsOneWidget);

      // Now that peer has no record: back to the freshest answer.
      client.lookupSecond = reply(
        _peer(
          '12D3KooWOtherPeer',
          pb.DhtLookupOutcome.DHT_LOOKUP_OUTCOME_NOT_FOUND,
        ),
      );
      await tester.tap(_refresh);
      await tester.pumpAndSettle();
      expect(client.lookupCalls, 3);
      expect(_textWith('ENTRIES — 12D3KooWFirstPee'), findsOneWidget);
    });

    testWidgets('selects the freshest answer and lists its entries unasked', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_reply([_record(keyId: 'ff01')])));
      await tester.pumpAndSettle();
      await _runLookup(tester);

      expect(_textWith('ENTRIES — 12D3KooWFoundPee'), findsOneWidget);
      // A regular record is one entry, with no subkey.
      expect(find.text('{"llama": 32}'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);

      await tester.tap(find.text('{"llama": 32}'));
      await tester.pumpAndSettle();
      // The slim detail: identity line and the value, no tier, no subkey list.
      expect(find.text('Expires in 5m · 2.0 KB'), findsOneWidget);
      expect(find.text('{"llama": 32}'), findsNWidgets(2));
      expect(_textWith('· primary'), findsNothing);
      expect(find.byTooltip('Open value'), findsOneWidget);
    });

    testWidgets('lists a dictionary answer one subkey per row, unquoted', (
      tester,
    ) async {
      final client = _fakeClient(
        detailRecord:
            _record(
                keyId: 'ff02',
                keyName: '_kwaai.vpk.nodes',
                kind: pb.DhtRecordKind.DHT_RECORD_KIND_DICTIONARY,
                subkeyCount: 2,
              )
              ..subkeys.addAll([
                pb.DhtSubkey()
                  ..subkey = '"12D3KooWEveOne"'
                  ..expiresInSecs = 120
                  ..valueBytes = Int64(40)
                  ..value = _value('{"capacity_gb": 100}'),
                pb.DhtSubkey()
                  ..subkey = '"12D3KooWEveTwo"'
                  ..expiresInSecs = -30
                  ..valueBytes = Int64(41)
                  ..value = _value('{"capacity_gb": 200}'),
              ]),
      );
      await tester.pumpWidget(
        _host(_reply([_record(keyId: 'ff02')]), client: client),
      );
      await tester.pumpAndSettle();
      await _runLookup(tester);

      expect(find.text('12D3KooWEveOne'), findsOneWidget);
      expect(find.text('12D3KooWEveTwo'), findsOneWidget);
      expect(find.text('"12D3KooWEveOne"'), findsNothing);
      expect(find.text('expired 30s ago'), findsOneWidget);
      expect(find.text('{"capacity_gb": 200}'), findsOneWidget);

      await tester.tap(find.text('12D3KooWEveTwo'));
      await tester.pumpAndSettle();
      expect(find.text('_kwaai.vpk.nodes · 12D3KooWEveTwo'), findsOneWidget);
      expect(find.text('Expired 30s ago · 41 B'), findsOneWidget);
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

      await tester.tap(find.text('{"llama": 32}'));
      await tester.pumpAndSettle();
      expect(find.text('{"llama": 32}'), findsNWidgets(2));

      // The entry selection is cleared; the peer stays selected.
      await tester.tap(_refresh);
      await tester.pumpAndSettle();
      expect(client.lookupCalls, 2);
      expect(find.text('{"llama": 32}'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });
  });

  group('value dialog', () {
    testWidgets('shows the whole rendered value', (tester) async {
      final long = '{"x":"${'y' * 400}"}';
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
      // Pretty by default; Raw is the compact string as sent.
      expect(find.textContaining('  "x": "yyyy'), findsOneWidget);
      await tester.tap(find.text('Raw'));
      await tester.pumpAndSettle();
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
      expect(find.text('[\n  1,\n  2,\n  3\n]'), findsOneWidget);
    });

    testWidgets('pretty-prints a nested ext wrapper', (tester) async {
      final client = _fakeClient(
        detailRecord: _named()
          ..value = (_value('{"\$ext":64,"value":[2,10,{"start_block":0}]}')
            ..extCode = 64),
      );
      await tester.pumpWidget(_host(_reply([_named()]), client: client));
      await tester.pumpAndSettle();
      await tester.tap(find.text('_petals.models'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open value'));
      await tester.pumpAndSettle();
      expect(find.textContaining('  "value": [\n'), findsOneWidget);
      expect(find.textContaining('    "start_block": 0'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: _textWith('(ext 64)'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('falls back to raw when a decoded value is not JSON', (
      tester,
    ) async {
      const old = 'ext(64)[2, 10, {start_block: 0}]';
      final client = _fakeClient(detailRecord: _named()..value = _value(old));
      await tester.pumpWidget(_host(_reply([_named()]), client: client));
      await tester.pumpAndSettle();
      await tester.tap(find.text('_petals.models'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open value'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(of: find.byType(Dialog), matching: find.text(old)),
        findsOneWidget,
      );
      expect(find.text('Raw'), findsNothing);
    });

    testWidgets('never parses an undecoded value', (tester) async {
      // Hex that is also a JSON number: it must stay hex text.
      final client = _fakeClient(
        detailRecord: _named()..value = (_value('12')..decoded = false),
      );
      await tester.pumpWidget(_host(_reply([_named()]), client: client));
      await tester.pumpAndSettle();
      await tester.tap(find.text('_petals.models'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open value'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(Dialog), matching: find.text('12')),
        findsOneWidget,
      );
      expect(_textWith('not decoded, shown as hex'), findsOneWidget);
      expect(find.text('Raw'), findsNothing);
    });
  });
}
