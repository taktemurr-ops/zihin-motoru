import 'package:flutter_test/flutter_test.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/rng.dart';
import 'package:zihin_motoru/src/kinds/ek4.dart';
import 'package:zihin_motoru/src/texts_ek4.dart';
import 'package:zihin_motoru/zihin_motoru.dart';

void main() {
  test('Kestirme, İz Sürme, Ok Yönü metinleri 33 dilde', () {
    for (final e in kZihinTexts3.entries) {
      expect(e.value.length, 33, reason: e.key);
      expect(e.value.every((s) => s.trim().isNotEmpty), isTrue, reason: e.key);
    }
    for (final k in ['estTime', 'trailB']) {
      expect(kZihinTexts3[k]!.every((s) => s.contains(k == 'estTime' ? '{n}' : '{s}')), isTrue, reason: k);
    }
    expect(kTrailLetters.length, 33);
    for (final l in kTrailLetters) {
      expect(l.length, greaterThanOrEqualTo(10));
      expect(l.toSet().length, l.length);
    }
  });

  test('Kestirme isabeti: tam tahmin 1, uzak tahmin 0', () {
    const t = EstTask(0, 40, 1);
    expect(estAccuracy(t, 40), 1.0);
    expect(estAccuracy(t, 80), 0.0);
    expect(estAccuracy(const EstTask(1, 90, 1), 135), 0.0);
    expect(estAccuracy(const EstTask(3, 4, 1), 4.4), closeTo(0.8, 1e-9));
  });

  test('İz Sürme B etiketleri sayı-harf dönüşümlü', () {
    const part = TrailPart(true, [10, 30, 50, 70], [10, 30, 50, 70]);
    expect([for (var i = 0; i < 4; i++) trailLabel(part, i, const ['A', 'B'])], ['1', 'A', '2', 'B']);
  });

  test('100.000 bölümün geniş örneklemi kurulur ve doğrulanır', () {
    for (final k in ['kestirme', 'iz-surme', 'ok-yonu']) {
      final rules = brainRulesFor('oyun-test-$k', k);
      expect(rules.levelCount, 100000);
      final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: const []);
      final r = SeededRandom(77);
      for (var i = 0; i < 400; i++) {
        final n = 1 + r.nextInt(100000);
        expect(rules.build(planner.spec(n)).validation.ok, isTrue, reason: '$k $n');
      }
    }
  });
}
