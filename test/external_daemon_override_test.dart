import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/settings.dart';

/// Tests for `KWAAINET_EXTERNAL_DAEMON`, which pins the app to
/// [DaemonMode.external] regardless of the on-disk setting.
///
/// The parsing is what is worth pinning down: the variable decides whether
/// the app spawns a daemon at startup, so a value read the wrong way either
/// takes over daemon management the user did not ask for, or fails to
/// disclaim it when they did.
void main() {
  group('isExternalDaemonForced', () {
    test('unset does not force external mode', () {
      expect(isExternalDaemonForced(null), isFalse);
    });

    test('empty is treated as unset', () {
      // `FOO=$UNSET` expands to this, and exporting the variable empty is a
      // common shell accident — neither should silently pin the mode.
      expect(isExternalDaemonForced(''), isFalse);
      expect(isExternalDaemonForced('   '), isFalse);
    });

    test('falsey spellings do not force external mode', () {
      for (final v in ['0', 'false', 'no', 'off']) {
        expect(isExternalDaemonForced(v), isFalse, reason: v);
        expect(isExternalDaemonForced(v.toUpperCase()), isFalse, reason: v);
        expect(isExternalDaemonForced('  $v  '), isFalse, reason: v);
      }
    });

    test('1 and other values force external mode', () {
      for (final v in ['1', 'true', 'yes', 'on', 'anything']) {
        expect(isExternalDaemonForced(v), isTrue, reason: v);
      }
    });

    test('the Makefile and launch.json value works', () {
      // Both gui-run and the VS Code config pass exactly "1"; if this ever
      // stops being truthy, the GUI silently resumes spawning a local daemon
      // alongside the container it is pointed at.
      expect(isExternalDaemonForced('1'), isTrue);
    });
  });
}
