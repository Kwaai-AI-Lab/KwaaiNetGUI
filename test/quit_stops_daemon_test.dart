import 'package:flutter_test/flutter_test.dart';
import 'package:kwaainet_gui/src/settings.dart';
import 'package:kwaainet_gui/src/window/shutdown.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<Settings> settings({DaemonMode? mode, bool? startOnStartup}) async {
    SharedPreferences.setMockInitialValues({});
    final s = await Settings.load();
    if (mode != null) await s.setMode(mode);
    if (startOnStartup != null) {
      await s.setStartServiceOnStartup(startOnStartup);
    }
    return s;
  }

  test('defaults stop the node: the GUI would have started one', () async {
    expect(quitStopsDaemon(await settings()), isTrue);
  });

  test('start-on-startup off leaves the node running', () async {
    expect(quitStopsDaemon(await settings(startOnStartup: false)), isFalse);
  });

  test('external mode never stops the node', () async {
    expect(quitStopsDaemon(await settings(mode: DaemonMode.external)), isFalse);
  });

  test('system and custom modes behave like built-in', () async {
    for (final m in [DaemonMode.system, DaemonMode.custom]) {
      expect(quitStopsDaemon(await settings(mode: m)), isTrue, reason: '$m');
      expect(
        quitStopsDaemon(await settings(mode: m, startOnStartup: false)),
        isFalse,
        reason: '$m',
      );
    }
  });
}
