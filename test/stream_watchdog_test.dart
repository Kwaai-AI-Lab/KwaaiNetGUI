import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/chat/session_client.dart';

/// Short deadlines so the tests exercise the real timer logic without the
/// production 90s/45s waits. fakeAsync-free: we drive real timers but at a
/// scale where the whole suite still runs in well under a second.
const _first = Duration(milliseconds: 120);
const _stall = Duration(milliseconds: 60);

Stream<String> _wrap(Stream<String> source) => watchdogged<String, String>(
  source,
  extract: (s) => s.isEmpty ? null : s,
  firstTimeout: _first,
  stallTimeout: _stall,
);

void main() {
  group('watchdogged', () {
    test('passes through elements and completes normally', () async {
      final src = Stream.fromIterable(['a', 'b', 'c']);
      expect(await _wrap(src).toList(), ['a', 'b', 'c']);
    });

    test('drops elements extract maps to null', () async {
      final src = Stream.fromIterable(['a', '', 'b']);
      expect(await _wrap(src).toList(), ['a', 'b']);
    });

    test('forwards an upstream error without wrapping it', () async {
      final src = Stream<String>.error(StateError('upstream boom'));
      await expectLater(_wrap(src), emitsError(isA<StateError>()));
    });

    test('errors when the first element never arrives', () async {
      // A source that opens and then says nothing — the exact shape of a
      // daemon that accepted the request and went quiet.
      final ctrl = StreamController<String>();
      addTearDown(ctrl.close);
      await expectLater(
        _wrap(ctrl.stream),
        emitsError(
          isA<SessionOpError>()
              .having((e) => e.code, 'code', 3)
              .having((e) => e.message, 'message', contains('did not respond')),
        ),
      );
    });

    test('errors when the stream stalls after producing', () async {
      final ctrl = StreamController<String>();
      addTearDown(ctrl.close);
      final events = <String>[];
      final done = Completer<Object>();
      _wrap(ctrl.stream).listen(events.add, onError: done.complete);

      ctrl.add('partial');
      final err = await done.future;

      expect(events, ['partial'], reason: 'tokens before the stall survive');
      expect(err, isA<SessionOpError>());
      expect((err as SessionOpError).message, contains('mid-answer'));
    });

    test('a slow but alive stream is never killed', () async {
      // Elements spaced under the stall deadline: the timer must reset on
      // each one, so a slow generation completes rather than erroring.
      final ctrl = StreamController<String>();
      final events = <String>[];
      final done = Completer<void>();
      _wrap(ctrl.stream).listen(
        events.add,
        onError: (Object e) => done.completeError(e),
        onDone: done.complete,
      );

      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(_stall ~/ 2);
        ctrl.add('tok$i');
      }
      await ctrl.close();
      await done.future;

      expect(events, ['tok0', 'tok1', 'tok2', 'tok3']);
    });

    test('cancelling the subscription stops the watchdog', () async {
      final ctrl = StreamController<String>();
      addTearDown(ctrl.close);
      var errored = false;
      final sub = _wrap(
        ctrl.stream,
      ).listen((_) {}, onError: (Object _) => errored = true);

      await sub.cancel();
      // Well past the first-frame deadline: a leaked timer would fire here
      // and push an error into a stream nobody is listening to.
      await Future<void>.delayed(_first * 2);
      expect(errored, isFalse);
    });
  });
}
