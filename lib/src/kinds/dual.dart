import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/rng.dart';

import '../core.dart';
import '../studio_chrome.dart';
import '../texts.dart';

// ---------------------------------------------------------------- Çift Görev

/// Hızlı karşılaştırma sorusu. op: 0 a>b, 1 a<b, 2 a+b>c, 3 a×b>c, 4 a−b<c.
class DQ {
  final int a, b, c, op;
  const DQ(this.a, this.b, this.c, this.op);

  bool get answer => switch (op) {
        0 => a > b,
        1 => a < b,
        2 => a + b > c,
        3 => a * b > c,
        _ => a - b < c,
      };

  /// Eşitlik olmadan net bir karşılaştırma mı?
  bool get clean => switch (op) {
        0 || 1 => a != b,
        2 => a + b != c,
        3 => a * b != c,
        _ => a - b != c,
      };

  String get text => switch (op) {
        0 => '$a > $b',
        1 => '$a < $b',
        2 => '$a + $b > $c',
        3 => '$a × $b > $c',
        _ => '$a − $b < $c',
      };
}

class DualPuzzle extends BPuzzle {
  final List<DQ> qs;

  /// Rüzgâr dizisi (-1..1), her biri 1,5 saniye sürer.
  final List<double> gusts;
  final double strength;
  final double zone;

  /// Soru süresi (ms), cevaplara göre uyarlanır.
  final int window;
  const DualPuzzle(this.qs, this.gusts, this.strength, this.zone, this.window);
}

class DualTaskKind extends BrainKind {
  @override
  String get id => 'cift-gorev';
  const DualTaskKind();

  static const int count = 20;

  DQ _q(int d, SeededRandom r) {
    final want = r.chance(0.5);
    if (d <= 3) {
      final a = r.range(1, 20);
      var b = r.range(1, 19);
      if (b >= a) b++;
      final op = r.nextInt(2);
      final q = DQ(a, b, 0, op);
      return q.answer == want ? q : DQ(b, a, 0, op);
    }
    final delta = r.range(1, 3) * (want ? -1 : 1);
    if (d <= 6 || r.chance(0.4)) {
      final a = r.range(2, 9 + d * 2), b = r.range(2, 9 + d);
      return DQ(a, b, a + b + delta, 2);
    }
    if (r.chance(0.5)) {
      final a = r.range(2, 9), b = r.range(2, 9);
      return DQ(a, b, a * b + delta, 3);
    }
    final a = r.range(10, 30), b = r.range(2, 9);
    // a−b<c doğruysa c farkın üstünde olmalı.
    return DQ(a, b, a - b - delta, 4);
  }

  @override
  BPuzzle? make(int d, SeededRandom r) {
    final qs = [for (var i = 0; i < count; i++) _q(d, r)];
    final gusts = [for (var i = 0; i < 48; i++) r.nextDouble() * 2 - 1];
    return DualPuzzle(qs, gusts, 0.8 + d * 0.11, 0.48 - d * 0.015, math.max<int>(1600, 4400 - d * 240));
  }

  @override
  bool check(BPuzzle p) =>
      p is DualPuzzle &&
      p.qs.length == count &&
      p.qs.every((q) => q.clean) &&
      p.qs.any((q) => q.answer) &&
      p.qs.any((q) => !q.answer) &&
      p.gusts.length >= 8 &&
      p.zone > 0.2;

  @override
  Widget build(BrainPlay play) => _DualView(play: play);
}

class _BalancePainter extends CustomPainter {
  final double pos, zone, wind;
  final bool inZone;
  _BalancePainter(this.pos, this.zone, this.wind, this.inZone);

  @override
  void paint(Canvas c, Size size) {
    final w = size.width, h = size.height;
    final y = h * 0.6;
    final half = w * 0.42;
    final cx = w / 2;
    final track = Paint()
      ..color = BColors.ink.withValues(alpha: 0.25)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(cx - half, y), Offset(cx + half, y), track);
    final z = Paint()
      ..color = BColors.good.withValues(alpha: 0.55)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(cx - half * zone, y), Offset(cx + half * zone, y), z);
    // rüzgâr oku
    final ay = h * 0.22;
    final len = wind * half * 0.5;
    final ap = Paint()
      ..color = BColors.accent.withValues(alpha: 0.6)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (len.abs() > 2) {
      c.drawLine(Offset(cx, ay), Offset(cx + len, ay), ap);
      final dir = len.sign;
      c.drawLine(Offset(cx + len, ay), Offset(cx + len - dir * 10, ay - 7), ap);
      c.drawLine(Offset(cx + len, ay), Offset(cx + len - dir * 10, ay + 7), ap);
    }
    final bx = cx + pos * half;
    final r = math.min(26.0, h * 0.16);
    c.drawCircle(Offset(bx, y - r - 3), r, Paint()..color = inZone ? BColors.accent : BColors.bad);
    c.drawCircle(Offset(bx - r * 0.3, y - r * 1.35 - 3), r * 0.25, Paint()..color = Colors.white.withValues(alpha: 0.6));
  }

  @override
  bool shouldRepaint(_BalancePainter old) => true;
}

class _DualView extends StatefulWidget {
  final BrainPlay play;
  const _DualView({required this.play});

  @override
  State<_DualView> createState() => _DualViewState();
}

class _DualViewState extends State<_DualView> with Ticker {
  late DualPuzzle p;
  bool started = false;
  double pos = 0, vel = 0, window = 0, panelW = 1;
  int ms = 0, qi = 0, qStart = 0, good = 0, zoneTicks = 0, allTicks = 0;
  String fb = '';
  final Map<int, int> holds = {};
  Timer? _loop;

  BrainPlay get play => widget.play;

  @override
  void initState() {
    super.initState();
    p = play.puzzle as DualPuzzle;
    window = p.window.toDouble();
  }

  @override
  void dispose() {
    _loop?.cancel();
    super.dispose();
  }

  void _start() {
    if (started) return;
    setState(() => started = true);
    startClock();
    qStart = 0;
    _loop = Timer.periodic(const Duration(milliseconds: 33), (_) => _tick());
  }

  double get wind => p.gusts[(ms ~/ 1500) % p.gusts.length];

  void _tick() {
    if (!mounted || ended) return;
    const dt = 0.033;
    ms += 33;
    var hold = 0;
    for (final v in holds.values) {
      hold += v;
    }
    final push = p.strength * 1.7 + 0.5;
    vel += (wind * p.strength + hold.sign * push) * dt;
    vel *= 0.965;
    pos += vel * dt;
    if (pos.abs() > 1) {
      pos = pos.sign;
      vel = -vel * 0.3;
    }
    allTicks++;
    if (pos.abs() <= p.zone) zoneTicks++;
    if (ms - qStart > window) {
      // Süre doldu: kaçırılan soru.
      window = math.min(p.window * 1.4, window * 1.08);
      fb = '…';
      _nextQ();
    }
    setState(() {});
  }

  void _nextQ() {
    if (qi + 1 >= p.qs.length) return _finish();
    qi++;
    qStart = ms;
  }

  void _answer(bool yes) {
    if (!started) return _start();
    if (ended) return;
    final ok = p.qs[qi].answer == yes;
    if (ok) {
      good++;
      window = math.max(p.window * 0.55, window * 0.93);
      play.ctx.sfx(Sfx.place);
    } else {
      window = math.min(p.window * 1.4, window * 1.1);
      play.ctx.sfx(Sfx.error);
    }
    fb = ok ? '✓' : '✗';
    _nextQ();
    if (mounted) setState(() {});
  }

  void _finish() {
    ended = true;
    _loop?.cancel();
    final acc = good / p.qs.length;
    final bal = allTicks == 0 ? 0.0 : zoneTicks / allTicks;
    final low = math.min(acc, bal);
    if (acc >= 0.7 && bal >= 0.55) {
      play.ctx.sfx(Sfx.win);
      play.win(
          score: (acc * 500 + bal * 500).round(),
          stars: low >= 0.9 ? 3 : (low >= 0.78 ? 2 : 1),
          seconds: seconds,
          correct: good);
    } else {
      play.ctx.sfx(Sfx.lose);
      play.lose(
          seconds: seconds,
          correct: good,
          headline: '${bt(play.lang, 'accuracy')}: ${(acc * 100).round()}% · ${bt(play.lang, 'balance')}: ${(bal * 100).round()}%');
    }
  }

  void _down(PointerDownEvent e) {
    if (!started) return _start();
    holds[e.pointer] = e.localPosition.dx < panelW / 2 ? -1 : 1;
  }

  void _up(int pointer) => holds.remove(pointer);

  @override
  Widget build(BuildContext context) {
    final lang = play.lang;
    final bal = allTicks == 0 ? 1.0 : zoneTicks / allTicks;
    final inZone = pos.abs() <= p.zone;
    return Column(children: [
      BrainBar(
          lang: lang,
          left: started ? '${qi + 1}/${p.qs.length}' : '',
          status: '${bt(lang, 'balance')}: ${(bal * 100).round()}%  ✓ $good'),
      Expanded(
        flex: 5,
        child: LayoutBuilder(builder: (context, box) {
          panelW = box.maxWidth;
          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _down,
            onPointerUp: (e) => _up(e.pointer),
            onPointerCancel: (e) => _up(e.pointer),
            child: Container(
              margin: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              decoration: BoxDecoration(color: BColors.paper, borderRadius: BorderRadius.circular(18)),
              child: Stack(children: [
                Positioned.fill(child: CustomPaint(painter: _BalancePainter(pos, p.zone, started ? wind : 0.0, inZone))),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 8,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(bt(lang, 'keepBall'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: BColors.ink)),
                  ),
                ),
                const Positioned(left: 14, bottom: 8, child: Icon(Icons.chevron_left, size: 36, color: BColors.ink)),
                const Positioned(right: 14, bottom: 8, child: Icon(Icons.chevron_right, size: 36, color: BColors.ink)),
              ]),
            ),
          );
        }),
      ),
      Expanded(
        flex: 4,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
          child: Column(children: [
            SizedBox(
              height: 26,
              child: FittedBox(fit: BoxFit.scaleDown, child: Text(bt(lang, 'isTrue'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
            ),
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(started ? p.qs[qi].text : bt(lang, 'go'),
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ),
            SizedBox(
              height: 6,
              child: started
                  ? LinearProgressIndicator(value: (1.0 - (ms - qStart) / window).clamp(0.0, 1.0).toDouble(), color: StudioLook.of(context).accent, backgroundColor: Colors.white24)
                  : null,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 64,
              child: Row(children: [
                Expanded(child: _btn(bt(lang, 'no'), BColors.bad, () => _answer(false))),
                SizedBox(width: 40, child: Center(child: Text(fb, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)))),
                Expanded(child: _btn(bt(lang, 'yes'), BColors.good, () => _answer(true))),
              ]),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _btn(String label, Color color, VoidCallback onTap) => Material(
        color: color,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
          ),
        ),
      );
}
