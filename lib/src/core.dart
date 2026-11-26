import 'dart:async';

import 'package:flutter/material.dart';
import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/core/game_rules.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/missions.dart';
import 'package:studio_core/core/rng.dart';
import 'package:studio_core/core/stats.dart';

import 'texts.dart';
import 'studio_chrome.dart';

/// Bir zihin oyununun kurulmuş bölümü.
abstract class BPuzzle {
  const BPuzzle();
}

class BLevel {
  final String kind;
  final int d;
  final BPuzzle puzzle;
  const BLevel(this.kind, this.d, this.puzzle);
}

/// Zihin antrenmanı türü.
abstract class BrainKind {
  const BrainKind();
  String get id;

  /// Zorluk 1..10 için deterministik bölüm (kurulamazsa null).
  BPuzzle? make(int d, SeededRandom r);

  bool check(BPuzzle p) => true;

  Widget build(BrainPlay play);

  List<GameStat> get stats => const [
        GameStat('rounds_won', 'Kazanılan bölüm', 'Levels won', scale: 10),
        GameStat('correct', 'Doğru yanıt', 'Correct answers', scale: 200),
      ];

  List<MissionTemplate> get missions => const [
        MissionTemplate('win', 'rounds_won', [3, 10, 25]),
        MissionTemplate('correct', 'correct', [30, 100, 250]),
      ];
}

BPuzzle realizeBrain(BrainKind k, int d, int seed) {
  for (var dd = d; dd >= 1; dd--) {
    for (var a = 0; a < 20; a++) {
      BPuzzle? p;
      try {
        p = k.make(dd, SeededRandom(mixSeed([seed, a, dd, 5153])));
      } catch (_) {
        p = null;
      }
      if (p != null && k.check(p)) return p;
    }
  }
  throw StateError('zihin bölümü kurulamadı: ${k.id} $d');
}

class BrainRules extends GameRules<BLevel> {
  @override
  final String gameId;
  final BrainKind kind;
  final int levels;
  BrainRules({required this.gameId, required this.kind, this.levels = 100000});

  @override
  int get levelCount => levels;

  @override
  List<String> get optionalMechanics => const [];

  @override
  List<GameModeId> get modes => const [GameModeId.campaign, GameModeId.daily, GameModeId.weekly, GameModeId.challenge];

  @override
  List<GameStat> get gameStats => kind.stats;

  @override
  List<MissionTemplate> get missionTemplates => kind.missions;

  @override
  BLevel generate(LevelSpec spec) {
    final d = spec.difficulty.clamp(1, 10);
    return BLevel(kind.id, d, realizeBrain(kind, d, spec.seed));
  }

  @override
  Validation validate(BLevel puzzle, LevelSpec spec) =>
      puzzle.kind == kind.id && kind.check(puzzle.puzzle) ? const Validation.ok() : const Validation.fail('invalid');
}

class BrainPlay {
  final PlayContext ctx;
  final BPuzzle puzzle;
  final int d;
  final int seed;

  /// Günlük programda alt oyunun sonucu ana oyuna aktarılır.
  final void Function(bool won, int correct, int stars)? relay;
  const BrainPlay({required this.ctx, required this.puzzle, required this.d, required this.seed, this.relay});

  String get lang => ctx.lang;

  void win({int score = 0, int stars = 3, int seconds = 0, int correct = 0, int hints = 0}) {
    final r = relay;
    if (r != null) return r(true, correct, stars);
    ctx.finish(RoundResult(
      won: true,
      score: score < 0 ? 0 : score,
      stars: stars.clamp(1, 3),
      seconds: seconds,
      hintsUsed: hints,
      gameStats: {'rounds_won': 1, 'correct': correct},
    ));
  }

  void lose({int score = 0, int seconds = 0, int correct = 0, String? headline}) {
    final r = relay;
    if (r != null) return r(false, correct, 0);
    ctx.finish(RoundResult(won: false, score: score < 0 ? 0 : score, seconds: seconds, gameStats: {'correct': correct}, headline: headline));
  }
}

/// Zihin oyunlarının ortak sahnesi.
class BrainStage extends StatelessWidget {
  final PlayContext ctx;
  final BrainRules rules;
  const BrainStage({super.key, required this.ctx, required this.rules});

  /// Motorun bütün arayüzü (paneller, pencereler, düğmeler) onaylı koyu
  /// tasarımda; tahta çizimleri kendi renklerini korur.
  @override
  Widget build(BuildContext context) => StudioChrome(child: Builder(builder: _build));

  Widget _build(BuildContext context) {
    final lv = ctx.generated.puzzle as BLevel;
    return rules.kind.build(BrainPlay(ctx: ctx, puzzle: lv.puzzle, d: lv.d, seed: ctx.spec.seed));
  }
}

BrainRules brainRules(String gameId, BrainKind kind) => BrainRules(gameId: gameId, kind: kind);

// ---------------------------------------------------------------- ortak arayüz

class BColors {
  static const paper = Color(0xFFF4F1EA);
  static const ink = Color(0xFF22303F);
  static const good = Color(0xFF4F9A6E);
  static const bad = Color(0xFFC8553D);
  static const accent = Color(0xFF3E6FB0);
  static const soft = Color(0xFFE6E0D4);
  static const List<Color> pads = [Color(0xFFE07A5F), Color(0xFF3D85C6), Color(0xFF81B29A), Color(0xFFF2CC8F), Color(0xFF9B72AA), Color(0xFF56B4D3)];
}

mixin Ticker<T extends StatefulWidget> on State<T> {
  int seconds = 0;
  bool ended = false;
  Timer? _t;

  void startClock() {
    _t?.cancel();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!ended && mounted) setState(() => seconds++);
      onSecond();
    });
  }

  void onSecond() {}

  final List<Timer> _later = [];

  /// İptal edilebilen gecikmeli iş (ekran kapanınca durur).
  void later(int ms, VoidCallback f) {
    _later.add(Timer(Duration(milliseconds: ms), () {
      if (mounted) f();
    }));
  }

  @override
  void dispose() {
    _t?.cancel();
    for (final t in _later) {
      t.cancel();
    }
    super.dispose();
  }

  String clock([int? s]) {
    final v = s ?? seconds;
    return '${v ~/ 60}:${(v % 60).toString().padLeft(2, '0')}';
  }
}

/// Üst çubuk.
class BrainBar extends StatelessWidget {
  final String left;
  final String status;
  final VoidCallback? onHint;
  final String lang;
  const BrainBar({super.key, required this.lang, this.left = '', this.status = '', this.onHint});

  @override
  Widget build(BuildContext context) {
    final look = StudioLook.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 48,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: look.accent.withValues(alpha: 0.45), width: 1.2),
      ),
      child: Row(children: [
        Text(left, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: look.number)),
        const SizedBox(width: 8),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(status, maxLines: 1, style: const TextStyle(fontWeight: FontWeight.w700, color: kStudioSubtle)),
          ),
        ),
        if (onHint != null)
          IconButton(
            tooltip: bt(lang, 'hint'),
            onPressed: onHint,
            icon: const Icon(Icons.lightbulb_rounded, color: StudioLook.gold),
          ),
      ]),
    );
  }
}

/// Büyük yuvarlak düğme.
class PadButton extends StatelessWidget {
  final Color color;
  final Widget? child;
  final VoidCallback? onTap;
  final bool lit;
  final double size;
  const PadButton({super.key, required this.color, this.child, this.onTap, this.lit = false, this.size = 120});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: lit ? Color.lerp(color, Colors.white, 0.55) : color,
            borderRadius: BorderRadius.circular(size * 0.22),
            boxShadow: [BoxShadow(color: (lit ? color : Colors.black).withValues(alpha: lit ? 0.8 : 0.2), blurRadius: lit ? 18 : 4, offset: const Offset(0, 3))],
          ),
          child: child,
        ),
      );
}

int starsBy(double accuracy, {int hints = 0}) {
  var s = accuracy >= 0.95 ? 3 : (accuracy >= 0.85 ? 2 : 1);
  s -= hints;
  return s < 1 ? 1 : s;
}
