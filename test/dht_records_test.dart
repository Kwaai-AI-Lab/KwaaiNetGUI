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

/// Answers the detail request from a canned reply. Closed at birth: that
/// stops the probe loop (a pending timer fails a widget test) and nothing
/// here reaches the session.
class _FakeClient extends KwaaiRpcClient {
  _FakeClient({required this.detail}) {
    close();
  }

  final pb.DhtRecordsReply detail;

  @override
  Future<pb.DhtRecordsReply> dhtRecords({
    bool includeValues = false,
    List<String> keyIds = const [],
  }) async {
    return detail;
  }
}

/// A named regular record with a value.
_FakeClient _fakeClient({pb.DhtRecord? detailRecord}) {
  final record =
      detailRecord ??
      (_record(keyId: 'ff01', keyName: '_petals.models')
        ..value = _value('{"llama": 32}'));
  return _FakeClient(detail: _reply([record]));
}

/// Counts how many times the listing was (re)requested. [errorsFirst] fail
/// the opening requests in order; [errorAfterFirst] fails every later one.
class _Listing {
  _Listing({this.errorsFirst = const []});

  final List<Object> errorsFirst;
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
      final early = listing?.errorsFirst ?? const [];
      if (n <= early.length) return Stream.error(early[n - 1]);
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

SessionOpError _starting(pb.Error_Code code) =>
    SessionOpError(code: code.value, message: 'the p2p node is still starting');

void main() {
  group('formatExpiry', () {
    test('counts down in the largest useful unit', () {
      expect(formatExpiry(45), 'in 45s');
      expect(formatExpiry(240), 'in 4m');
      expect(formatExpiry(7200), 'in 2h');
      expect(formatExpiry(172800), 'in 2d');
    });

    // A dictionary keeps subkeys past their expiration.
    test('reads an expired subkey as expired, not as a negative countdown', () {
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

    // Records are never expired (the listing filters them); subkeys can be.
    testWidgets('marks an expired subkey in the detail', (tester) async {
      pb.DhtRecord dict() => _record(
        keyId: 'ff02',
        keyName: 'Llama.0',
        kind: pb.DhtRecordKind.DHT_RECORD_KIND_DICTIONARY,
        subkeyCount: 1,
      );
      await tester.pumpWidget(
        _host(
          _reply([dict()]),
          client: _fakeClient(
            detailRecord: dict()
              ..subkeys.add(
                pb.DhtSubkey()
                  ..subkey = '"12D3KooWServer"'
                  ..expiresInSecs = -90
                  ..valueBytes = Int64(9)
                  ..value = _value('[1]'),
              ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Llama.0'));
      await tester.pumpAndSettle();
      expect(_textWith('12D3KooWServer · expired 1m ago'), findsOneWidget);
      expect(_textWith('Expires in 5m ('), findsOneWidget);
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
          code: pb.Error_Code.INTERNAL.value,
          message: 'store lock poisoned',
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
      // Unreachable is why Refresh is off, and the banner says so.
      expect(tester.widget<IconButton>(_refresh).onPressed, isNull);
    });

    testWidgets('a node restarting under the rows is retried', (tester) async {
      final listing = _Listing()
        ..errorAfterFirst = _starting(pb.Error_Code.UNAVAILABLE);
      await tester.pumpWidget(_host(_reply([_named()]), listing: listing));
      await tester.pumpAndSettle();
      await tester.tap(_refresh);
      await tester.pump();
      await tester.pump();
      expect(_textWith('the p2p node is still starting'), findsOneWidget);
      expect(listing.requests, 2);

      await tester.pump(const Duration(seconds: 2));
      expect(listing.requests, 3);
    });
  });

  test('retries back off while the node starts, then hold steady', () {
    expect(
      [for (var i = 0; i < 6; i++) startingRetryDelay(i).inSeconds],
      [2, 4, 8, 15, 15, 15],
    );
  });

  group('not available yet', () {
    for (final code in [
      pb.Error_Code.UNAVAILABLE,
      pb.Error_Code.UNIMPLEMENTED,
    ]) {
      testWidgets('${code.name} reads as starting and retries by itself', (
        tester,
      ) async {
        final listing = _Listing(
          errorsFirst: [_starting(code), _starting(code)],
        );
        await tester.pumpWidget(_host(_reply([_named()]), listing: listing));
        await tester.pump();
        expect(find.text('The p2p node is still starting'), findsOneWidget);
        expect(_textWith('native_p2p'), findsNothing);
        expect(_textWith('Go p2p'), findsNothing);
        expect(listing.requests, 1);

        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
        expect(listing.requests, 2);
        // Backed off: the second retry waits 4s, not 2s.
        await tester.pump(const Duration(seconds: 3));
        expect(listing.requests, 2);
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        expect(listing.requests, 3);
        expect(find.text('_petals.models'), findsOneWidget);
      });
    }

    testWidgets('Retry now skips the wait', (tester) async {
      final listing = _Listing(
        errorsFirst: [_starting(pb.Error_Code.UNAVAILABLE)],
      );
      await tester.pumpWidget(_host(_reply([_named()]), listing: listing));
      await tester.pump();
      await tester.tap(find.text('Retry now'));
      await tester.pump();
      await tester.pump();
      expect(listing.requests, 2);
      expect(find.text('_petals.models'), findsOneWidget);
      // The cancelled timer must not fire a third request.
      await tester.pump(const Duration(seconds: 30));
      expect(listing.requests, 2);
    });

    testWidgets('an old daemon is told to update, and not retried', (
      tester,
    ) async {
      final listing = _Listing(
        errorsFirst: [
          SessionOpError(
            code: pb.Error_Code.INVALID_ARGUMENT.value,
            message: 'ClientFrame missing body',
          ),
        ],
      );
      await tester.pumpWidget(_host(_reply([_named()]), listing: listing));
      await tester.pumpAndSettle();
      expect(find.text('DHT records are not available'), findsOneWidget);
      expect(
        find.text(
          'This daemon is too old to list DHT records — update kwaainet',
        ),
        findsOneWidget,
      );
      expect(_textWith('ClientFrame'), findsNothing);
      await tester.pump(const Duration(seconds: 30));
      expect(listing.requests, 1);
    });

    testWidgets('another INVALID_ARGUMENT is not blamed on the version', (
      tester,
    ) async {
      final listing = _Listing(
        errorsFirst: [
          SessionOpError(
            code: pb.Error_Code.INVALID_ARGUMENT.value,
            message: 'key_ids: not hex',
          ),
        ],
      );
      await tester.pumpWidget(_host(_reply([_named()]), listing: listing));
      await tester.pumpAndSettle();
      expect(_textWith('too old'), findsNothing);
      expect(find.text('Key_ids: not hex'), findsOneWidget);
    });

    testWidgets('a failed first listing can be retried by hand', (
      tester,
    ) async {
      final listing = _Listing(
        errorsFirst: [
          SessionOpError(
            code: pb.Error_Code.INTERNAL.value,
            message: 'store lock poisoned',
          ),
        ],
      );
      await tester.pumpWidget(_host(_reply([_named()]), listing: listing));
      await tester.pumpAndSettle();
      expect(find.text('DHT records are not available'), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
      expect(listing.requests, 1);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(listing.requests, 2);
      expect(find.text('_petals.models'), findsOneWidget);
    });
  });

  testWidgets('the header fits a 560px window', (tester) async {
    await tester.pumpWidget(
      _host(_reply([_record(keyId: 'ff01')]), width: 560),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
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
