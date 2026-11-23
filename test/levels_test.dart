import 'package:flutter_test/flutter_test.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:zihin_motoru/zihin_motoru.dart';

void main() {
  for (final e in kBrainKinds.entries) {
    test('${e.key}: bölümler kurulur ve doğrulanır', () {
      final rules = brainRulesFor('oyun-test-${e.key}', e.key);
      final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: const []);
      for (final n in const [1, 7, 40, 300, 5000, 99999]) {
        expect(rules.build(planner.spec(n)).validation.ok, isTrue, reason: '${e.key} $n');
      }
    });
  }
}
