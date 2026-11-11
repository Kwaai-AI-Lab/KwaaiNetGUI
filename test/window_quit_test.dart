import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kwaainet_gui/src/daemon/daemon_state.dart';
import 'package:kwaainet_gui/src/window/shutdown.dart';
import 'package:kwaainet_gui/src/window/window_restore.dart';

/// Stops nothing: these tests are about the window calls around the stop.
/// Records which stop was asked for.
class _NoopTransition extends DaemonTransitionNotifier {
  final stops = <String>[];

  @override
  DaemonTransition build() => DaemonTransition.none;

  @override
  Future<void> stop() async => stops.add('stop');

  @override
  Future<void> stopOnQuit() async => stops.add('stopOnQuit');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('window_manager');
  late List<String> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          // show() asks isMinimized first and casts the answer to bool.
          return call.method.startsWith('is') ? false : null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [daemonTransitionProvider.overrideWith(_NoopTransition.new)],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('openMainWindowAtChat', () {
    // Regression: window_manager 0.5.2's SetSkipTaskbar crashes on Windows
    // (null taskbar list), so restoring from the tray killed the GUI.
    test('never calls setSkipTaskbar on Windows', () async {
      await openMainWindowAtChat(container(), isWindows: true);
      expect(calls, isNot(contains('setSkipTaskbar')));
      expect(calls, containsAllInOrder(['show', 'focus']));
    });

    test('still restores the taskbar entry elsewhere', () async {
      await openMainWindowAtChat(container(), isWindows: false);
      expect(calls, containsAllInOrder(['setSkipTaskbar', 'show', 'focus']));
    });
  });

  group('performQuit', () {
    // Regression: destroy() on Windows is a bare PostQuitMessage, and the
    // process crashed in flutter_windows.dll on the way out.
    test('closes rather than destroys on Windows', () async {
      await performQuit(container(), isWindows: true);
      expect(calls, ['setPreventClose', 'close']);
    });

    test('destroys elsewhere', () async {
      await performQuit(container(), isWindows: false);
      expect(calls, ['setPreventClose', 'destroy']);
    });

    test('runs beforeClose after the stop and before the window goes', () async {
      final c = container();
      final order = <String>[];
      await performQuit(
        c,
        isWindows: true,
        beforeClose: () async {
          order.add('beforeClose:${calls.length}');
          expect(c.read(shuttingDownProvider), isTrue);
        },
      );
      expect(order, ['beforeClose:0']);
      expect(calls, ['setPreventClose', 'close']);
    });

    // KwaaiNetGUI#17: Quit must leave a node the app only attached to.
    test('stops only a node the app started', () async {
      final c = container();
      await performQuit(c, isWindows: true);
      final t = c.read(daemonTransitionProvider.notifier) as _NoopTransition;
      expect(t.stops, ['stopOnQuit']);
    });

    // The update swap renames the install dir, which a running bundled
    // kwaainet.exe blocks on Windows.
    test('stopAttached stops the node whoever started it', () async {
      final c = container();
      await performQuit(c, isWindows: true, stopAttached: true);
      final t = c.read(daemonTransitionProvider.notifier) as _NoopTransition;
      expect(t.stops, ['stop']);
    });

    test('a second quit does nothing', () async {
      final c = container();
      await performQuit(c, isWindows: true);
      calls.clear();
      await performQuit(c, isWindows: true);
      expect(calls, isEmpty);
    });
  });
}
