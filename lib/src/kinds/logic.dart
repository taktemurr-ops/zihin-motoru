import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/rng.dart';

import '../core.dart';
import '../studio_chrome.dart';
import '../texts.dart';
import 'dual.dart';
import 'faces.dart';
import 'memory.dart';
import 'speed.dart';

// ---------------------------------------------------------------- Örüntü tamamlama

/// Bir örüntü öğesi: sayı ya da şekil (ok açısı, nokta sayısı, renk).
class PItem {
  final int? number;
  final int angle; // 0..7 (45° adım)
  final int dots;
  final int color;
  const PItem.num(int n)
      : number = n,
        angle = 0,
        dots = 0,
        color = 0;
  const PItem.shape(this.angle, this.dots, this.color) : number = null;

  bool same(PItem o) => number == o.number && (number != null || (angle == o.angle && dots == o.dots && color == o.color));
}

class PatternQ {
  final List<PItem> seq;
  final List<PItem> options;
  final int answer;
  const PatternQ(this.seq, this.options, this.answer);
}

class PatternPuzzle extends BPuzzle {
  final List<PatternQ> qs;
  final int lives;
  const PatternPuzzle(this.qs, this.lives);
}

class PatternKind extends BrainKind {
  @override
  String get id => 'oruntu';
  const PatternKind();

  PatternQ? _numbers(int d, SeededRandom r) {
    final type = r.nextInt(d <= 3 ? 2 : (d <= 6 ? 4 : 6));
    final seq = <int>[];
    final a = r.range(1, 9 + d);
    final s = r.range(2, 3 + d);
    for (var i = 0; i < 6; i++) {
      switch (type) {
        case 0:
          seq.add(a + s * i);
        case 1:
          seq.add(a + 40 - s * i);
        case 2:
          seq.add(a * math.pow(2, i).toInt());
        case 3:
          seq.add(i.isEven ? a + i * s : a + i * s + 10);
        case 4:
          seq.add(a + i * (i + 1) ~/ 2 * s);
        default:
          seq.add(i < 2 ? a + i : seq[i - 1] + seq[i - 2]);
      }
    }
    final ans = seq.last;
    final opts = <int>{ans};
    var g = 0;
    while (opts.length < 4 && g++ < 40) {
      opts.add(ans + r.range(1, 6 + d) * (r.chance(0.5) ? 1 : -1));
    }
    if (opts.length < 4) return null;
    final list = opts.toList();
    r.shuffle(list);
    return PatternQ([for (final v in seq.take(5)) PItem.num(v)], [for (final v in list) PItem.num(v)], list.indexOf(ans));
  }

  PatternQ _shapes(int d, SeededRandom r) {
    final da = r.nextInt(3) + 1; // açı adımı
    final dd = d >= 5 ? r.nextInt(2) : 0; // nokta artışı
    final dc = d >= 7 ? 1 : 0; // renk döngüsü
    final a0 = r.nextInt(8), c0 = r.nextInt(4);
    PItem at(int i) => PItem.shape((a0 + da * i) % 8, 1 + (dd * i) % 4, (c0 + dc * i) % 4);
    final seq = [for (var i = 0; i < 5; i++) at(i)];
    final ans = at(5);
    final opts = <PItem>[ans];
    var g = 0;
    while (opts.length < 4 && g++ < 60) {
      final o = PItem.shape((ans.angle + r.range(1, 7)) % 8, r.chance(0.5) ? ans.dots : 1 + r.nextInt(4), r.chance(0.6) ? ans.color : r.nextInt(4));
      if (!opts.any(o.same)) opts.add(o);
    }
    r.shuffle(opts);
    return PatternQ(seq, opts, opts.indexWhere(ans.same));
  }

  @override
  BPuzzle? make(int d, SeededRandom r) {
    final qs = <PatternQ>[];
    for (var i = 0; i < 10; i++) {
      final q = r.chance(0.5) ? _numbers(d, r) : _shapes(d, r);
      if (q == null) return null;
      qs.add(q);
    }
    return PatternPuzzle(qs, d <= 5 ? 3 : 2);
  }

  @override
  bool check(BPuzzle p) => p is PatternPuzzle && p.qs.every((q) => q.answer >= 0 && q.options.length == 4);

  @override
  Widget build(BrainPlay play) => _PatternView(play: play);
}

class _ItemPainter extends CustomPainter {
  final PItem it;
  _ItemPainter(this.it);

  @override
  void paint(Canvas c, Size s) {
    final o = Offset(s.width / 2, s.height / 2);
    final col = BColors.pads[it.color % BColors.pads.length];
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(it.angle * math.pi / 4);
    final r = s.shortestSide * 0.36;
    final path = Path()
      ..moveTo(0, -r)
      ..lineTo(r * 0.6, 0)
      ..lineTo(r * 0.22, 0)
      ..lineTo(r * 0.22, r)
      ..lineTo(-r * 0.22, r)
      ..lineTo(-r * 0.22, 0)
      ..lineTo(-r * 0.6, 0)
      ..close();
    c.drawPath(path, Paint()..color = col);
    c.restore();
    for (var k = 0; k < it.dots; k++) {
      c.drawCircle(Offset(s.width * (0.2 + k * 0.2), s.height * 0.9), s.shortestSide * 0.05, Paint()..color = BColors.ink);
    }
  }

  @override
  bool shouldRepaint(covariant _ItemPainter old) => !old.it.same(it);
}

Widget itemView(PItem it, double size, {Color? bg}) => Container(
      width: size,
      height: size,
      margin: const EdgeInsets.all(3),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg ?? BColors.paper, borderRadius: BorderRadius.circular(10), border: Border.all(color: BColors.soft)),
      child: it.number != null
          ? FittedBox(child: Padding(padding: const EdgeInsets.all(4), child: Text('${it.number}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: BColors.ink))))
          : CustomPaint(size: Size(size, size), painter: _ItemPainter(it)),
    );

class _PatternView extends StatefulWidget {
  final BrainPlay play;
  const _PatternView({required this.play});

  @override
  State<_PatternView> createState() => _PatternViewState();
}

class _PatternViewState extends State<_PatternView> with Ticker {
  late PatternPuzzle p;
  int idx = 0, mistakes = 0, good = 0, hints = 0;
  int? picked;
  final Set<int> removed = {};

  BrainPlay get play => widget.play;

  @override
  void initState() {
    super.initState();
    p = play.puzzle as PatternPuzzle;
    startClock();
  }

  void _pick(int i) {
    if (ended || picked != null) return;
    final q = p.qs[idx];
    final ok = i == q.answer;
    setState(() {
      picked = i;
      if (ok) {
        good++;
      } else {
        mistakes++;
      }
    });
    play.ctx.sfx(ok ? Sfx.clear : Sfx.error);
    later(700, () {
      if (mistakes >= p.lives) {
        ended = true;
        return play.lose(seconds: seconds, correct: good, headline: '${bt(play.lang, 'correct')}: $good/${p.qs.length}');
      }
      if (idx + 1 >= p.qs.length) {
        ended = true;
        play.ctx.sfx(Sfx.win);
        return play.win(score: good * 50 - hints * 30, stars: 3 - mistakes - hints, seconds: seconds, correct: good, hints: hints);
      }
      setState(() {
        idx++;
        picked = null;
        removed.clear();
      });
    });
  }

  Future<void> _hint() async {
    if (ended || picked != null) return;
    final q = p.qs[idx];
    final w = [for (var i = 0; i < 4; i++) if (i != q.answer && !removed.contains(i)) i];
    if (w.length <= 1) return;
    if (!await play.ctx.requestHint()) return;
    if (!mounted) return;
    setState(() {
      hints++;
      removed.add(w.first);
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = p.qs[idx];
    final lang = play.lang;
    return Column(children: [
      BrainBar(lang: lang, left: '${idx + 1}/${p.qs.length}', status: '${bt(lang, 'lives')}: ${'♥' * (p.lives - mistakes)}', onHint: _hint),
      const SizedBox(height: 12),
      Text(bt(lang, 'whatNext'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      Expanded(
        child: LayoutBuilder(builder: (context, box) {
          final s = math.min(70.0, (box.maxWidth - 30) / 6 - 6);
          return Center(
            child: Wrap(alignment: WrapAlignment.center, children: [
              for (final it in q.seq) itemView(it, s),
              Container(
                width: s,
                height: s,
                margin: const EdgeInsets.all(3),
                alignment: Alignment.center,
                decoration: BoxDecoration(border: Border.all(color: StudioLook.of(context).accent, width: 2), borderRadius: BorderRadius.circular(10)),
                child: Text('?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: StudioLook.of(context).accent)),
              ),
            ]),
          );
        }),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
          for (var i = 0; i < 4; i++)
            if (!removed.contains(i))
              GestureDetector(
                onTap: () => _pick(i),
                child: itemView(q.options[i], 76,
                    bg: picked == null ? null : (i == q.answer ? BColors.good.withValues(alpha: 0.4) : (i == picked ? BColors.bad.withValues(alpha: 0.4) : null))),
              ),
        ]),
      ),
      const SizedBox(height: 10),
    ]);
  }
}

// ---------------------------------------------------------------- Uzamsal döndürme

List<int> _norm(List<int> cells) {
  // (x, y) → x*10+y; en küçük x ve y sıfıra.
  final xs = cells.map((c) => c ~/ 10), ys = cells.map((c) => c % 10);
  final mx = xs.reduce(math.min), my = ys.reduce(math.min);
  return [for (final c in cells) (c ~/ 10 - mx) * 10 + c % 10 - my]..sort();
}

List<int> _rot(List<int> cells) => _norm([for (final c in cells) (c % 10) * 10 + (9 - c ~/ 10)]);
List<int> _mirror(List<int> cells) => _norm([for (final c in cells) (9 - c ~/ 10) * 10 + c % 10]);
bool _eq(List<int> a, List<int> b) => a.length == b.length && [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);

class RotQ {
  final List<int> shape;
  final List<List<int>> options;
  final int answer;
  const RotQ(this.shape, this.options, this.answer);
}

class RotationPuzzle extends BPuzzle {
  final List<RotQ> qs;
  final int lives;
  const RotationPuzzle(this.qs, this.lives);
}

class RotationKind extends BrainKind {
  @override
  String get id => 'dondurme';
  const RotationKind();

  List<int>? _shape(int size, SeededRandom r) {
    final cells = <int>{44};
    var g = 0;
    while (cells.length < size && g++ < 200) {
      final c = r.pick(cells.toList());
      final dirs = [10, -10, 1, -1];
      final n = c + r.pick<int>(dirs);
      if (n ~/ 10 < 1 || n ~/ 10 > 8 || n % 10 < 1 || n % 10 > 8) continue;
      cells.add(n);
    }
    final s = _norm(cells.toList());
    // Ayna görüntüsü hiçbir döndürmeye eşit olmamalı (kiral şekil).
    final m = _mirror(s);
    var rr = s;
    for (var k = 0; k < 4; k++) {
      if (_eq(rr, m)) return null;
      rr = _rot(rr);
    }
    return s;
  }

  @override
  BPuzzle? make(int d, SeededRandom r) {
    final qs = <RotQ>[];
    var guard = 0;
    while (qs.length < 10 && guard++ < 200) {
      final s = _shape(4 + math.min(3, d ~/ 3), r);
      if (s == null) continue;
      var good = s;
      for (var k = 0; k < 1 + r.nextInt(3); k++) {
        good = _rot(good);
      }
      final opts = <List<int>>[good];
      var m = _mirror(s);
      for (var k = 0; k < 3; k++) {
        m = _rot(m);
        opts.add(m);
      }
      r.shuffle(opts);
      qs.add(RotQ(s, opts, opts.indexWhere((o) => _eq(o, good))));
    }
    if (qs.length < 10) return null;
    return RotationPuzzle(qs, d <= 5 ? 3 : 2);
  }

  @override
  bool check(BPuzzle p) {
    if (p is! RotationPuzzle) return false;
    for (final q in p.qs) {
      // Tam olarak bir seçenek, şeklin döndürülmüşü olmalı.
      var n = 0;
      for (final o in q.options) {
        var rr = q.shape;
        var hit = false;
        for (var k = 0; k < 4; k++) {
          if (_eq(rr, o)) hit = true;
          rr = _rot(rr);
        }
        if (hit) n++;
      }
      if (n != 1) return false;
    }
    return true;
  }

  @override
  Widget build(BrainPlay play) => _RotationView(play: play);
}

class _ShapePainter extends CustomPainter {
  final List<int> cells;
  final Color color;
  _ShapePainter(this.cells, this.color);

  @override
  void paint(Canvas c, Size s) {
    final w = cells.map((x) => x ~/ 10).reduce(math.max) + 1, h = cells.map((x) => x % 10).reduce(math.max) + 1;
    final cs = math.min(s.width / (math.max(w, h) + 1), s.height / (math.max(w, h) + 1));
    final ox = (s.width - cs * w) / 2, oy = (s.height - cs * h) / 2;
    for (final cell in cells) {
      final r = Rect.fromLTWH(ox + (cell ~/ 10) * cs, oy + (cell % 10) * cs, cs - 2, cs - 2);
      c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(cs * 0.15)), Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _RotationView extends StatefulWidget {
  final BrainPlay play;
  const _RotationView({required this.play});

  @override
  State<_RotationView> createState() => _RotationViewState();
}

class _RotationViewState extends State<_RotationView> with Ticker {
  late RotationPuzzle p;
  int idx = 0, mistakes = 0, good = 0;
  int? picked;

  BrainPlay get play => widget.play;

  @override
  void initState() {
    super.initState();
    p = play.puzzle as RotationPuzzle;
    startClock();
  }

  void _pick(int i) {
    if (ended || picked != null) return;
    final ok = i == p.qs[idx].answer;
    setState(() {
      picked = i;
      if (ok) {
        good++;
      } else {
        mistakes++;
      }
    });
    play.ctx.sfx(ok ? Sfx.clear : Sfx.error);
    later(800, () {
      if (mistakes >= p.lives) {
        ended = true;
        return play.lose(seconds: seconds, correct: good, headline: '${bt(play.lang, 'correct')}: $good/${p.qs.length}');
      }
      if (idx + 1 >= p.qs.length) {
        ended = true;
        play.ctx.sfx(Sfx.win);
        return play.win(score: good * 50 + math.max(0, 300 - seconds), stars: 3 - mistakes, seconds: seconds, correct: good);
      }
      setState(() {
        idx++;
        picked = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = p.qs[idx];
    final lang = play.lang;
    return Column(children: [
      BrainBar(lang: lang, left: '${idx + 1}/${p.qs.length}', status: '${bt(lang, 'lives')}: ${'♥' * (p.lives - mistakes)}'),
      const SizedBox(height: 10),
      Text(bt(lang, 'whichRotation'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      Expanded(child: Center(child: CustomPaint(size: const Size(150, 150), painter: _ShapePainter(q.shape, BColors.accent)))),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
          for (var i = 0; i < q.options.length; i++)
            GestureDetector(
              onTap: () => _pick(i),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: picked == null ? BColors.paper : (i == q.answer ? BColors.good.withValues(alpha: 0.35) : (i == picked ? BColors.bad.withValues(alpha: 0.35) : BColors.paper)),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: BColors.soft),
                ),
                child: CustomPaint(painter: _ShapePainter(q.options[i], BColors.pads[(i + idx) % 4])),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 10),
    ]);
  }
}

// ---------------------------------------------------------------- Günlük beyin programı

class DailyPuzzle extends BPuzzle {
  final List<String> kinds;
  final List<BPuzzle> parts;
  final int d;
  const DailyPuzzle(this.kinds, this.parts, this.d);
}

const Map<String, BrainKind> _dailyPool = {
  'hafiza-dizisi': SequenceKind(),
  'gorsel-hafiza': GridMemoryKind(),
  'stroop': StroopKind(),
  'schulte': SchulteKind(),
  'hizli-hesap': MathKind(),
  'oruntu': PatternKind(),
  'dondurme': RotationKind(),
  'yuz-isim': FaceNameKind(),
  'cift-gorev': DualTaskKind(),
};

class DailyKind extends BrainKind {
  @override
  String get id => 'gunluk-program';
  const DailyKind();

  @override
  BPuzzle? make(int d, SeededRandom r) {
    final keys = _dailyPool.keys.toList();
    r.shuffle(keys);
    final pick = keys.take(3).toList();
    final sd = math.max(1, d - 2);
    final parts = <BPuzzle>[];
    for (final k in pick) {
      final p = _dailyPool[k]!.make(sd, r);
      if (p == null || !_dailyPool[k]!.check(p)) return null;
      parts.add(p);
    }
    return DailyPuzzle(pick, parts, sd);
  }

  @override
  bool check(BPuzzle p) => p is DailyPuzzle && p.parts.length == 3;

  @override
  Widget build(BrainPlay play) => _DailyView(play: play);
}

class _DailyView extends StatefulWidget {
  final BrainPlay play;
  const _DailyView({required this.play});

  @override
  State<_DailyView> createState() => _DailyViewState();
}

class _DailyViewState extends State<_DailyView> {
  late DailyPuzzle p;
  int part = 0, correct = 0, stars = 0, wins = 0;

  BrainPlay get play => widget.play;

  @override
  void initState() {
    super.initState();
    p = play.puzzle as DailyPuzzle;
  }

  void _done(bool won, int c, int s) {
    correct += c;
    if (won) {
      wins++;
      stars += s.clamp(1, 3);
    }
    if (part + 1 >= p.parts.length) {
      if (wins >= 2) {
        play.win(score: correct * 20 + wins * 100, stars: (stars / 3).round(), correct: correct);
      } else {
        play.lose(correct: correct, headline: '$wins/3');
      }
      return;
    }
    setState(() => part++);
  }

  @override
  Widget build(BuildContext context) {
    final sub = BrainPlay(ctx: play.ctx, puzzle: p.parts[part], d: p.d, seed: play.seed + part, relay: _done);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 46,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(color: i <= part ? BColors.accent : BColors.soft, borderRadius: BorderRadius.circular(4)),
            ),
        ]),
      ),
      Expanded(child: KeyedSubtree(key: ValueKey(part), child: _dailyPool[p.kinds[part]]!.build(sub))),
    ]);
  }
}
