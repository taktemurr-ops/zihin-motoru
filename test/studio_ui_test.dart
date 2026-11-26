// Onaylı tasarım: motorun her türü merkez benzeri ev sahibinde (koyu palet)
// açılır; oyun içi yazılar ve dokunuşla açılan pencereler okunur (3:1).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zihin_motoru/zihin_motoru.dart';
import 'package:studio_core/core/level_plan.dart';

import 'studio_readability.dart';
import 'views_test.dart' show fakeCtx;

void main() {
  for (final e in kBrainKinds.entries) {
    testWidgets('${e.key}: onaylı koyu tasarımda yazılar ve pencereler okunur', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      final rules = brainRulesFor('oyun-test-${e.key}', e.key);
      final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: const []);
      final gl = rules.build(planner.spec(5));
      await tester.pumpWidget(studioHost(BrainStage(ctx: fakeCtx(gl, 'tr', []), rules: rules)));
      await tester.pump(const Duration(milliseconds: 400));
      final issues = await sweepReadability(tester, e.key);
      expect(issues, isEmpty, reason: 'Okunmayan yazı (${e.key}): ${issues.join('; ')}');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
