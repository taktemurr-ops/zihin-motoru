import 'package:flutter_test/flutter_test.dart';
import 'package:studio_core/core/global_daily.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:zihin_motoru/zihin_motoru.dart';

/// Günün Bulmacası: her zihin oyunu herkese aynı, doğrulanmış günlük tur verir.
void main() {
  final days = [for (var i = 0; i < 7; i++) GlobalDaily.shift('2026-11-23', i)];
  for (final id in kBrainKinds.keys) {
    test('$id: günlük tur belirlenimci ve geçerli, puan sıralaması', () {
      final r = brainRulesFor('oyun-test-$id', id);
      expect(r.globalDaily, isTrue);
      expect(r.dailyRank, DailyRank.score);
      expect(r.dailyPerLanguage, isFalse);
      for (final d in days) {
        final a = r.globalDailySpec(d);
        expect(a.seed, r.globalDailySpec(d).seed);
        expect(a.mode, GameModeId.daily);
        expect(a.difficulty, inInclusiveRange(3, 6));
        expect(r.build(a).validation.ok, isTrue, reason: '$id $d');
      }
      expect(r.globalDailySpec(days[0]).seed, isNot(r.globalDailySpec(days[1]).seed));
    });
  }
}
