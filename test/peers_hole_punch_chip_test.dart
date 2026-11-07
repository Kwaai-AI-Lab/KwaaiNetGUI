import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/chat/generated/kwaai.pb.dart' as pb;
import 'package:kwaainet_gui/src/ui/pages/peers_tab.dart';

pb.HolePunchStats _stats({int ok = 0, int tried = 0, int relayed = 0}) =>
    pb.HolePunchStats()
      ..succeeded = Int64(ok)
      ..attempted = Int64(tried)
      ..relayedConnections = relayed;

void main() {
  group('holePunchChip', () {
    test('says so when nothing has been tried', () {
      final chip = holePunchChip(_stats(relayed: 2));
      expect(chip.label, 'No hole punches · 2 relayed');
      expect(chip.warn, isFalse);
    });

    test('shows successes over attempts', () {
      final chip = holePunchChip(_stats(ok: 3, tried: 4, relayed: 1));
      expect(chip.label, 'Hole punch 3/4 · 1 relayed');
      expect(chip.warn, isFalse);
    });

    test('warns when every punch failed and traffic still rides a relay', () {
      expect(holePunchChip(_stats(tried: 5, relayed: 2)).warn, isTrue);
      expect(holePunchChip(_stats(tried: 5)).warn, isFalse);
    });
  });
}
