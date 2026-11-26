import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/rng.dart';

import '../core.dart';
import '../studio_chrome.dart';
import '../texts.dart';

// ================================================================ Kestirme Ustası

/// Tahmin görevi: 0 miktar (nokta sayısı), 1 açı (derece), 2 uzunluk (kat),
/// 3 süre (saniye; oyuncu süreyi içinden sayıp durdurur).
class EstTask {
  final int type;
  final double value;
  final int seed;
  const EstTask(this.type, this.value, this.seed);
}

class EstimatePuzzle extends BPuzzle {
  final List<EstTask> tasks;

  /// Geçmek için gereken ortalama isabet (0..1).
  final double pass;

  /// Noktaların ekranda kalma süresi (ms).
  final int showMs;
  const EstimatePuzzle(this.tasks, this.pass, this.showMs);
}

/// Sürgü aralıkları (zorluktan bağımsız: aralık yanıtı ele vermesin).
const double kEstCountMax = 200;
const double kEstLenMin = 1, kEstLenMax = 8;

/// Bir tahminin isabeti (0..1).
double estAccuracy(EstTask t, double guess) {
  if (t.type == 1) return (1 - (guess - t.value).abs() / 45).clamp(0.0, 1.0);
  final rel = (guess - t.value).abs() / t.value;
  return (1 - rel * 2).clamp(0.0, 1.0);
}

class EstimateKind extends BrainKind {
  @override
  String get id => 'kestirme';
  const EstimateKind();

  @override
  BPuzzle? make(int d, SeededRandom r) {
    final n = 6 + d ~/ 3;
    final types = [0, 1, 2, 3];
    while (types.length < n) {
      types.add(r.nextInt(4));
    }
    r.shuffle(types);
    final tasks = <EstTask>[];
    for (final ty in types) {
      double v;
      switch (ty) {
        case 0:
          v = r.range(8, 25 + d * 14).toDouble();
        case 1:
          v = r.range(10, 170).toDouble();
        case 2:
          v = (r.range(12, 30 + d * 4)) / 10.0;
        default:
          v = r.range(4, 8 + d) / 2.0;
      }
      tasks.add(EstTask(ty, v, r.nextUint32()));
    }
    return EstimatePuzzle(tasks, math.min(0.7, 0.5 + d * 0.02), 1700 - d * 90);
  }

  @override
  bool check(BPuzzle p) {
    if (p is! EstimatePuzzle) return false;
    if (p.tasks.length < 6 || p.tasks.length > 10) return false;
    for (var ty = 0; ty < 4; ty++) {
      if (!p.tasks.any((t) => t.type == ty)) return false;
    }
    for (final t in p.tasks) {
      final ok = switch (t.type) {
        0 => t.value >= 8 && t.value <= kEstCountMax * 0.9 && t.value == t.value.roundToDouble(),
        1 => t.value >= 10 && t.value <= 170,
        2 => t.value >= 1.2 && t.value <= kEstLenMax * 0.9,
        3 => t.value >= 2 && t.value <= 9,
        _ => false,
      };
      if (!ok) return false;
    }
    return p.pass > 0.3 && p.pass < 0.9 && p.showMs >= 600;
  }

  @override
  Widget build(BrainPlay play) => _EstimateView(play: play);
}

class _EstimateView extends StatefulWidget {
  final BrainPlay play;
  const _EstimateView({required this.play});

  @override
  State<_EstimateView> createState() => _EstimateViewState();
}

class _EstimateViewState extends State<_EstimateView> with Ticker {
  late EstimatePuzzle p;
  int idx = 0;

  /// 0 gösterim, 1 yanıt, 2 geri bildirim.
  int phase = 0;
  bool timing = false;
  double guess = 0;
  double lastAcc = 0;
  double lastGuess = 0;
  final List<double> accs = [];
  final Stopwatch sw = Stopwatch();

  BrainPlay get play => widget.play;
  EstTask get task => p.tasks[idx];

  @override
  void initState() {
    super.initState();
    p = play.puzzle as EstimatePuzzle;
    startClock();
    _begin();
  }

  void _begin() {
    final t = task;
    phase = t.type == 0 ? 0 : 1;
    timing = false;
    guess = switch (t.type) { 0 => kEstCountMax / 4, 1 => 90.0, 2 => 3.0, _ => 0.0 };
    if (t.type == 0) {
      final my = idx;
      later(p.showMs, () {
        if (my == idx && phase == 0) setState(() => phase = 1);
      });
    }
  }

  void _answer(double g) {
    if (phase != 1) return;
    final a = estAccuracy(task, g);
    play.ctx.sfx(a >= 0.75 ? Sfx.place : (a >= 0.4 ? Sfx.tap : Sfx.error));
    setState(() {
      lastAcc = a;
      lastGuess = g;
      accs.add(a);
      phase = 2;
    });
  }

  void _timer() {
    if (phase != 1) return;
    if (!timing) {
      sw
        ..reset()
        ..start();
      setState(() => timing = true);
      return;
    }
    sw.stop();
    _answer(sw.elapsedMilliseconds / 1000.0);
  }

  void _next() {
    if (phase != 2) return;
    if (idx + 1 >= p.tasks.length) return _finish();
    setState(() {
      idx++;
      _begin();
    });
  }

  void _finish() {
    if (ended) return;
    ended = true;
    final mean = accs.isEmpty ? 0.0 : accs.reduce((a, b) => a + b) / accs.length;
    final good = accs.where((a) => a >= 0.75).length;
    if (mean >= p.pass) {
      play.ctx.sfx(Sfx.win);
      final stars = mean >= 0.85 ? 3 : (mean >= 0.72 ? 2 : 1);
      play.win(score: (mean * 1000).round(), stars: stars, seconds: seconds, correct: good);
    } else {
      play.ctx.sfx(Sfx.lose);
      play.lose(seconds: seconds, correct: good, headline: '${bt(play.lang, 'accuracy')}: ${(mean * 100).round()}%');
    }
  }

  String _fmt(EstTask t, double v) => switch (t.type) {
        0 => '${v.round()}',
        1 => '${v.round()}°',
        2 => '×${v.toStringAsFixed(1)}',
        _ => '${v.toStringAsFixed(1)} s',
      };

  String get _prompt {
    final lang = play.lang;
    return switch (task.type) {
      0 => bt(lang, 'estCount'),
      1 => bt(lang, 'estAngle'),
      2 => bt(lang, 'estLength'),
      _ => bt(lang, 'estTime').replaceAll('{n}', task.value.toStringAsFixed(1)),
    };
  }

  Widget _figure() {
    final t = task;
    if (t.type == 3) {
      return Center(
        child: SizedBox(
          width: 180,
          height: 180,
          child: CustomPaint(painter: _PulsePainter(running: timing, hide: play.d >= 6, ms: timing ? sw.elapsedMilliseconds : 0)),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: BColors.paper, borderRadius: BorderRadius.circular(18)),
        child: CustomPaint(painter: _EstPainter(t, phase == 0 || t.type != 0, play.d)),
      ),
    );
  }

  Widget _input() {
    final lang = play.lang;
    final t = task;
    if (phase == 2) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${bt(lang, 'actual')}: ${_fmt(t, t.value)}   ·   ${bt(lang, 'you')}: ${_fmt(t, lastGuess)}',
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 6),
        StudioBar(value: lastAcc, color: lastAcc >= 0.75 ? BColors.good : (lastAcc >= 0.4 ? StudioLook.gold : BColors.bad)),
        const SizedBox(height: 10),
        StudioButton(label: bt(lang, 'next'), icon: Icons.arrow_forward_rounded, onPressed: _next),
      ]);
    }
    if (t.type == 3) {
      return StudioButton(
        label: timing ? bt(lang, 'stop') : bt(lang, 'go'),
        icon: timing ? Icons.stop_rounded : Icons.play_arrow_rounded,
        onPressed: _timer,
      );
    }
    if (phase == 0) return const SizedBox(height: 96);
    final (lo, hi, div) = switch (t.type) {
      0 => (0.0, kEstCountMax, 200),
      1 => (0.0, 180.0, 180),
      _ => (kEstLenMin, kEstLenMax, 70),
    };
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(_fmt(t, guess), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: StudioLook.of(context).number)),
      Slider(value: guess.clamp(lo, hi), min: lo, max: hi, divisions: div, onChanged: (v) => setState(() => guess = v)),
      StudioButton(label: bt(lang, 'ok'), icon: Icons.check_rounded, onPressed: () => _answer(guess)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (timing && phase == 1) {
      // Saati döndürmek için kare kare yenile (yalnızca görsel nabız).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && timing && phase == 1) setState(() {});
      });
    }
    return Column(children: [
      BrainBar(lang: play.lang, left: '${idx + 1}/${p.tasks.length}', status: clock()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text(_prompt, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
      ),
      Expanded(child: Center(child: _figure())),
      Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), child: _input()),
    ]);
  }
}

class _EstPainter extends CustomPainter {
  final EstTask t;
  final bool visible;
  final int d;
  _EstPainter(this.t, this.visible, this.d);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.scale(s / 100);
    if (!visible) {
      final tp = TextPainter(
        text: const TextSpan(text: '?', style: TextStyle(fontSize: 40, color: BColors.ink, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(50 - tp.width / 2, 50 - tp.height / 2));
      canvas.restore();
      return;
    }
    final r = SeededRandom(t.seed);
    switch (t.type) {
      case 0:
        final n = t.value.round();
        final pts = <Offset>[];
        final minD = n > 120 ? 4.2 : (n > 60 ? 5.5 : 7.5);
        for (var g = 0; g < n * 200 && pts.length < n; g++) {
          final o = Offset(6 + r.nextDouble() * 88, 6 + r.nextDouble() * 88);
          if (pts.every((q) => (q - o).distance >= minD)) pts.add(o);
        }
        // Yer kalmadıysa kalanlar yine de çizilir (sayı her zaman doğru kalsın).
        while (pts.length < n) {
          pts.add(Offset(6 + r.nextDouble() * 88, 6 + r.nextDouble() * 88));
        }
        final rad = n > 120 ? 1.6 : (n > 60 ? 2.1 : 2.8);
        for (final o in pts) {
          canvas.drawCircle(o, rad, Paint()..color = BColors.pads[r.nextInt(d >= 5 ? 6 : 1) % 6]);
        }
      case 1:
        final base = d >= 4 ? r.nextDouble() * math.pi * 2 : 0.0;
        final a = t.value * math.pi / 180;
        const c = Offset(50, 50);
        final p1 = c + Offset(math.cos(base), -math.sin(base)) * 40;
        final p2 = c + Offset(math.cos(base + a), -math.sin(base + a)) * 40;
        final ink = Paint()
          ..color = BColors.ink
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(c, p1, ink);
        canvas.drawLine(c, p2, ink);
        canvas.drawArc(Rect.fromCircle(center: c, radius: 12), -base - a, a, false,
            Paint()
              ..color = BColors.accent
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
        canvas.drawCircle(c, 2.4, Paint()..color = BColors.bad);
      case 2:
        // Kısa (birim) çubuk ve uzun çubuk; ileri zorlukta uzun çubuk eğik.
        const unit = 10.0;
        final long = unit * t.value;
        final ux = 10 + r.nextDouble() * 30;
        canvas.drawLine(Offset(ux, 14), Offset(ux + unit, 14),
            Paint()
              ..color = BColors.bad
              ..strokeWidth = 4
              ..strokeCap = StrokeCap.butt);
        final ang = d >= 5 ? (r.nextDouble() - 0.5) * 1.2 : 0.0;
        final len = math.min(long, 80.0);
        final scale = len / long;
        final start = Offset(50 - math.cos(ang) * len / 2, 60 - math.sin(ang) * len / 2);
        final end = Offset(50 + math.cos(ang) * len / 2, 60 + math.sin(ang) * len / 2);
        canvas.drawLine(start, end,
            Paint()
              ..color = BColors.accent
              ..strokeWidth = 4
              ..strokeCap = StrokeCap.butt);
        if (scale < 1) {
          // Çok uzun çubuklarda birim çubuk aynı oranda küçülür.
          canvas.drawLine(Offset(ux, 22), Offset(ux + unit * scale, 22),
              Paint()
                ..color = BColors.bad.withValues(alpha: 0.6)
                ..strokeWidth = 2);
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EstPainter old) => old.t != t || old.visible != visible;
}

class _PulsePainter extends CustomPainter {
  final bool running;
  final bool hide;
  final int ms;
  _PulsePainter({required this.running, required this.hide, required this.ms});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 6;
    canvas.drawCircle(c, r, Paint()..color = Colors.white.withValues(alpha: 0.08));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = running ? BColors.good : BColors.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6);
    if (running && !hide) {
      // Saniye göstermeyen, düzensiz dönen bir işaret: sayma ipucu vermez.
      final a = ms / 1000.0 * 2.7 + math.sin(ms / 370.0);
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * (r - 14), 9, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _PulsePainter old) => true;
}

// ================================================================ İz Sürme

/// Bir iz: düğümlerin konumları (0..100 × 0..140) ve türü (B: sayı-harf dönüşümlü).
class TrailPart {
  final bool alt;
  final List<double> xs, ys;
  const TrailPart(this.alt, this.xs, this.ys);
  int get n => xs.length;
}

class TrailPuzzle extends BPuzzle {
  final List<TrailPart> parts;
  const TrailPuzzle(this.parts);
}

const double kTrailW = 100, kTrailH = 140, kTrailR = 5.6, kTrailGap = 13.5;

TrailPart? _trailPart(bool alt, int n, SeededRandom r) {
  final xs = <double>[], ys = <double>[];
  for (var g = 0; g < 4000 && xs.length < n; g++) {
    final x = 8 + r.nextDouble() * (kTrailW - 16);
    final y = 8 + r.nextDouble() * (kTrailH - 16);
    var ok = true;
    for (var i = 0; i < xs.length; i++) {
      final dx = xs[i] - x, dy = ys[i] - y;
      if (dx * dx + dy * dy < kTrailGap * kTrailGap) {
        ok = false;
        break;
      }
    }
    if (ok) {
      xs.add(x);
      ys.add(y);
    }
  }
  return xs.length == n ? TrailPart(alt, xs, ys) : null;
}

class TrailKind extends BrainKind {
  @override
  String get id => 'iz-surme';
  const TrailKind();

  @override
  BPuzzle? make(int d, SeededRandom r) {
    final na = math.min(8 + d, 18);
    final nb = math.min(7 + d, 20);
    final a = _trailPart(false, na, r);
    final b = _trailPart(d >= 3, d >= 3 ? nb : na, r);
    if (a == null || b == null) return null;
    return TrailPuzzle([a, b]);
  }

  @override
  bool check(BPuzzle p) {
    if (p is! TrailPuzzle || p.parts.length != 2) return false;
    for (final t in p.parts) {
      if (t.n < 8 || t.n > 20 || t.xs.length != t.ys.length) return false;
      if (t.alt && (t.n + 1) ~/ 2 > 10) return false;
      for (var i = 0; i < t.n; i++) {
        if (t.xs[i] < kTrailR || t.xs[i] > kTrailW - kTrailR || t.ys[i] < kTrailR || t.ys[i] > kTrailH - kTrailR) return false;
        for (var j = i + 1; j < t.n; j++) {
          final dx = t.xs[i] - t.xs[j], dy = t.ys[i] - t.ys[j];
          if (dx * dx + dy * dy < kTrailGap * kTrailGap - 1e-6) return false;
        }
      }
    }
    return true;
  }

  @override
  Widget build(BrainPlay play) => _TrailView(play: play);
}

String trailLabel(TrailPart t, int i, List<String> letters) {
  if (!t.alt) return '${i + 1}';
  return i.isEven ? '${i ~/ 2 + 1}' : letters[(i ~/ 2) % letters.length];
}

class _TrailView extends StatefulWidget {
  final BrainPlay play;
  const _TrailView({required this.play});

  @override
  State<_TrailView> createState() => _TrailViewState();
}

class _TrailViewState extends State<_TrailView> with Ticker {
  late TrailPuzzle p;
  int part = 0, done = 0, errors = 0, hints = 0, wrong = -1;
  bool showHint = false;
  final List<int> partSeconds = [];
  int partStart = 0;

  BrainPlay get play => widget.play;
  TrailPart get t => p.parts[part];
  int get maxErrors => 6;

  @override
  void initState() {
    super.initState();
    p = play.puzzle as TrailPuzzle;
    startClock();
  }

  void _tap(Offset lp) {
    if (ended) return;
    var best = -1;
    var bd = 1e9;
    for (var i = 0; i < t.n; i++) {
      final dx = t.xs[i] - lp.dx, dy = t.ys[i] - lp.dy;
      final dd = dx * dx + dy * dy;
      if (dd < bd) {
        bd = dd;
        best = i;
      }
    }
    if (best < 0 || bd > (kTrailR * 1.9) * (kTrailR * 1.9)) return;
    if (best < done) return; // zaten bağlı
    if (best == done) {
      play.ctx.sfx(Sfx.place);
      setState(() {
        done++;
        wrong = -1;
        showHint = false;
      });
      if (done >= t.n) _partDone();
    } else {
      play.ctx.sfx(Sfx.error);
      setState(() {
        errors++;
        wrong = best;
      });
      if (errors > maxErrors) {
        ended = true;
        play.ctx.sfx(Sfx.lose);
        play.lose(seconds: seconds, correct: done, headline: '${bt(play.lang, 'errors')}: $errors');
      }
    }
  }

  void _partDone() {
    partSeconds.add(seconds - partStart);
    if (part + 1 < p.parts.length) {
      play.ctx.sfx(Sfx.clear);
      setState(() {
        part++;
        done = 0;
        wrong = -1;
        partStart = seconds;
      });
      return;
    }
    ended = true;
    play.ctx.sfx(Sfx.win);
    final nodes = p.parts.fold<int>(0, (a, b) => a + b.n);
    final par = p.parts.fold<double>(0, (a, b) => a + b.n * (b.alt ? 1.9 : 1.3));
    var stars = seconds <= par ? 3 : (seconds <= par * 1.6 ? 2 : 1);
    if (errors > 2) stars--;
    stars -= hints;
    play.win(score: math.max(0, 2000 - seconds * 20 - errors * 60), stars: stars < 1 ? 1 : stars, seconds: seconds, correct: nodes, hints: hints);
  }

  @override
  Widget build(BuildContext context) {
    final lang = play.lang;
    final letters = trailLetters(lang);
    final help = t.alt
        ? bt(lang, 'trailB').replaceAll('{s}', '1-${letters[0]}-2-${letters[1]}-3')
        : bt(lang, 'trailA');
    return Column(children: [
      BrainBar(
        lang: lang,
        left: '${part + 1}/${p.parts.length}',
        status: '${clock()} · ${bt(lang, 'errors')}: $errors',
        onHint: ended || showHint
            ? null
            : () async {
                if (await play.ctx.requestHint()) {
                  setState(() {
                    hints++;
                    showHint = true;
                  });
                }
              },
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
        child: Text(help, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
      ),
      Expanded(
        child: LayoutBuilder(builder: (context, box) {
          final k = math.min(box.maxWidth / kTrailW, box.maxHeight / kTrailH) * 0.97;
          return Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (e) => _tap(e.localPosition / k),
              onPanUpdate: (e) => _tap(e.localPosition / k),
              child: Container(
                width: kTrailW * k,
                height: kTrailH * k,
                decoration: BoxDecoration(color: BColors.paper, borderRadius: BorderRadius.circular(16)),
                child: CustomPaint(painter: _TrailPainter(t, done, wrong, showHint, letters, k)),
              ),
            ),
          );
        }),
      ),
      const SizedBox(height: 8),
    ]);
  }
}

class _TrailPainter extends CustomPainter {
  final TrailPart t;
  final int done, wrong;
  final bool hint;
  final List<String> letters;
  final double k;
  _TrailPainter(this.t, this.done, this.wrong, this.hint, this.letters, this.k);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(k);
    final line = Paint()
      ..color = BColors.accent
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < done; i++) {
      canvas.drawLine(Offset(t.xs[i - 1], t.ys[i - 1]), Offset(t.xs[i], t.ys[i]), line);
    }
    for (var i = 0; i < t.n; i++) {
      final o = Offset(t.xs[i], t.ys[i]);
      final isLetter = t.alt && i.isOdd;
      final fillC = i < done
          ? BColors.good
          : (i == wrong ? BColors.bad : (hint && i == done ? StudioLook.gold : (isLetter ? const Color(0xFFFFF4E0) : Colors.white)));
      canvas.drawCircle(o, kTrailR, Paint()..color = fillC);
      canvas.drawCircle(
          o,
          kTrailR,
          Paint()
            ..color = BColors.ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.7);
      final tp = TextPainter(
        text: TextSpan(
            text: trailLabel(t, i, letters),
            style: TextStyle(fontSize: 5.4, fontWeight: FontWeight.w900, color: i < done || i == wrong ? Colors.white : BColors.ink)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TrailPainter old) => true;
}

// ================================================================ Ok Yönü

/// Deneme bitleri: 1 yön (sağ), 2 uyumlu (yan oklar aynı yön), 4 dur (kırmızı),
/// 8 yansız (yanlarda çizgi).
class FlankPuzzle extends BPuzzle {
  final List<int> trials;
  final List<int> gaps;
  final int window;
  const FlankPuzzle(this.trials, this.gaps, this.window);
}

class FlankerKind extends BrainKind {
  @override
  String get id => 'ok-yonu';
  const FlankerKind();

  @override
  BPuzzle? make(int d, SeededRandom r) {
    final n = 22 + d * 2;
    final nogoP = d <= 2 ? 0.0 : 0.18 + d * 0.01;
    final trials = <int>[];
    for (var i = 0; i < n; i++) {
      var b = r.chance(0.5) ? 1 : 0;
      if (r.chance(0.5)) b |= 2;
      if (d <= 3 && r.chance(0.25)) b |= 8;
      if (i > 1 && r.chance(nogoP)) b |= 4;
      trials.add(b);
    }
    return FlankPuzzle(trials, [for (var i = 0; i < n; i++) r.range(450, 1100)], 1300 - d * 60);
  }

  @override
  bool check(BPuzzle p) {
    if (p is! FlankPuzzle) return false;
    final go = p.trials.where((b) => b & 4 == 0).toList();
    return p.trials.length >= 20 &&
        p.trials.length == p.gaps.length &&
        go.length >= p.trials.length * 0.6 &&
        go.any((b) => b & 2 == 0 && b & 8 == 0) &&
        go.any((b) => b & 2 != 0) &&
        p.window >= 600;
  }

  @override
  Widget build(BrainPlay play) => _FlankView(play: play);
}

class _FlankView extends StatefulWidget {
  final BrainPlay play;
  const _FlankView({required this.play});

  @override
  State<_FlankView> createState() => _FlankViewState();
}

class _FlankViewState extends State<_FlankView> with Ticker {
  late FlankPuzzle p;
  int idx = -1, good = 0, token = 0;
  bool started = false, showing = false, responded = false;
  String fb = '';
  final Stopwatch sw = Stopwatch();
  final List<int> rtSame = [], rtMixed = [];

  BrainPlay get play => widget.play;

  @override
  void initState() {
    super.initState();
    p = play.puzzle as FlankPuzzle;
  }

  void _start() {
    setState(() => started = true);
    startClock();
    _next();
  }

  void _next() {
    if (idx + 1 >= p.trials.length) return _finish();
    setState(() {
      idx++;
      showing = false;
      responded = false;
    });
    final my = ++token;
    later(p.gaps[idx], () {
      if (my != token) return;
      setState(() => showing = true);
      sw
        ..reset()
        ..start();
      later(p.window, () {
        if (my != token) return;
        if (!responded) {
          final nogo = p.trials[idx] & 4 != 0;
          if (nogo) good++;
          setState(() => fb = nogo ? '✓' : '…');
        }
        _next();
      });
    });
  }

  void _press(int side) {
    if (!started) return _start();
    if (ended || responded) return;
    if (!showing) {
      play.ctx.sfx(Sfx.error);
      setState(() => fb = '✗');
      return;
    }
    responded = true;
    final b = p.trials[idx];
    final ok = b & 4 == 0 && (b & 1) == side;
    if (ok) {
      good++;
      final ms = sw.elapsedMilliseconds;
      if (b & 8 == 0) (b & 2 != 0 ? rtSame : rtMixed).add(ms);
    }
    play.ctx.sfx(ok ? Sfx.place : Sfx.error);
    setState(() => fb = ok ? '${sw.elapsedMilliseconds} ms' : '✗');
  }

  int _avg(List<int> l) => l.isEmpty ? 0 : l.reduce((a, b) => a + b) ~/ l.length;

  void _finish() {
    if (ended) return;
    ended = true;
    final acc = good / p.trials.length;
    final cost = rtSame.isEmpty || rtMixed.isEmpty ? 0 : _avg(rtMixed) - _avg(rtSame);
    if (acc >= 0.8) {
      play.ctx.sfx(Sfx.win);
      play.win(
          score: (acc * 500).round() + math.max(0, 700 - _avg([...rtSame, ...rtMixed])),
          stars: starsBy(acc),
          seconds: seconds,
          correct: good);
    } else {
      play.ctx.sfx(Sfx.lose);
      play.lose(
          seconds: seconds,
          correct: good,
          headline: '${bt(play.lang, 'accuracy')}: ${(acc * 100).round()}% · ${bt(play.lang, 'conflict')}: ${math.max(0, cost)} ms');
    }
  }

  Widget _side(int side) => Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _press(side),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: StudioLook.of(context).accent.withValues(alpha: 0.5), width: 1.4),
            ),
            child: Center(child: SizedBox(width: 64, height: 40, child: CustomPaint(painter: _ArrowsPainter([side], Colors.white)))),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final lang = play.lang;
    final b = idx >= 0 ? p.trials[idx] : 0;
    final dir = b & 1;
    final flank = b & 2 != 0 ? dir : 1 - dir;
    final List<int> row = b & 8 != 0 ? [-1, -1, dir, -1, -1] : [flank, flank, dir, flank, flank];
    final color = b & 4 != 0 ? const Color(0xFFE5534B) : Colors.white;
    final help = play.d <= 2 ? bt(lang, 'flank') : '${bt(lang, 'flank')}\n${bt(lang, 'nogo')}';
    return Column(children: [
      BrainBar(lang: lang, left: started ? '${idx + 1}/${p.trials.length}' : '', status: fb),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text(help, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kStudioSubtle)),
      ),
      Expanded(
        flex: 3,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: started ? null : _start,
          child: Center(
            child: !started
                ? StudioButton(label: bt(lang, 'go'), icon: Icons.play_arrow_rounded, onPressed: _start)
                : (showing
                    ? SizedBox(width: 300, height: 64, child: CustomPaint(painter: _ArrowsPainter(row, color)))
                    : const Text('+', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w300, color: Colors.white))),
          ),
        ),
      ),
      // Sol ve sağ her dilde yerinde kalsın (sağdan sola dillerde de).
      Expanded(
        flex: 2,
        child: Directionality(textDirection: TextDirection.ltr, child: Row(children: [_side(0), _side(1)])),
      ),
    ]);
  }
}

/// Yan yana oklar: 0 sol, 1 sağ, -1 yansız çizgi.
class _ArrowsPainter extends CustomPainter {
  final List<int> dirs;
  final Color color;
  _ArrowsPainter(this.dirs, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / dirs.length;
    final h = size.height;
    final pt = Paint()
      ..color = color
      ..strokeWidth = math.max(3.0, h * 0.12)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < dirs.length; i++) {
      final cx = w * (i + 0.5);
      final cy = h / 2;
      final half = w * 0.36;
      canvas.drawLine(Offset(cx - half, cy), Offset(cx + half, cy), pt);
      if (dirs[i] < 0) continue;
      final tip = dirs[i] == 1 ? cx + half : cx - half;
      final back = dirs[i] == 1 ? -1.0 : 1.0;
      final hw = math.min(half * 0.7, h * 0.32);
      canvas.drawPath(
          Path()
            ..moveTo(tip + back * hw, cy - hw)
            ..lineTo(tip, cy)
            ..lineTo(tip + back * hw, cy + hw),
          pt);
    }
  }

  @override
  bool shouldRepaint(covariant _ArrowsPainter old) => old.dirs.join() != dirs.join() || old.color != color;
}
