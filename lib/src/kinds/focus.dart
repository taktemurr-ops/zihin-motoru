import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/rng.dart';
import 'package:studio_core/core/strings.dart';

import '../core.dart';
import '../texts.dart';
import '../words.dart';

// ================================================================ Rakam dizisi (digit span)

class DigitRound {
  final List<int> digits;

  /// true: tersten girilir.
  final bool back;
  const DigitRound(this.digits, this.back);
}

class DigitPuzzle extends BPuzzle {
  final List<DigitRound> rounds;
  final int ms;
  const DigitPuzzle(this.rounds, this.ms);
}

class DigitSpanKind extends BrainKind {
  @override
  String get id => 'rakam-dizisi';
  const DigitSpanKind();

  @override
  BPuzzle? make(int d, SeededRandom r) {
    final rounds = <DigitRound>[];
    final base = 3 + d ~/ 2;
    for (var k = 0; k < 6; k++) {
      final back = d >= 6 ? k.isOdd : (d >= 3 && k == 5);
      final len = base + k ~/ 2 - (back ? 1 : 0);
      final ds = <int>[];
      while (ds.length < len) {
        final v = r.nextInt(10);
        // Art arda aynı rakam ve basit ardışıklıklar (1-2-3) olmasın.
        if (ds.isNotEmpty && (v == ds.last || (ds.length >= 2 && v - ds.last == ds.last - ds[ds.length - 2] && (v - ds.last).abs() == 1))) continue;
        ds.add(v);
      }
      rounds.add(DigitRound(ds, back));
    }
    return DigitPuzzle(rounds, 1000 - d * 45);
  }

  @override
  bool check(BPuzzle p) {
    if (p is! DigitPuzzle || p.rounds.length != 6 || p.ms < 400) return false;
    for (final rd in p.rounds) {
      if (rd.digits.length < 2 || rd.digits.any((x) => x < 0 || x > 9)) return false;
      for (var i = 1; i < rd.digits.length; i++) {
        if (rd.digits[i] == rd.digits[i - 1]) return false;
      }
    }
    return true;
  }

  @override
  Widget build(BrainPlay play) => _DigitView(play: play);
}

/// Girilmesi beklenen dizi.
List<int> digitAnswer(DigitRound rd) => rd.back ? rd.digits.reversed.toList() : rd.digits;

class _DigitView extends StatefulWidget {
  final BrainPlay play;
  const _DigitView({required this.play});

  @override
  State<_DigitView> createState() => _DigitViewState();
}

class _DigitViewState extends State<_DigitView> with Ticker {
  late DigitPuzzle p;
  int round = 0, lives = 3, correct = 0, shown = -1, token = 0;
  bool showing = true;
  bool? lastOk;
  final List<int> typed = [];

  BrainPlay get play => widget.play;
  DigitRound get rd => p.rounds[round];

  @override
  void initState() {
    super.initState();
    p = play.puzzle as DigitPuzzle;
    startClock();
    later(600, _show);
  }

  void _show() {
    final t = ++token;
    setState(() {
      showing = true;
      typed.clear();
      lastOk = null;
      shown = -1;
    });
    for (var i = 0; i < rd.digits.length; i++) {
      later(i * p.ms, () {
        if (t != token) return;
        setState(() => shown = i);
        play.ctx.sfx(Sfx.tap);
      });
      later(i * p.ms + (p.ms * 0.7).round(), () {
        if (t == token) setState(() => shown = -1);
      });
    }
    later(rd.digits.length * p.ms, () {
      if (t == token) setState(() => showing = false);
    });
  }

  void _key(int k) {
    if (showing || ended || lastOk != null) return;
    if (k < 0) {
      if (typed.isNotEmpty) {
        setState(() {
          typed.removeLast();
        });
      }
      return;
    }
    setState(() => typed.add(k));
    play.ctx.sfx(Sfx.place);
    if (typed.length < rd.digits.length) return;
    final want = digitAnswer(rd);
    final ok = List.generate(want.length, (i) => want[i] == typed[i]).every((x) => x);
    setState(() => lastOk = ok);
    if (ok) {
      correct++;
      play.ctx.sfx(Sfx.clear);
    } else {
      lives--;
      play.ctx.sfx(Sfx.error);
    }
    if (lives <= 0) {
      ended = true;
      later(900, () => play.lose(seconds: seconds, correct: correct, headline: '${bt(play.lang, 'step')}: $correct/${p.rounds.length}'));
      return;
    }
    later(ok ? 700 : 1400, () {
      if (round + 1 >= p.rounds.length) {
        ended = true;
        play.ctx.sfx(Sfx.win);
        final maxLen = p.rounds.map((e) => e.digits.length).reduce(math.max);
        play.win(score: 150 + correct * 60 + maxLen * 20 + lives * 40, stars: lives, seconds: seconds, correct: correct);
        return;
      }
      setState(() => round++);
      later(300, _show);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = play.lang;
    final want = digitAnswer(rd);
    return Column(children: [
      BrainBar(lang: lang, left: '${round + 1}/${p.rounds.length}', status: '${bt(lang, 'lives')}: ${'♥' * lives}'),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(showing ? bt(lang, 'watch') : bt(lang, rd.back ? 'backward' : 'forward'),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: rd.back ? BColors.bad : BColors.ink)),
        ),
      ),
      Expanded(
        flex: 4,
        child: Center(
          child: showing
              ? AnimatedSwitcher(
                  duration: const Duration(milliseconds: 120),
                  child: Text(shown >= 0 ? '${rd.digits[shown]}' : '', key: ValueKey(shown), style: const TextStyle(fontSize: 120, fontWeight: FontWeight.w900, color: BColors.accent)),
                )
              : Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
                  for (var i = 0; i < rd.digits.length; i++)
                    Container(
                      width: 40,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: lastOk == null ? BColors.soft : (lastOk! ? BColors.good.withValues(alpha: 0.25) : BColors.bad.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        i < typed.length ? '${typed[i]}' : (lastOk == false ? '${want[i]}' : ''),
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: i < typed.length ? BColors.ink : BColors.good),
                      ),
                    ),
                ]),
        ),
      ),
      Expanded(
        flex: 5,
        child: LayoutBuilder(builder: (context, box) {
          final s = math.min((box.maxWidth - 40) / 3, (box.maxHeight - 30) / 4) - 8;
          Widget key(int k, {Widget? child}) => Padding(
                padding: const EdgeInsets.all(4),
                child: SizedBox(
                  width: s,
                  height: s * 0.8,
                  child: FilledButton.tonal(
                    onPressed: showing ? null : () => _key(k),
                    style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: EdgeInsets.zero),
                    child: child ?? Text('$k', style: TextStyle(fontSize: s * 0.36, fontWeight: FontWeight.w800)),
                  ),
                ),
              );
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final row in const [[1, 2, 3], [4, 5, 6], [7, 8, 9]]) Row(mainAxisSize: MainAxisSize.min, children: [for (final k in row) key(k)]),
              Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: s + 8),
                key(0),
                key(-1, child: const Icon(Icons.backspace_outlined)),
              ]),
            ]),
          );
        }),
      ),
    ]);
  }
}

// ================================================================ Görsel arama

/// Arama nesnesi: şekil (0 daire, 1 kare, 2 üçgen, 3 T, 4 L), renk, açı (çeyrek tur).
class SearchItem {
  final int shape, color, rot;
  final double x, y;
  const SearchItem(this.shape, this.color, this.rot, this.x, this.y);
}

class SearchRound {
  final List<SearchItem> items;
  final int target;
  const SearchRound(this.items, this.target);
}

class SearchPuzzle extends BPuzzle {
  final List<SearchRound> rounds;
  final int limitMs;
  const SearchPuzzle(this.rounds, this.limitMs);
}

const kSearchColors = [Color(0xFFD64545), Color(0xFF3D7CC9), Color(0xFF3FA35B), Color(0xFFE3B21E), Color(0xFF8E5CB5)];

/// Hedefle aynı şekil ve renkte olan tek nesne hedefin kendisi olmalı.
bool searchUnique(SearchRound rd) {
  final t = rd.items[rd.target];
  return rd.items.where((o) => o.shape == t.shape && o.color == t.color).length == 1;
}

class VisualSearchKind extends BrainKind {
  @override
  String get id => 'gorsel-arama';
  const VisualSearchKind();

  @override
  BPuzzle? make(int d, SeededRandom r) {
    final rounds = <SearchRound>[];
    for (var k = 0; k < 8; k++) {
      final n = 8 + d * 3 + k;
      // Tür: 0 renk farkı (kolay), 1 şekil farkı, 2 şekil+renk birleşimi, 3 T'ler arasında L.
      final mode = d <= 2 ? (k.isEven ? 0 : 1) : (d <= 5 ? 1 + k % 2 : (k % 3 == 0 ? 2 : 3));
      final cols = math.max(4, math.sqrt(n * 0.75).ceil());
      final rows = (n / cols).ceil();
      final cells = List<int>.generate(cols * rows, (i) => i);
      r.shuffle(cells);
      final items = <SearchItem>[];
      SearchItem at(int shape, int color, int rot, int cell) {
        final cx = (cell % cols + 0.5 + (r.nextDouble() - 0.5) * 0.4) / cols;
        final cy = (cell ~/ cols + 0.5 + (r.nextDouble() - 0.5) * 0.4) / rows;
        return SearchItem(shape, color, rot, cx, cy);
      }

      final tc = r.nextInt(kSearchColors.length);
      final oc = (tc + 1 + r.nextInt(kSearchColors.length - 1)) % kSearchColors.length;
      late SearchItem target;
      switch (mode) {
        case 0:
          {
            final sh = r.nextInt(3);
            target = at(sh, tc, 0, cells[0]);
            for (var i = 1; i < n; i++) {
              items.add(at(sh, oc, 0, cells[i]));
            }
          }
        case 1:
          {
            final sh = r.nextInt(3);
            final other = (sh + 1 + r.nextInt(2)) % 3;
            target = at(sh, tc, 0, cells[0]);
            for (var i = 1; i < n; i++) {
              items.add(at(other, tc, 0, cells[i]));
            }
          }
        case 2:
          {
            final sh = r.nextInt(3);
            final other = (sh + 1 + r.nextInt(2)) % 3;
            target = at(sh, tc, 0, cells[0]);
            for (var i = 1; i < n; i++) {
              items.add(i.isEven ? at(sh, oc, 0, cells[i]) : at(other, tc, 0, cells[i]));
            }
          }
        default:
          {
            target = at(4, tc, r.nextInt(4), cells[0]);
            for (var i = 1; i < n; i++) {
              items.add(at(3, tc, r.nextInt(4), cells[i]));
            }
          }
      }
      final pos = r.nextInt(items.length + 1);
      items.insert(pos, target);
      rounds.add(SearchRound(items, pos));
    }
    return SearchPuzzle(rounds, 9000 - d * 450);
  }

  @override
  bool check(BPuzzle p) =>
      p is SearchPuzzle &&
      p.rounds.length == 8 &&
      p.rounds.every((rd) => rd.target >= 0 && rd.target < rd.items.length && rd.items.length >= 8 && searchUnique(rd) && rd.items.every((o) => o.x > 0 && o.x < 1 && o.y > 0 && o.y < 1));

  @override
  Widget build(BrainPlay play) => _SearchView(play: play);
}

void paintSearchItem(Canvas c, Offset o, double s, SearchItem it, {bool dim = false}) {
  final col = kSearchColors[it.color % kSearchColors.length].withValues(alpha: dim ? 0.35 : 1);
  final fill = Paint()..color = col;
  final line = Paint()
    ..color = col
    ..strokeWidth = s * 0.2
    ..strokeCap = StrokeCap.round;
  c.save();
  c.translate(o.dx, o.dy);
  c.rotate(it.rot * math.pi / 2);
  final h = s / 2;
  switch (it.shape) {
    case 0:
      c.drawCircle(Offset.zero, h * 0.9, fill);
    case 1:
      c.drawRect(Rect.fromCenter(center: Offset.zero, width: s * 0.8, height: s * 0.8), fill);
    case 2:
      c.drawPath(Path()..addPolygon([Offset(0, -h * 0.9), Offset(h * 0.9, h * 0.75), Offset(-h * 0.9, h * 0.75)], true), fill);
    case 3:
      c.drawLine(Offset(-h * 0.75, -h * 0.75), Offset(h * 0.75, -h * 0.75), line);
      c.drawLine(Offset(0, -h * 0.75), Offset(0, h * 0.8), line);
    default:
      // L: T ile aynı iki çubuk, yatay çubuk bir uçta.
      c.drawLine(Offset(-h * 0.6, -h * 0.8), Offset(-h * 0.6, h * 0.75), line);
      c.drawLine(Offset(-h * 0.6, h * 0.75), Offset(h * 0.75, h * 0.75), line);
  }
  c.restore();
}

class _SearchPainter extends CustomPainter {
  final SearchRound rd;
  final int? wrongAt;
  final bool found;
  _SearchPainter(this.rd, this.wrongAt, this.found);

  @override
  void paint(Canvas c, Size size) {
    final s = math.min(size.width, size.height) / math.sqrt(rd.items.length) * 0.5;
    for (var i = 0; i < rd.items.length; i++) {
      final it = rd.items[i];
      final o = Offset(it.x * size.width, it.y * size.height);
      if (found && i == rd.target) {
        c.drawCircle(o, s * 0.85, Paint()..color = BColors.good.withValues(alpha: 0.3));
      }
      if (i == wrongAt) {
        c.drawCircle(o, s * 0.85, Paint()..color = BColors.bad.withValues(alpha: 0.25));
      }
      paintSearchItem(c, o, s, it, dim: found && i != rd.target);
    }
  }

  @override
  bool shouldRepaint(covariant _SearchPainter o) => o.rd != rd || o.wrongAt != wrongAt || o.found != found;
}

class _SearchView extends StatefulWidget {
  final BrainPlay play;
  const _SearchView({required this.play});

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> with Ticker {
  late SearchPuzzle p;
  int round = 0, lives = 3, correct = 0, token = 0, ms = 0;
  int? wrongAt;
  bool found = false;
  final Stopwatch watch = Stopwatch();

  BrainPlay get play => widget.play;
  SearchRound get rd => p.rounds[round];

  @override
  void initState() {
    super.initState();
    p = play.puzzle as SearchPuzzle;
    startClock();
    _arm();
  }

  void _arm() {
    final t = ++token;
    watch
      ..reset()
      ..start();
    later(p.limitMs, () {
      if (t == token && !found && !ended) _miss();
    });
  }

  void _miss() {
    lives--;
    play.ctx.sfx(Sfx.error);
    setState(() => found = true);
    if (lives <= 0) {
      ended = true;
      later(900, () => play.lose(seconds: seconds, correct: correct, headline: '${bt(play.lang, 'step')}: $correct/${p.rounds.length}'));
      return;
    }
    later(900, _next);
  }

  void _next() {
    if (round + 1 >= p.rounds.length) {
      ended = true;
      play.ctx.sfx(Sfx.win);
      final avg = correct == 0 ? p.limitMs : ms ~/ correct;
      final speed = ((p.limitMs - avg) / p.limitMs).clamp(0.0, 1.0);
      play.win(score: 200 + correct * 50 + (speed * 300).round(), stars: lives, seconds: seconds, correct: correct);
      return;
    }
    setState(() {
      round++;
      found = false;
      wrongAt = null;
    });
    _arm();
  }

  void _tap(Offset pos, Size size) {
    if (found || ended) return;
    var best = -1;
    var bd = double.infinity;
    for (var i = 0; i < rd.items.length; i++) {
      final it = rd.items[i];
      final dd = (Offset(it.x * size.width, it.y * size.height) - pos).distance;
      if (dd < bd) {
        bd = dd;
        best = i;
      }
    }
    final reach = math.min(size.width, size.height) / math.sqrt(rd.items.length) * 0.6;
    if (best < 0 || bd > reach) return;
    if (best == rd.target) {
      watch.stop();
      ms += watch.elapsedMilliseconds;
      correct++;
      token++;
      play.ctx.sfx(Sfx.clear);
      setState(() => found = true);
      later(500, _next);
    } else {
      setState(() => wrongAt = best);
      play.ctx.sfx(Sfx.error);
      lives--;
      if (lives <= 0) {
        ended = true;
        token++;
        setState(() => found = true);
        later(900, () => play.lose(seconds: seconds, correct: correct, headline: '${bt(play.lang, 'step')}: $correct/${p.rounds.length}'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = play.lang;
    final t = rd.items[rd.target];
    return Column(children: [
      BrainBar(lang: lang, left: '${round + 1}/${p.rounds.length}', status: '${bt(lang, 'lives')}: ${'♥' * lives}'),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text('${bt(lang, 'find')}:', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)))),
          const SizedBox(width: 10),
          SizedBox(width: 40, height: 40, child: CustomPaint(painter: _OnePainter(SearchItem(t.shape, t.color, 0, 0.5, 0.5)))),
        ]),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: LayoutBuilder(builder: (context, box) {
            final size = Size(box.maxWidth, box.maxHeight);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (e) => _tap(e.localPosition, size),
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: CustomPaint(size: size, painter: _SearchPainter(rd, wrongAt, found)),
              ),
            );
          }),
        ),
      ),
    ]);
  }
}

class _OnePainter extends CustomPainter {
  final SearchItem it;
  _OnePainter(this.it);
  @override
  void paint(Canvas c, Size size) => paintSearchItem(c, Offset(size.width / 2, size.height / 2), size.shortestSide * 0.8, it);
  @override
  bool shouldRepaint(covariant _OnePainter o) => false;
}

// ================================================================ Kelime hafızası

class WordRound {
  /// Ezberlenecek kelimeler ([kMemoryWords] sırası).
  final List<int> study;

  /// Sorulan kelimeler (eski ve yeni karışık).
  final List<int> test;
  const WordRound(this.study, this.test);
}

class WordPuzzle extends BPuzzle {
  final List<WordRound> rounds;
  final int studyMs;

  /// true: hepsini seç ekranı; false: tek tek "listede var mıydı?".
  final bool grid;
  const WordPuzzle(this.rounds, this.studyMs, this.grid);
}

String memWord(int i, String lang) => Strings.pick(kMemoryWords[i % kMemoryWords.length], lang);

class WordMemoryKind extends BrainKind {
  @override
  String get id => 'kelime-hafizasi';
  const WordMemoryKind();

  @override
  BPuzzle? make(int d, SeededRandom r) {
    final k = 4 + d ~/ 2;
    final pool = List<int>.generate(kMemoryWords.length, (i) => i);
    r.shuffle(pool);
    final rounds = <WordRound>[];
    var at = 0;
    for (var n = 0; n < 3; n++) {
      if (at + 2 * k > pool.length) {
        r.shuffle(pool);
        at = 0;
      }
      final study = pool.sublist(at, at + k);
      final fresh = pool.sublist(at + k, at + 2 * k);
      at += 2 * k;
      final test = [...study, ...fresh];
      r.shuffle(test);
      rounds.add(WordRound(study, test));
    }
    return WordPuzzle(rounds, 1500 * k - d * 60 * k, d >= 6);
  }

  @override
  bool check(BPuzzle p) {
    if (p is! WordPuzzle || p.rounds.length != 3) return false;
    for (final rd in p.rounds) {
      final s = rd.study.toSet();
      if (s.length != rd.study.length || rd.test.toSet().length != rd.test.length) return false;
      if (!s.every(rd.test.contains) || rd.test.length != 2 * rd.study.length) return false;
      if (rd.test.any((i) => i < 0 || i >= kMemoryWords.length)) return false;
    }
    return true;
  }

  @override
  Widget build(BrainPlay play) => _WordView(play: play);
}

enum _WPhase { study, test }

class _WordView extends StatefulWidget {
  final BrainPlay play;
  const _WordView({required this.play});

  @override
  State<_WordView> createState() => _WordViewState();
}

class _WordViewState extends State<_WordView> with Ticker {
  late WordPuzzle p;
  _WPhase phase = _WPhase.study;
  int round = 0, q = 0, lives = 3, correct = 0, asked = 0, token = 0;
  bool? lastOk;
  final Set<int> picked = {};
  bool checked = false;

  BrainPlay get play => widget.play;
  WordRound get rd => p.rounds[round];

  @override
  void initState() {
    super.initState();
    p = play.puzzle as WordPuzzle;
    startClock();
    _study();
  }

  void _study() {
    final t = ++token;
    setState(() {
      phase = _WPhase.study;
      q = 0;
      lastOk = null;
      picked.clear();
      checked = false;
    });
    later(p.studyMs, () {
      if (t == token) _test();
    });
  }

  void _test() {
    token++;
    setState(() => phase = _WPhase.test);
  }

  void _score(bool ok) {
    asked++;
    if (ok) {
      correct++;
      play.ctx.sfx(Sfx.place);
    } else {
      lives--;
      play.ctx.sfx(Sfx.error);
    }
  }

  bool _over() {
    if (lives > 0) return false;
    ended = true;
    later(900, () => play.lose(seconds: seconds, correct: correct, headline: '${bt(play.lang, 'accuracy')}: ${asked == 0 ? 0 : (correct * 100 / asked).round()}%'));
    return true;
  }

  void _nextRound() {
    if (round + 1 < p.rounds.length) {
      play.ctx.sfx(Sfx.clear);
      round++;
      _study();
      return;
    }
    ended = true;
    play.ctx.sfx(Sfx.win);
    final acc = asked == 0 ? 0.0 : correct / asked;
    play.win(score: (acc * 600).round() + lives * 80, stars: starsBy(acc), seconds: seconds, correct: correct);
  }

  void _answer(bool seen) {
    if (phase != _WPhase.test || lastOk != null || ended) return;
    final ok = rd.study.contains(rd.test[q]) == seen;
    _score(ok);
    setState(() => lastOk = ok);
    if (_over()) return;
    later(ok ? 350 : 800, () {
      if (q + 1 < rd.test.length) {
        setState(() {
          q++;
          lastOk = null;
        });
        return;
      }
      _nextRound();
    });
  }

  void _checkGrid() {
    if (checked || ended) return;
    setState(() => checked = true);
    for (final w in rd.test) {
      final want = rd.study.contains(w);
      if (want || picked.contains(w)) _score(want == picked.contains(w));
      if (lives <= 0) break;
    }
    if (_over()) return;
    later(1600, _nextRound);
  }

  Widget _chip(String s, {Color? color, VoidCallback? onTap, bool sel = false}) => Material(
        color: color ?? (sel ? BColors.accent.withValues(alpha: 0.2) : Colors.white),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 96, minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: sel ? BColors.accent : BColors.soft, width: 2)),
            child: Text(s, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ),
        ),
      );

  Widget _studyView(String lang) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: FittedBox(fit: BoxFit.scaleDown, child: Text(bt(lang, 'memorize'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [for (final w in rd.study) _chip(memWord(w, lang))]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: FilledButton.icon(onPressed: _test, icon: const Icon(Icons.check), label: Text(bt(lang, 'ready'))),
        ),
      ]);

  Widget _oneView(String lang) {
    final w = rd.test[q];
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: FittedBox(fit: BoxFit.scaleDown, child: Text(bt(lang, 'wasIn'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
      ),
      Text('${q + 1}/${rd.test.length}', style: const TextStyle(color: Colors.black54)),
      Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(memWord(w, lang),
                  style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: lastOk == null ? BColors.ink : (lastOk! ? BColors.good : BColors.bad))),
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Row(children: [
          Expanded(
            child: SizedBox(
              height: 64,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: BColors.good),
                onPressed: () => _answer(true),
                child: FittedBox(fit: BoxFit.scaleDown, child: Text(bt(lang, 'yes'), style: const TextStyle(fontSize: 22))),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SizedBox(
              height: 64,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: BColors.bad),
                onPressed: () => _answer(false),
                child: FittedBox(fit: BoxFit.scaleDown, child: Text(bt(lang, 'no'), style: const TextStyle(fontSize: 22))),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _gridView(String lang) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: FittedBox(fit: BoxFit.scaleDown, child: Text(bt(lang, 'pickSeen'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
              for (final w in rd.test)
                _chip(
                  memWord(w, lang),
                  sel: picked.contains(w),
                  color: !checked
                      ? null
                      : (rd.study.contains(w)
                          ? (picked.contains(w) ? BColors.good.withValues(alpha: 0.35) : BColors.accent.withValues(alpha: 0.15))
                          : (picked.contains(w) ? BColors.bad.withValues(alpha: 0.3) : null)),
                  onTap: checked
                      ? null
                      : () => setState(() {
                            if (!picked.remove(w)) picked.add(w);
                            play.ctx.sfx(Sfx.tap);
                          }),
                ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: FilledButton.icon(onPressed: checked ? null : _checkGrid, icon: const Icon(Icons.done_all), label: Text(bt(lang, 'done'))),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    final lang = play.lang;
    final Widget body = phase == _WPhase.study ? _studyView(lang) : (p.grid ? _gridView(lang) : _oneView(lang));
    return Column(children: [
      BrainBar(lang: lang, left: '${round + 1}/${p.rounds.length}', status: '${bt(lang, 'lives')}: ${'♥' * lives}'),
      Expanded(child: body),
    ]);
  }
}
