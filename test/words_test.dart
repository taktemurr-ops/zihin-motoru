import 'package:flutter_test/flutter_test.dart';
import 'package:zihin_motoru/src/words.dart';

void main() {
  test('kelime listeleri 33 dilde ve her dilde birbirinden farklı', () {
    expect(kMemoryWords.length, greaterThanOrEqualTo(60));
    for (final w in kMemoryWords) {
      expect(w.length, 33);
    }
    for (var l = 0; l < 33; l++) {
      final seen = <String>{};
      for (final w in kMemoryWords) {
        expect(seen.add(w[l].toLowerCase()), isTrue, reason: '$l ${w[l]}');
      }
    }
    for (final v in kZihinTexts2.values) {
      expect(v.length, 33);
    }
  });
}
