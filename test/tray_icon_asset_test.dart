import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kwaainet_gui/src/tray/tray.dart';

void main() {
  // Regression: Windows was handed the PNG, which tray_manager cannot load
  // there, so no tray icon appeared and Quit was unreachable.
  test('Windows gets an .ico that really is one', () {
    final icon = trayIconAsset(isWindows: true);
    expect(icon.asset, endsWith('.ico'));
    expect(icon.fileName, endsWith('.ico'));
    final bytes = File(icon.asset).readAsBytesSync();
    // ICONDIR header: reserved 0, type 1 (icon).
    expect(bytes.sublist(0, 4), [0, 0, 1, 0]);
    // The tray asks LoadImage for SM_CXSMICON (16 px at 100% scaling), so a
    // 16 px entry must exist rather than be scaled down from a large one.
    // ICONDIRENTRY widths start at byte 6, 16 bytes apart; 0 means 256.
    final count = bytes[4] | (bytes[5] << 8);
    final widths = [for (var i = 0; i < count; i++) bytes[6 + 16 * i]];
    expect(widths, containsAll([16, 32, 0]));
  });

  test('macOS and Linux keep the template PNG', () {
    final icon = trayIconAsset(isWindows: false);
    expect(icon.asset, 'assets/tray_kwaai_logo@2x.png');
    expect(File(icon.asset).existsSync(), isTrue);
  });

  test('every tray asset is declared in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final w in [true, false]) {
      expect(pubspec, contains('- ${trayIconAsset(isWindows: w).asset}'));
    }
  });
}
