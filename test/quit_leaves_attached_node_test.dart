import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kwaainet_gui/src/daemon/daemon_controller.dart';
import 'package:kwaainet_gui/src/daemon/daemon_state.dart';

/// Records stops instead of running `kwaainet stop`.
class _FakeController extends Fake implements DaemonController {
  _FakeController({required this.startedNode});

  @override
  final bool startedNode;

  int stops = 0;

  @override
  Future<bool> stop() async {
    stops++;
    return true;
  }
}

void main() {
  ProviderContainer container(_FakeController daemon) {
    final c = ProviderContainer(
      overrides: [
        daemonControllerProvider.overrideWithValue(daemon),
        daemonStatusProvider.overrideWith((ref) => const Stream.empty()),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  // Regression (KwaaiNetGUI#17 item 2): quitting the GUI ran `kwaainet stop`
  // on a node started from the CLI, which the GUI had only attached to.
  test('quit leaves a node the app attached to running', () async {
    final daemon = _FakeController(startedNode: false);
    await container(daemon)
        .read(daemonTransitionProvider.notifier)
        .stopOnQuit();
    expect(daemon.stops, 0);
  });

  test('quit stops a node the app spawned', () async {
    final daemon = _FakeController(startedNode: true);
    await container(daemon)
        .read(daemonTransitionProvider.notifier)
        .stopOnQuit();
    expect(daemon.stops, 1);
  });

  test('Stop service stops the node either way', () async {
    final daemon = _FakeController(startedNode: false);
    await container(daemon).read(daemonTransitionProvider.notifier).stop();
    expect(daemon.stops, 1);
  });
}
