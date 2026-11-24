import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/settings.dart';

void main() {
  test('parseBoundedInt takes the range, and empty means the default', () {
    expect(parseBoundedInt('', min: 1, max: 9), (value: null, error: null));
    expect(parseBoundedInt(' 5 ', min: 1, max: 9), (value: 5, error: null));
    expect(parseBoundedInt('9', min: 1, max: 9).value, 9);
    for (final bad in ['0', '10', '-1', '1.5', 'x']) {
      expect(
        parseBoundedInt(bad, min: 1, max: 9).error,
        isNotNull,
        reason: bad,
      );
    }
    expect(
      parseBoundedInt('', min: 1, max: 9, allowEmpty: false).error,
      isNotNull,
    );
  });

  test('parseMinScore takes 0 or more, and empty keeps everything', () {
    expect(parseMinScore(''), (value: 0.0, error: null));
    expect(parseMinScore('0.25'), (value: 0.25, error: null));
    expect(parseMinScore('2').value, 2.0, reason: 'scores are not 0-1');
    for (final bad in ['-0.1', 'x', 'NaN', 'Infinity']) {
      expect(parseMinScore(bad).error, isNotNull, reason: bad);
    }
  });
}
