import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/ui/pages/settings_page.dart';

/// The Settings shell's status bar shows exactly one thing. These fix the
/// priority so a later addition can't quietly outrank an error or unsaved
/// work. The restart-needed prompt is not part of this chain — it renders
/// as its own bar above whichever of these shows.
void main() {
  SettingsBottomBar bar({
    bool hasError = false,
    bool updateReady = false,
    bool dirty = false,
  }) => settingsBottomBar(
    hasError: hasError,
    updateReady: updateReady,
    dirty: dirty,
  );

  test('nothing to say', () {
    expect(bar(), SettingsBottomBar.none);
  });

  test('each state on its own', () {
    expect(bar(hasError: true), SettingsBottomBar.error);
    expect(bar(updateReady: true), SettingsBottomBar.updateReady);
    expect(bar(dirty: true), SettingsBottomBar.apply);
  });

  test('an error outranks everything', () {
    expect(
      bar(hasError: true, updateReady: true, dirty: true),
      SettingsBottomBar.error,
    );
  });

  test('an update outranks a bare apply — but never an error', () {
    expect(bar(updateReady: true, dirty: true), SettingsBottomBar.updateReady);
    expect(
      bar(hasError: true, updateReady: true, dirty: true),
      SettingsBottomBar.error,
    );
  });
}
