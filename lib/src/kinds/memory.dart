import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/rng.dart';

import '../core.dart';
import '../texts.dart';

// ---------------------------------------------------------------- Hafıza dizisi

class SequencePuzzle extends BPuzzle {
  final List<int> seq;
  final int pads;
  final int speed;
  const SequencePuzzle(this.seq, this.pads, this.speed);
}

class SequenceKind extends BrainKind {
  @override
  String get id => 'hafiza-dizisi';
  const SequenceKind();

  @override
  BPuzzle? make(int d, SeededRandom r) {
    final pads = d <= 5 ? 4 : 6;
    final seq = <int>[];
    for (var i = 0; i < 4 + d; i++) {
      var v = r.nextInt(pads);
      if (i >= 2 && v == seq[i - 1] && v == seq[i - 2]) v = (v + 1) % pads;
      seq.add(v);
    }
    return SequencePuzzle(seq, pads, 650 - d * 35);
  }

  @override
  bool check(BPuzzle p) => p is SequencePuzzle && p.seq.length >= 5 && p.seq.every((v) => v >= 0 && v < p.pads);

  @override
  Widget build(BrainPlay play) => _SequenceView(play: play);
}

class _SequenceView extends StatefulWidget {
  final BrainPlay play;
  const _SequenceView({required this.play});

  @override
  State<_SequenceView> createState() => _SequenceViewState();
}

class _SequenceViewState extends State<_SequenceView> with Ticker {
  late SequencePuzzle p;
  int round = 1, pos = 0, lives = 3, lit = -1, mistakes = 0;
  bool showing = false;

  BrainPlay get play => widget.play;

  @override
  void initState() {
    super.initState();
    p = play.puzzle as SequencePuzzle;
    startClock();
    later(700, _show);
  }

  void _show() {
    setState(() {
      showing = true;
      pos = 0;
    });
    for (var i = 0; i < round; i++) {
      later(i * p.speed, () {
        setState(() => lit = p.seq[i]);
        play.ctx.sfx(Sfx.tap);
      });
      later(i * p.speed + (p.speed * 0.6).round(), () => setState(() => lit = -1));
    }
    later(round * p.speed, () => setState(() => showing = false));
  }

  void _tap(int k) {
    if (showing || ended) return;
    setState(() => lit = k);
    later(180, () => setState(() => lit = -1));
    if (p.seq[pos] != k) {
      play.ctx.sfx(Sfx.error);
      setState(() {
        lives--;
        mistakes++;
      });
      if (lives <= 0) {
        ended = true;
        later(600, () => play.lose(seconds: seconds, correct: round - 1, headline: '${bt(play.lang, 'step')}: ${round - 1}/${p.seq.length}'));
        return;
      }
      later(800, _show);
      return;
    }
    pos++;
    play.ctx.sfx(Sfx.place);
    if (pos == round) {
      if (round == p.seq.length) {
        ended = true;
        play.ctx.sfx(Sfx.win);
        later(500, () => play.win(score: 200 + p.seq.length * 40 - mistakes * 50, stars: 3 - mistakes, seconds: seconds, correct: p.seq.length));
        return;
      }
      setState(() => round++);
      later(700, _show);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = play.lang;
    return Column(children: [
      BrainBar(lang: lang, left: '${bt(lang, 'step')} $round/${p.seq.length}', status: '${bt(lang, 'lives')}: ${'♥' * lives}'),
      const SizedBox(height: 12),
      Text(showing ? bt(lang, 'watch') : bt(lang, 'yourTurn'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
      Expanded(
        child: LayoutBuilder(builder: (context, box) {
          final cols = p.pads == 4 ? 2 : 3;
          final rows = (p.pads / cols).ceil();
          final s = math.min((box.maxWidth - 40) / cols, (box.maxHeight - 40) / rows) - 14;
          return Center(
            child: Wrap(spacing: 14, runSpacing: 14, alignment: WrapAlignment.center, children: [
              for (var k = 0; k < p.pads; k++) PadButton(color: BColors.pads[k], lit: lit == k, size: s, onTap: () => _tap(k)),
            ]),
          );
        }),
      ),
    ]);
  }
}

// ---------------------------------------------------------------- Görsel hafıza ızgarası

class GridMemPuzzle extends BPuzzle {
  final int n;
  final List<List<int>> rounds;
  final int showMs;
  const GridMemPuzzle(this.n, this.rounds, this.showMs);
}

class GridMemoryKind extends BrainKind {
  @override
  String get id => 'gorsel-hafiza';
  const GridMemoryKind();

  @override
  BPuzzle? make(int d, SeededRandom r) {
    final n = 3 + math.min(3, d ~/ 3);
    final rounds = <List<int>>[];
    for (var k = 0; k < 5; k++) {
      final c = math.min(n * n - 2, 3 + k + d ~/ 2);
      final cells = [for (var i = 0; i < n * n; i++) i];
      r.shuffle(cells);
      rounds.add(cells.take(c).toList()..sort());
    }
    return GridMemPuzzle(n, rounds, 1600 - d * 70);
  }

  @override
  bool check(BPuzzle p) => p is GridMemPuzzle && p.rounds.length == 5 && p.rounds.every((r) => r.toSet().length == r.length);

  @override
  Widget build(BrainPlay play) => _GridMemView(play: play);
}

class _GridMemView extends StatefulWidget {
  final BrainPlay play;
  const _GridMemView({required this.play});

  @override
  State<_GridMemView> createState() => _GridMemViewState();
}

class _GridMemViewState extends State<_GridMemView> with Ticker {
  late GridMemPuzzle p;
  int round = 0, lives = 3, correct = 0;
  bool showing = true;
  final Set<int> picked = {};
  final Set<int> wrong = {};

  BrainPlay get play => widget.play;
  List<int> get target => p.rounds[round];

  @override
  void initState() {
    super.initState();
    p = play.puzzle as GridMemPuzzle;
    startClock();
    _show();
  }

  void _show() {
    setState(() {
      showing = true;
      picked.clear();
      wrong.clear();
    });
    later(p.showMs + target.length * 120, () => setState(() => showing = false));
  }

  void _tap(int i) {
    if (showing || ended || picked.contains(i) || wrong.contains(i)) return;
    if (target.contains(i)) {
      setState(() => picked.add(i));
      play.ctx.sfx(Sfx.place);
      correct++;
      if (picked.length == target.length) {
        play.ctx.sfx(Sfx.clear);
        if (round + 1 == p.rounds.length) {
          ended = true;
          play.ctx.sfx(Sfx.win);
          later(500, () => play.win(score: 300 + correct * 10 - (3 - lives) * 60, stars: lives, seconds: seconds, correct: correct));
          return;
        }
        later(500, () {
          setState(() => round++);
          _show();
        });
      }
    } else {
      setState(() {
        wrong.add(i);
        lives--;
      });
      play.ctx.sfx(Sfx.error);
      if (lives <= 0) {
        ended = true;
        later(700, () => play.lose(seconds: seconds, correct: correct));
        return;
      }
      later(700, _show);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = play.lang;
    return Column(children: [
      BrainBar(lang: lang, left: '${round + 1}/${p.rounds.length}', status: '${bt(lang, 'lives')}: ${'♥' * lives}'),
      const SizedBox(height: 10),
      Text(showing ? bt(lang, 'watch') : bt(lang, 'yourTurn'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
      Expanded(
        child: LayoutBuilder(builder: (context, box) {
          final s = math.min(box.maxWidth - 30, box.maxHeight - 30) / p.n;
          return Center(
            child: SizedBox(
              width: s * p.n,
              height: s * p.n,
              child: GridView.count(
                crossAxisCount: p.n,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var i = 0; i < p.n * p.n; i++)
                    GestureDetector(
                      onTap: () => _tap(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: (showing && target.contains(i)) || picked.contains(i)
                              ? BColors.accent
                              : (wrong.contains(i) ? BColors.bad : BColors.soft),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    ]);
  }
}

// ---------------------------------------------------------------- N-geri

class NBackPuzzle extends BPuzzle {
  final int n;
  final List<int> stream;
  final int interval;
  const NBackPuzzle(this.n, this.stream, this.interval);

  bool isMatch(int i) => i >= n && stream[i] == stream[i - n];
}

class NBackKind extends BrainKind {
  @override
  String get id => 'n-geri';
  const NBackKind();

  @override
  BPuzzle? make(int d, SeededRandom r) {
    final n = d <= 3 ? 1 : (d <= 7 ? 2 : 3);
    final len = 18 + n * 4;
    final s = <int>[];
    for (var i = 0; i < len; i++) {
      if (i >= n && r.chance(0.3)) {
        s.add(s[i - n]);
      } else {
        var v = r.nextInt(9);
        if (i >= n && v == s[i - n]) v = (v + 1 + r.nextInt(8)) % 9;
        s.add(v);
      }
    }
    return NBackPuzzle(n, s, 2300 - d * 90);
  }

  @override
  bool check(BPuzzle p) {
    if (p is! NBackPuzzle) return false;
    var m = 0;
    for (var i = 0; i < p.stream.length; i++) {
      if (p.isMatch(i)) m++;
    }
    return m >= 3;
  }

  @override
  Widget build(BrainPlay play) => _NBackView(play: play);
}

class _NBackView extends StatefulWidget {
  final BrainPlay play;
  const _NBackView({required this.play});

  @override
  State<_NBackView> createState() => _NBackViewState();
}

class _NBackViewState extends State<_NBackView> with Ticker {
  late NBackPuzzle p;
  int idx = -1, good = 0, hits = 0;
  bool pressed = false, started = false, visible = false;
  String feedback = '';

  BrainPlay get play => widget.play;

  @override
  void initState() {
    super.initState();
    p = play.puzzle as NBackPuzzle;
  }

  void _start() {
    setState(() => started = true);
    startClock();
    _next();
  }

  void _next() {
    // Önceki uyaranı değerlendir.
    if (idx >= 0) {
      final m = p.isMatch(idx);
      if (m == pressed) good++;
      if (m && pressed) hits++;
    }
    if (idx + 1 >= p.stream.length) return _finish();
    setState(() {
      idx++;
      pressed = false;
      visible = true;
      feedback = '';
    });
    later((p.interval * 0.6).round(), () => setState(() => visible = false));
    later(p.interval, _next);
  }

  void _press() {
    if (!started || ended || pressed || idx < 0) return;
    setState(() {
      pressed = true;
      feedback = p.isMatch(idx) ? '✓' : '✗';
    });
    play.ctx.sfx(p.isMatch(idx) ? Sfx.place : Sfx.error);
  }

  void _finish() {
    ended = true;
    final acc = good / p.stream.length;
    if (acc >= 0.75) {
      play.ctx.sfx(Sfx.win);
      play.win(score: (acc * 500).round() + hits * 20, stars: starsBy(acc), seconds: seconds, correct: good);
    } else {
      play.ctx.sfx(Sfx.lose);
      play.lose(seconds: seconds, correct: good, headline: '${bt(play.lang, 'accuracy')}: ${(acc * 100).round()}%');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = play.lang;
    return Column(children: [
      BrainBar(lang: lang, left: '${p.n}-back', status: started ? '${idx + 1}/${p.stream.length}' : bt(lang, 'tapWhenSame')),
      Expanded(
        child: LayoutBuilder(builder: (context, box) {
          final s = math.min(box.maxWidth - 40, box.maxHeight - 40) / 3;
          return Center(
            child: SizedBox(
              width: s * 3,
              height: s * 3,
              child: Stack(children: [
                for (var i = 0; i < 9; i++)
                  Positioned(
                    left: (i % 3) * s,
                    top: (i ~/ 3) * s,
                    child: Container(
                      width: s - 8,
                      height: s - 8,
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: visible && idx >= 0 && p.stream[idx] == i ? BColors.accent : BColors.soft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
              ]),
            ),
          );
        }),
      ),
      Text(feedback, style: TextStyle(fontSize: 28, color: feedback == '✓' ? BColors.good : BColors.bad)),
      Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: double.infinity,
          height: 64,
          child: FilledButton(
            onPressed: started ? _press : _start,
            child: Text(started ? bt(lang, 'match') : bt(lang, 'go'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    ]);
  }
}
