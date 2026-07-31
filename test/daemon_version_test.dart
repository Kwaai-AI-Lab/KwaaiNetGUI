import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/daemon/daemon_controller.dart';

void main() {
  group('DaemonController.parseVersionOutput', () {
    test('extracts the version from standard clap output', () {
      expect(DaemonController.parseVersionOutput('kwaainet 0.5.4'), '0.5.4');
    });

    test('ignores trailing whitespace and newlines', () {
      expect(DaemonController.parseVersionOutput('kwaainet 0.5.4\n'), '0.5.4');
      expect(DaemonController.parseVersionOutput('  kwaainet 0.4.69  '), '0.4.69');
    });

    test('takes only the first line, so update hints do not leak in', () {
      expect(
        DaemonController.parseVersionOutput(
          'kwaainet 0.5.4\nA new version is available: 0.6.0',
        ),
        '0.5.4',
      );
    });

    test('tolerates a v prefix on the version token', () {
      expect(DaemonController.parseVersionOutput('kwaainet v0.5.4'), '0.5.4');
    });

    test('accepts a bare version with no binary name', () {
      expect(DaemonController.parseVersionOutput('0.5.4'), '0.5.4');
    });

    test('returns null for empty output', () {
      expect(DaemonController.parseVersionOutput(''), isNull);
      expect(DaemonController.parseVersionOutput('   \n  '), isNull);
    });

    test('returns null when the trailing token is not digit-led', () {
      // An older binary that does not understand --version prints usage
      // rather than failing; that must not render as a version.
      expect(
        DaemonController.parseVersionOutput('Usage: kwaainet [OPTIONS]'),
        isNull,
      );
      expect(DaemonController.parseVersionOutput('unknown flag'), isNull);
    });
  });
}
