import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/ui/pages/settings_page.dart';

/// The Settings shell shows exactly one pinned bar. These fix the priority
/// so a later addition can't quietly outrank an error or unsaved work.
void main() {
  SettingsBottomBar bar({
    bool hasError = false,
    bool needsRestart = false,
    bool serviceRunning = false,
    bool updateReady = false,
    bool dirty = false,
  }) => settingsBottomBar(
    hasError: hasError,
    needsRestart: needsRestart,
    serviceRunning: serviceRunning,
    updateReady: updateReady,
    dirty: dirty,
  );

  test('nothing to say', () {
    expect(bar(), SettingsBottomBar.none);
  });

  test('each state on its own', () {
    expect(bar(hasError: true), SettingsBottomBar.error);
    expect(
      bar(needsRestart: true, serviceRunning: true),
      SettingsBottomBar.restartNeeded,
    );
    expect(bar(updateReady: true), SettingsBottomBar.updateReady);
    expect(bar(dirty: true), SettingsBottomBar.apply);
  });

  test('an error outranks everything', () {
    expect(
      bar(
        hasError: true,
        needsRestart: true,
        serviceRunning: true,
        updateReady: true,
        dirty: true,
      ),
      SettingsBottomBar.error,
    );
  });

  test('a restart-needed prompt outranks an update', () {
    expect(
      bar(needsRestart: true, serviceRunning: true, updateReady: true),
      SettingsBottomBar.restartNeeded,
    );
  });

  test('an update outranks a bare apply — but never an error', () {
    expect(bar(updateReady: true, dirty: true), SettingsBottomBar.updateReady);
    expect(
      bar(hasError: true, updateReady: true, dirty: true),
      SettingsBottomBar.error,
    );
  });

  test('restart-needed is inert while the service is down', () {
    // The prompt only means anything against a running service; the update
    // behind it should surface instead of nothing.
    expect(bar(needsRestart: true), SettingsBottomBar.none);
    expect(
      bar(needsRestart: true, updateReady: true),
      SettingsBottomBar.updateReady,
    );
    expect(bar(needsRestart: true, dirty: true), SettingsBottomBar.apply);
  });
}
