import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/rng.dart';

import '../core.dart';
import '../texts.dart';

/// Stroop renkleri (kırmızı, mavi, yeşil, sarı, mor, turuncu).
const kInkColors = [Color(0xFFD64545), Color(0xFF3D7CC9), Color(0xFF3FA35B), Color(0xFFE3B21E), Color(0xFF8E5CB5), Color(0xFFEE8434)];

// ---------------------------------------------------------------- Renk-kelime (Stroop)

class StroopPuzzle extends BPuzzle {
  final int colors;
  final List<int> words, inks;
  final int ms;
  const StroopPuzzle(this.colors, this.words, this.inks, this.ms);
}

class StroopKind extends BrainKind {
  @override
  String get id => 'stroop';
  const StroopKind();

  @override
  BPuzzle? make(int d, SeededRandom r) {
    final k = d <= 4 ? 4 : 6;
    final n = 16 + d;
    final w = <int>[], c = <int>[];
    for (var i = 0; i < n; i++) {
      final word = r.nextInt(k);
      var ink = r.nextInt(k);
      if (r.chance(0.75) && ink == word) ink = (ink + 1 + r.nextInt(k - 1)) % k;
      w.add(word);
      c.add(ink);
    }
    return StroopPuzzle(k, w, c, 3200 - d * 160);
  }

  @override
  bool check(BPuzzle p) => p is StroopPuzzle && p.words.length == p.inks.length && p.inks.every((x) => x < p.colors);

  @override
  Widget build(BrainPlay play) => _StroopView(play: play);
}

class _StroopView extends StatefulWidget {
  final BrainPlay play;
  const _StroopView({required this.play});

  @override
  State<_StroopView> createState() => _StroopViewState();
}

class _StroopViewState extends State<_StroopView> with Ticker {
  late StroopPuzzle p;
  int idx = 0, good = 0, token = 0;
  String fb = '';

  BrainPlay get play => widget.play;

  @override
  void initState() {
    super.initState();
    p = play.puzzle as StroopPuzzle;
    startClock();
    _arm();
  }

  void _arm() {
    final t = ++token;
    later(p.ms, () {
      if (t == token && !ended) _answer(-1);
    });
  }

  void _answer(int c) {
    if (ended) return;
    final ok = c == p.inks[idx];
    if (ok) good++;
    play.ctx.sfx(ok ? Sfx.place : Sfx.error);
    setState(() => fb = ok ? '✓' : '✗');
    if (idx + 1 >= p.words.length) {
      ended = true;
      final acc = good / p.words.length;
      later(400, () {
        if (acc >= 0.8) {
          play.win(score: (acc * 600).round(), stars: starsBy(acc), seconds: seconds, correct: good);
        } else {
          play.lose(seconds: seconds, correct: good, headline: '${bt(play.lang, 'accuracy')}: ${(acc * 100).round()}%');
        }
      });
      return;
    }
    setState(() => idx++);
    _arm();
  }

  @override
  Widget build(BuildContext context) {
    final lang = play.lang;
    return Column(children: [
      BrainBar(lang: lang, left: '${idx + 1}/${p.words.length}', status: bt(lang, 'inkColor')),
      Expanded(
        child: Center(
          child: FittedBox(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(colorName(lang, p.words[idx]),
                  style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: kInkColors[p.inks[idx]])),
            ),
          ),
        ),
      ),
      Text(fb, style: TextStyle(fontSize: 26, color: fb == '✓' ? BColors.good : BColors.bad)),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
          for (var c = 0; c < p.colors; c++) PadButton(color: kInkColors[c], size: 72, onTap: () => _answer(c)),
        ]),
      ),
      const SizedBox(height: 8),
    ]);
  }
}

// ---------------------------------------------------------------- Sayı tablosu (Schulte)

class SchultePuzzle extends BPuzzle {
  final int n;
  final List<int> cells;
  final int time;
  const SchultePuzzle(this.n, this.cells, this.time);
}

class SchulteKind extends BrainKind {
  @override
  String get id => 'schulte';
  const SchulteKind();

  @override
  BPuzzle? make(int d, SeededRandom r) {
    final n = d <= 2 ? 3 : (d <= 5 ? 4 : (d <= 8 ? 5 : 6));
    final cells = [for (var i = 1; i <= n * n; i++) i];
    r.shuffle(cells);
    return SchultePuzzle(n, cells, (n * n * (3.4 - d * 0.14)).round() + 5);
  }

  @override
  bool check(BPuzzle p) => p is SchultePuzzle && p.cells.toSet().length == p.n * p.n;

  @override
  Widget build(BrainPlay play) => _SchulteView(play: play);
}

class _SchulteView extends StatefulWidget {
  final BrainPlay play;
  const _SchulteView({required this.play});

  @override
  State<_SchulteView> createState() => _SchulteViewState();
}

class _SchulteViewState extends State<_SchulteView> with Ticker {
  late SchultePuzzle p;
  int next = 1, misses = 0;
  int? flashBad;

  BrainPlay get play => widget.play;

  @override
  void initState() {
    super.initState();
    p = play.puzzle as SchultePuzzle;
    startClock();
  }

  @override
  void onSecond() {
    if (ended || seconds < p.time) return;
    ended = true;
    play.ctx.sfx(Sfx.lose);
    play.lose(seconds: seconds, correct: next - 1, headline: '${next - 1}/${p.n * p.n}');
  }

  void _tap(int i) {
    if (ended) return;
    if (p.cells[i] == next) {
      play.ctx.sfx(Sfx.tap);
      setState(() => next++);
      if (next > p.n * p.n) {
        ended = true;
        play.ctx.sfx(Sfx.win);
        final spare = p.time - seconds;
        play.win(
          score: 200 + spare * 10 - misses * 20,
          stars: misses <= 1 && spare > p.time * 0.3 ? 3 : (misses <= 4 ? 2 : 1),
          seconds: seconds,
          correct: p.n * p.n,
        );
      }
    } else {
      misses++;
      play.ctx.sfx(Sfx.error);
      setState(() => flashBad = i);
      later(250, () => setState(() => flashBad = null));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = play.lang;
    return Column(children: [
      BrainBar(lang: lang, left: clock(math.max(0, p.time - seconds)), status: '→ $next'),
      Expanded(
        child: LayoutBuilder(builder: (context, box) {
          final s = math.min(box.maxWidth - 24, box.maxHeight - 24) / p.n;
          return Center(
            child: SizedBox(
              width: s * p.n,
              height: s * p.n,
              child: GridView.count(
                crossAxisCount: p.n,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var i = 0; i < p.cells.length; i++)
                    GestureDetector(
                      onTap: () => _tap(i),
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: flashBad == i ? BColors.bad : (p.cells[i] < next ? BColors.soft : BColors.paper),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: BColors.ink.withValues(alpha: 0.3)),
                        ),
                        child: Text('${p.cells[i]}',
                            style: TextStyle(
                              fontSize: s * 0.38,
                              fontWeight: FontWeight.w800,
                              color: p.cells[i] < next ? BColors.ink.withValues(alpha: 0.3) : BColors.ink,
                            )),
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

// ---------------------------------------------------------------- Hızlı hesap

class MathQ {
  final String text;
  final List<int> options;
  final int answer;
  const MathQ(this.text, this.options, this.answer);
}

class MathPuzzle extends BPuzzle {
  final List<MathQ> qs;
  final int time;
  final int need;
  const MathPuzzle(this.qs, this.time, this.need);
}

class MathKind extends BrainKind {
  @override
  String get id => 'hizli-hesap';
  const MathKind();

  @override
  BPuzzle? make(int d, SeededRandom r) {
    final qs = <MathQ>[];
    final top = 9 + d * 6;
    for (var i = 0; i < 15; i++) {
      final op = r.nextInt(d <= 3 ? 2 : (d <= 6 ? 3 : 4));
      int a, b, ans;
      String t;
      switch (op) {
        case 0:
          a = r.range(1, top);
          b = r.range(1, top);
          ans = a + b;
          t = '$a + $b';
        case 1:
          a = r.range(2, top);
          b = r.range(1, a);
          ans = a - b;
          t = '$a − $b';
        case 2:
          a = r.range(2, 5 + d);
          b = r.range(2, 9 + d ~/ 2);
          ans = a * b;
          t = '$a × $b';
        default:
          b = r.range(2, 9);
          ans = r.range(2, 4 + d);
          a = ans * b;
          t = '$a ÷ $b';
      }
      final opts = <int>{ans};
      var guard = 0;
      while (opts.length < 4 && guard++ < 40) {
        final delta = r.range(1, math.max(3, ans ~/ 5 + 2)) * (r.chance(0.5) ? 1 : -1);
        if (ans + delta >= 0) opts.add(ans + delta);
      }
      if (opts.length < 4) return null;
      final list = opts.toList();
      r.shuffle(list);
      qs.add(MathQ(t, list, ans));
    }
    return MathPuzzle(qs, 100 - d * 5, 12);
  }

  @override
  bool check(BPuzzle p) => p is MathPuzzle && p.qs.every((q) => q.options.contains(q.answer) && q.options.toSet().length == 4);

  @override
  Widget build(BrainPlay play) => _MathView(play: play);
}

class _MathView extends StatefulWidget {
  final BrainPlay play;
  const _MathView({required this.play});

  @override
  State<_MathView> createState() => _MathViewState();
}

class _MathViewState extends State<_MathView> with Ticker {
  late MathPuzzle p;
  int idx = 0, good = 0;
  String fb = '';

  BrainPlay get play => widget.play;

  @override
  void initState() {
    super.initState();
    p = play.puzzle as MathPuzzle;
    startClock();
  }

  @override
  void onSecond() {
    if (ended || seconds < p.time) return;
    _finish();
  }

  void _finish() {
    if (ended) return;
    ended = true;
    if (good >= p.need) {
      play.ctx.sfx(Sfx.win);
      play.win(score: good * 40 + (p.time - seconds) * 3, stars: good >= 15 ? 3 : (good >= 13 ? 2 : 1), seconds: seconds, correct: good);
    } else {
      play.ctx.sfx(Sfx.lose);
      play.lose(seconds: seconds, correct: good, headline: '${bt(play.lang, 'correct')}: $good/${p.need}');
    }
  }

  void _answer(int v) {
    if (ended) return;
    final ok = v == p.qs[idx].answer;
    if (ok) good++;
    play.ctx.sfx(ok ? Sfx.place : Sfx.error);
    setState(() => fb = ok ? '✓' : '✗');
    if (idx + 1 >= p.qs.length) return _finish();
    setState(() => idx++);
  }

  @override
  Widget build(BuildContext context) {
    final q = p.qs[idx];
    return Column(children: [
      BrainBar(lang: play.lang, left: clock(math.max(0, p.time - seconds)), status: '${idx + 1}/${p.qs.length} · ${bt(play.lang, 'correct')}: $good'),
      Expanded(
        child: Center(
          child: FittedBox(child: Text('${q.text} = ?', style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: BColors.ink))),
        ),
      ),
      Text(fb, style: TextStyle(fontSize: 26, color: fb == '✓' ? BColors.good : BColors.bad)),
      Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          childAspectRatio: 2.4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final o in q.options)
              FilledButton.tonal(onPressed: () => _answer(o), child: Text('$o', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800))),
          ],
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------- Tepki ve odak (yap / yapma)

class ReactionPuzzle extends BPuzzle {
  final List<bool> go;
  final List<int> delays;
  final int window;
  const ReactionPuzzle(this.go, this.delays, this.window);
}

class ReactionKind extends BrainKind {
  @override
  String get id => 'tepki';
  const ReactionKind();

  @override
  BPuzzle? make(int d, SeededRandom r) {
    final n = 22 + d;
    return ReactionPuzzle(
      [for (var i = 0; i < n; i++) !r.chance(0.3)],
      [for (var i = 0; i < n; i++) r.range(500, 1500)],
      950 - d * 45,
    );
  }

  @override
  bool check(BPuzzle p) => p is ReactionPuzzle && p.go.where((g) => g).length >= 5 && p.go.contains(false);

  @override
  Widget build(BrainPlay play) => _ReactionView(play: play);
}

class _ReactionView extends StatefulWidget {
  final BrainPlay play;
  const _ReactionView({required this.play});

  @override
  State<_ReactionView> createState() => _ReactionViewState();
}

class _ReactionViewState extends State<_ReactionView> with Ticker {
  late ReactionPuzzle p;
  int idx = -1, good = 0, token = 0;
  bool showing = false, started = false, responded = false;
  final Stopwatch sw = Stopwatch();
  final List<int> times = [];
  String fb = '';

  BrainPlay get play => widget.play;

  @override
  void initState() {
    super.initState();
    p = play.puzzle as ReactionPuzzle;
  }

  void _start() {
    setState(() => started = true);
    startClock();
    _next();
  }

  void _next() {
    if (idx + 1 >= p.go.length) return _finish();
    setState(() {
      idx++;
      showing = false;
      responded = false;
    });
    final t = ++token;
    later(p.delays[idx], () {
      if (t != token) return;
      setState(() => showing = true);
      sw
        ..reset()
        ..start();
      later(p.window, () {
        if (t != token) return;
        // Süre doldu: yeşilde dokunmamak hata, kırmızıda beklemek doğru.
        if (!responded) {
          if (!p.go[idx]) {
            good++;
            fb = '✓';
          } else {
            fb = '…';
          }
        }
        _next();
      });
    });
  }

  void _tap() {
    if (!started) return _start();
    if (ended || responded) return;
    if (!showing) {
      play.ctx.sfx(Sfx.error);
      setState(() => fb = '✗');
      return;
    }
    responded = true;
    final ok = p.go[idx];
    if (ok) {
      good++;
      times.add(sw.elapsedMilliseconds);
    }
    play.ctx.sfx(ok ? Sfx.place : Sfx.error);
    setState(() => fb = ok ? '${sw.elapsedMilliseconds} ms' : '✗');
  }

  void _finish() {
    ended = true;
    final acc = good / p.go.length;
    final avg = times.isEmpty ? 0 : times.reduce((a, b) => a + b) ~/ times.length;
    if (acc >= 0.8) {
      play.ctx.sfx(Sfx.win);
      play.win(score: (acc * 400).round() + math.max(0, 600 - avg), stars: starsBy(acc), seconds: seconds, correct: good);
    } else {
      play.ctx.sfx(Sfx.lose);
      play.lose(seconds: seconds, correct: good, headline: '${bt(play.lang, 'accuracy')}: ${(acc * 100).round()}%');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = play.lang;
    final color = !showing || idx < 0 ? BColors.soft : (p.go[idx] ? BColors.good : BColors.bad);
    return Column(children: [
      BrainBar(lang: lang, left: started ? '${idx + 1}/${p.go.length}' : '', status: bt(lang, 'tapGreen')),
      Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _tap(),
          child: Center(
            child: LayoutBuilder(builder: (context, box) {
              final s = math.min(box.maxWidth, box.maxHeight) * 0.7;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 60),
                width: s,
                height: s,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Text(started ? fb : bt(lang, 'go'),
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white)),
              );
            }),
          ),
        ),
      ),
    ]);
  }
}
