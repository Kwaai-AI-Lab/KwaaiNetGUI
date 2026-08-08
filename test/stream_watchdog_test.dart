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

    // The watchdog measures silence, not slowness. Anything the daemon
    // sends — a token or a mere progress event — proves it is alive, so a
    // run that keeps reporting is never killed however long it takes. A
    // 90s cap here used to kill healthy distributed runs seconds before
    // their first token.
    group('liveness', () {
      Stream<String> wrapCounting(
        Stream<String> source, {
        void Function(SessionSlowNotice)? onSlow,
        Duration? slowAfter,
      }) => watchdogged<String, String>(
        source,
        extract: (s) => s.startsWith('tok') ? s : null,
        counts: (s) => s.startsWith('tok'),
        onSlow: onSlow,
        firstTimeout: _first,
        stallTimeout: _stall,
        slowAfter: slowAfter ?? _first,
        slowTick: _stall,
      );

      test('progress alone keeps a run alive indefinitely', () async {
        final ctrl = StreamController<String>();
        addTearDown(ctrl.close);
        var errored = false;
        wrapCounting(
          ctrl.stream,
        ).listen((_) {}, onError: (Object _) => errored = true);

        // Frames at a cadence inside the deadline, for far longer in
        // aggregate than either deadline would allow on its own.
        for (var i = 0; i < 6; i++) {
          await Future<void>.delayed(_stall ~/ 2);
          ctrl.add('event$i');
        }
        expect(
          errored,
          isFalse,
          reason: 'events prove liveness, so the run must not be failed',
        );
      });

      test('a token does not shorten the deadline into a failure', () async {
        final ctrl = StreamController<String>();
        addTearDown(ctrl.close);
        var errored = false;
        wrapCounting(
          ctrl.stream,
        ).listen((_) {}, onError: (Object _) => errored = true);

        ctrl.add('tok0');
        // Total elapsed far exceeds the stall deadline, but events keep
        // arriving — the run is slow, not stalled.
        for (var i = 0; i < 6; i++) {
          await Future<void>.delayed(_stall ~/ 2);
          ctrl.add('event$i');
        }
        expect(errored, isFalse);
      });

      test('genuine silence still fails', () async {
        final ctrl = StreamController<String>();
        addTearDown(ctrl.close);
        final errors = <Object>[];
        wrapCounting(ctrl.stream).listen((_) {}, onError: errors.add);

        // Nothing at all — the wedged case the deadline exists for.
        await Future<void>.delayed(_first * 2);
        expect(errors, hasLength(1));
        expect(errors.single, isA<SessionOpError>());
      });
    });

    group('slow notices', () {
      test('reports elapsed time until output arrives, then stops', () async {
        final ctrl = StreamController<String>();
        addTearDown(ctrl.close);
        final notices = <SessionSlowNotice>[];
        watchdogged<String, String>(
          ctrl.stream,
          extract: (s) => s.startsWith('tok') ? s : null,
          counts: (s) => s.startsWith('tok'),
          onSlow: notices.add,
          firstTimeout: _first * 10,
          stallTimeout: _stall * 10,
          slowAfter: _stall,
          slowTick: _stall,
        ).listen((_) {});

        // Progress but no output: the user should be told it is working.
        // Keep frames coming so the notice reports an active run.
        for (var i = 0; i < 6; i++) {
          await Future<void>.delayed(_stall ~/ 2);
          ctrl.add('event$i');
        }
        expect(notices, isNotEmpty);
        expect(
          notices.first.active,
          isTrue,
          reason: 'a recent frame means the daemon is demonstrably working',
        );

        // First token ends the notices for good.
        final before = notices.length;
        ctrl.add('tok0');
        await Future<void>.delayed(_stall * 3);
        expect(notices.length, before);
      });

      test('marks a run inactive when nothing has arrived', () async {
        final ctrl = StreamController<String>();
        addTearDown(ctrl.close);
        final notices = <SessionSlowNotice>[];
        watchdogged<String, String>(
          ctrl.stream,
          extract: (s) => s,
          onSlow: notices.add,
          firstTimeout: _first * 10,
          stallTimeout: _stall * 10,
          slowAfter: _stall,
          slowTick: _stall,
        ).listen((_) {});

        await Future<void>.delayed(_stall * 3);
        expect(notices, isNotEmpty);
        expect(
          notices.last.active,
          isFalse,
          reason: 'no frames means no evidence of progress',
        );
      });
    });
  });
}
