import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/rng.dart';

import '../core.dart';
import '../texts.dart';

// ---------------------------------------------------------------- Yüz ve İsim

/// Yüz özellikleri: [biçim, ten, saç biçimi, saç rengi, göz, kaş, gözlük,
/// ağız, giysi, ayrıntı]. Değer aralıkları [kFaceRanges] içinde.
const List<int> kFaceRanges = [4, 6, 8, 6, 3, 3, 3, 3, 6, 3];

/// İsim havuzları (eşit uzunlukta, her biri kendi içinde benzersiz).
const List<String> kNamesTr = [
  'Ayşe', 'Mehmet', 'Zeynep', 'Mert', 'Elif', 'Can', 'Deniz', 'Ece', 'Burak', 'Selin', 'Kerem', 'Defne', //
  'Emre', 'Nazlı', 'Onur', 'Ceren', 'Kaan', 'Derya', 'Ozan', 'İpek', 'Barış', 'Aslı', 'Tolga', 'Gizem', //
  'Umut', 'Sevgi', 'Arda', 'Melis', 'Serkan', 'Pelin', 'Cem', 'Esra', 'Levent', 'Duygu', 'Yiğit', 'Buse', //
  'Tuncay', 'Hande', 'Volkan', 'Damla', 'Alper', 'Nehir', 'Engin', 'İlayda', 'Sinan', 'Gül', 'Kadir', 'Su',
];
const List<String> kNamesEn = [
  'Amelia', 'Oliver', 'Grace', 'Noah', 'Chloe', 'Leo', 'Hannah', 'Ethan', 'Ruby', 'Isaac', 'Maya', 'Lucas', //
  'Ivy', 'Owen', 'Nora', 'Caleb', 'Zoe', 'Miles', 'Clara', 'Felix', 'Lily', 'Jonah', 'Ella', 'Hugo', //
  'Alice', 'Theo', 'Iris', 'Adam', 'Rose', 'Henry', 'Eva', 'Simon', 'Jade', 'Arthur', 'Daisy', 'Ryan', //
  'Holly', 'Elliot', 'Sara', 'Dylan', 'Anna', 'Max', 'Molly', 'Ben', 'Freya', 'Sam', 'Kate', 'Tom',
];
const List<String> kNamesWorld = [
  'Ana', 'Leo', 'Mia', 'Omar', 'Yuki', 'Ravi', 'Lina', 'Noa', 'Sami', 'Aiko', 'Kofi', 'Elena', //
  'Juan', 'Amara', 'Ivan', 'Nadia', 'Chen', 'Priya', 'Luca', 'Sofia', 'Malik', 'Hana', 'Diego', 'Zara', //
  'Tariq', 'Mei', 'Pablo', 'Ines', 'Arjun', 'Lea', 'Jonas', 'Aya', 'Marco', 'Nina', 'Hugo', 'Rania', //
  'Kenji', 'Olga', 'Rafael', 'Amina', 'Viktor', 'Sana', 'Mateo', 'Laila', 'Emil', 'Dara', 'Tomas', 'Isla',
];

List<String> namesFor(String lang) => lang == 'tr' ? kNamesTr : (lang == 'en' ? kNamesEn : kNamesWorld);

/// İki yüz yeterince farklı mı? (en az 4 özellik ve en az bir belirgin özellik)
bool facesDistinct(List<int> a, List<int> b) {
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) diff++;
  }
  final strong = a[1] != b[1] || a[2] != b[2] || a[3] != b[3] || a[6] != b[6];
  return diff >= 4 && strong;
}

class FaceRound {
  final List<List<int>> faces;

  /// İsim havuzu sıraları (yüzlerle aynı sırada).
  final List<int> names;

  /// Sorulma sırası (yüz sıraları).
  final List<int> order;

  /// Her soru için dört seçenek (isim havuzu sıraları).
  final List<List<int>> options;
  const FaceRound(this.faces, this.names, this.order, this.options);
}

class FacePuzzle extends BPuzzle {
  final List<FaceRound> rounds;
  final int studyMs;
  final int delayMs;
  const FacePuzzle(this.rounds, this.studyMs, this.delayMs);
}

class FaceNameKind extends BrainKind {
  @override
  String get id => 'yuz-isim';
  const FaceNameKind();

  static const int poolSize = 48;

  @override
  BPuzzle? make(int d, SeededRandom r) {
    final k = math.min<int>(8, 3 + d ~/ 2);
    final rounds = <FaceRound>[];
    for (var rd = 0; rd < 3; rd++) {
      final faces = <List<int>>[];
      var guard = 0;
      while (faces.length < k && guard++ < 400) {
        final f = [for (final n in kFaceRanges) r.nextInt(n)];
        if (faces.every((o) => facesDistinct(o, f))) faces.add(f);
      }
      if (faces.length < k) return null;
      final pool = [for (var i = 0; i < poolSize; i++) i];
      r.shuffle(pool);
      final names = pool.take(k).toList();
      final order = [for (var i = 0; i < k; i++) i];
      r.shuffle(order);
      final options = <List<int>>[];
      for (final fi in order) {
        final answer = names[fi];
        final cands = [for (final n in names) if (n != answer) n];
        r.shuffle(cands);
        final extra = [for (final n in pool.skip(k)) n];
        final opts = <int>[answer, ...cands.take(3)];
        var e = 0;
        while (opts.length < 4) {
          opts.add(extra[e++]);
        }
        r.shuffle(opts);
        options.add(opts);
      }
      rounds.add(FaceRound(faces, names, order, options));
    }
    final perFace = math.max<int>(1100, 2000 - d * 90);
    return FacePuzzle(rounds, perFace * k, 800 + d * 350);
  }

  @override
  bool check(BPuzzle p) {
    if (p is! FacePuzzle || p.rounds.length != 3) return false;
    for (final rd in p.rounds) {
      final k = rd.faces.length;
      if (k < 3 || rd.names.length != k || rd.order.length != k || rd.options.length != k) return false;
      if (rd.names.toSet().length != k || rd.order.toSet().length != k) return false;
      for (var i = 0; i < k; i++) {
        for (var j = i + 1; j < k; j++) {
          if (!facesDistinct(rd.faces[i], rd.faces[j])) return false;
        }
      }
      for (var q = 0; q < k; q++) {
        final o = rd.options[q];
        if (o.length != 4 || o.toSet().length != 4 || !o.contains(rd.names[rd.order[q]])) return false;
        if (o.any((n) => n < 0 || n >= poolSize)) return false;
      }
    }
    return true;
  }

  @override
  Widget build(BrainPlay play) => _FaceView(play: play);
}

/// Yüz çizimi: sakin, saygılı, karikatürsüz bir portre.
class FacePainter extends CustomPainter {
  final List<int> f;
  FacePainter(this.f);

  static const skins = [Color(0xFFF6D7C3), Color(0xFFEBC0A0), Color(0xFFD5A07A), Color(0xFFB57D55), Color(0xFF8D5A3B), Color(0xFF5E3A26)];
  static const hairs = [Color(0xFF1F1A17), Color(0xFF3B2A20), Color(0xFF6B4A2E), Color(0xFF8C3B1F), Color(0xFFD9B26F), Color(0xFFB8B2AA)];
  static const fabrics = [Color(0xFF2A9D8F), Color(0xFF9B72AA), Color(0xFFE07A5F), Color(0xFF3D85C6), Color(0xFF6A994E), Color(0xFFB0413E)];
  static const shirts = [Color(0xFF3D85C6), Color(0xFFE9C46A), Color(0xFF81B29A), Color(0xFFE07A5F), Color(0xFF6D597A), Color(0xFF457B9D)];

  @override
  void paint(Canvas c, Size size) {
    final s = math.min(size.width, size.height);
    c.save();
    c.translate((size.width - s) / 2, (size.height - s) / 2);
    c.scale(s / 100, s / 100);
    final fill = Paint()..isAntiAlias = true;
    Paint col(Color x) => Paint()
      ..color = x
      ..isAntiAlias = true;
    final skin = skins[f[1]];
    final shade = Color.lerp(skin, Colors.black, 0.18)!;
    final hair = hairs[f[3]];
    final style = f[2];

    // arka plan dairesi
    c.drawCircle(const Offset(50, 50), 49, col(const Color(0xFFEDE7DC)));
    c.save();
    c.clipPath(Path()..addOval(const Rect.fromLTWH(1, 1, 98, 98)));

    // omuzlar ve giysi
    final shirt = shirts[f[8]];
    c.drawPath(
        Path()
          ..moveTo(14, 100)
          ..quadraticBezierTo(16, 76, 50, 74)
          ..quadraticBezierTo(84, 76, 86, 100)
          ..close(),
        col(shirt));
    // boyun
    c.drawRect(const Rect.fromLTWH(43, 60, 14, 16), col(shade));
    c.drawPath(
        Path()
          ..moveTo(42, 74)
          ..lineTo(50, 82)
          ..lineTo(58, 74)
          ..close(),
        col(Color.lerp(shirt, Colors.white, 0.25)!));

    // yüz biçimi
    final Rect head;
    switch (f[0]) {
      case 0:
        head = const Rect.fromLTWH(30, 20, 40, 48);
      case 1:
        head = const Rect.fromLTWH(28, 22, 44, 44);
      case 2:
        head = const Rect.fromLTWH(30, 21, 40, 46);
      default:
        head = const Rect.fromLTWH(31, 18, 38, 51);
    }
    final headPath = f[0] == 2
        ? (Path()..addRRect(RRect.fromRectAndRadius(head, const Radius.circular(15))))
        : (Path()..addOval(head));

    // başörtüsü ya da uzun saç arkası
    if (style == 7) {
      final fab = fabrics[f[3]];
      c.drawOval(Rect.fromLTWH(head.left - 9, head.top - 8, head.width + 18, head.height + 22), col(fab));
      c.drawPath(
          Path()
            ..moveTo(head.left - 6, head.bottom - 4)
            ..quadraticBezierTo(50, head.bottom + 18, head.right + 6, head.bottom - 4)
            ..lineTo(head.right + 10, 86)
            ..lineTo(head.left - 10, 86)
            ..close(),
          col(fab));
    } else if (style == 2) {
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(head.left - 6, head.top - 4, head.width + 12, 60), const Radius.circular(16)), col(hair));
    } else if (style == 6) {
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(head.left - 5, head.top - 4, head.width + 10, head.height * 0.82), const Radius.circular(14)),
          col(hair));
    } else if (style == 3) {
      for (var i = 0; i < 11; i++) {
        final a = math.pi + i * math.pi / 10;
        c.drawCircle(Offset(50 + math.cos(a) * (head.width / 2 + 2), head.top + 20 + math.sin(a) * 22), 9, col(hair));
      }
    } else if (style == 4) {
      c.drawCircle(Offset(50, head.top - 3), 8, col(hair));
    }

    // kulaklar
    if (style != 7) {
      c.drawOval(Rect.fromCenter(center: Offset(head.left + 1, head.center.dy + 2), width: 7, height: 11), col(shade));
      c.drawOval(Rect.fromCenter(center: Offset(head.right - 1, head.center.dy + 2), width: 7, height: 11), col(shade));
      if (f[9] == 2) {
        c.drawCircle(Offset(head.left + 1, head.center.dy + 9), 1.8, col(const Color(0xFFE9C46A)));
        c.drawCircle(Offset(head.right - 1, head.center.dy + 9), 1.8, col(const Color(0xFFE9C46A)));
      }
    }

    // yüz
    fill.color = skin;
    c.drawPath(headPath, fill);

    // ön saç
    if (style != 7) {
      c.save();
      c.clipRect(Rect.fromLTWH(0, 0, 100, head.top + head.height * 0.33));
      final cap = Rect.fromLTWH(head.left - 2, head.top - 4, head.width + 4, head.height * 0.75);
      final hp = col(style == 5 ? hair.withValues(alpha: 0.55) : hair);
      if (style == 5) {
        c.drawOval(cap.deflate(1.5), hp);
      } else {
        c.drawOval(cap, hp);
      }
      c.restore();
      if (style == 1) {
        c.drawPath(
            Path()
              ..moveTo(head.left + 4, head.top + 16)
              ..quadraticBezierTo(head.left + 12, head.top + 2, head.right - 6, head.top + 10)
              ..lineTo(head.right - 4, head.top + 4)
              ..quadraticBezierTo(50, head.top - 6, head.left + 2, head.top + 10)
              ..close(),
            col(hair));
      } else if (style == 6) {
        c.drawRect(Rect.fromLTWH(head.left + 2, head.top + 6, head.width - 4, 8), col(hair));
      }
    } else {
      // başörtüsünün yüzü çevreleyen kenarı
      c.drawArc(Rect.fromLTWH(head.left - 1, head.top - 1, head.width + 2, head.height * 0.7), math.pi, math.pi, false,
          Paint()
            ..color = Color.lerp(fabrics[f[3]], Colors.white, 0.25)!
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..isAntiAlias = true);
    }

    // yüz ayrıntıları
    final ink = Color.lerp(hairs[f[3] == 5 ? 1 : f[3]], Colors.black, 0.2)!;
    final eyeY = head.top + head.height * 0.5;
    final browY = eyeY - 7;
    final bw = 1.2 + f[5] * 0.8;
    final browPaint = Paint()
      ..color = style == 7 ? const Color(0xFF3B2A20) : ink
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = bw
      ..isAntiAlias = true;
    c.drawLine(Offset(40, browY), Offset(46, browY - 1), browPaint);
    c.drawLine(Offset(54, browY - 1), Offset(60, browY), browPaint);
    final eyeCol = col(const Color(0xFF22303F));
    for (final ex in const [43.0, 57.0]) {
      switch (f[4]) {
        case 0:
          c.drawCircle(Offset(ex, eyeY), 2.2, eyeCol);
        case 1:
          c.drawOval(Rect.fromCenter(center: Offset(ex, eyeY), width: 6, height: 3), eyeCol);
        default:
          c.drawCircle(Offset(ex, eyeY), 3, col(Colors.white));
          c.drawCircle(Offset(ex, eyeY), 1.9, eyeCol);
      }
    }
    // burun
    c.drawPath(
        Path()
          ..moveTo(50, eyeY + 2)
          ..quadraticBezierTo(47, eyeY + 9, 50.5, eyeY + 10),
        Paint()
          ..color = shade
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..isAntiAlias = true);
    // ağız
    final my = eyeY + 16;
    final mouth = Paint()
      ..color = const Color(0xFF9E4A47)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.8
      ..isAntiAlias = true;
    switch (f[7]) {
      case 0:
        c.drawArc(Rect.fromCenter(center: Offset(50, my - 3), width: 12, height: 7), 0.2, math.pi - 0.4, false, mouth);
      case 1:
        c.drawLine(Offset(46, my), Offset(54, my), mouth);
      default:
        c.drawPath(
            Path()
              ..moveTo(45, my - 1)
              ..quadraticBezierTo(50, my + 5, 55, my - 1)
              ..close(),
            col(const Color(0xFF9E4A47)));
    }
    // çil
    if (f[9] == 1) {
      final fr = col(Color.lerp(skin, const Color(0xFF8C3B1F), 0.45)!);
      for (final o in const [Offset(39, 4), Offset(42, 6), Offset(40, 8), Offset(58, 4), Offset(61, 6), Offset(60, 8)]) {
        c.drawCircle(Offset(o.dx, eyeY + o.dy), 0.8, fr);
      }
    }
    // gözlük
    if (f[6] != 0) {
      final gl = Paint()
        ..color = const Color(0xFF2B2D42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..isAntiAlias = true;
      if (f[6] == 1) {
        c.drawCircle(Offset(43, eyeY), 5.5, gl);
        c.drawCircle(Offset(57, eyeY), 5.5, gl);
      } else {
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(43, eyeY), width: 12, height: 9), const Radius.circular(2)), gl);
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(57, eyeY), width: 12, height: 9), const Radius.circular(2)), gl);
      }
      c.drawLine(Offset(48.5, eyeY), Offset(51.5, eyeY), gl);
    }
    c.restore();
    c.restore();
  }

  @override
  bool shouldRepaint(FacePainter old) => old.f != f;
}

Widget faceWidget(List<int> f, double size) => SizedBox(width: size, height: size, child: CustomPaint(painter: FacePainter(f)));

enum _Phase { study, wait, recall }

class _FaceView extends StatefulWidget {
  final BrainPlay play;
  const _FaceView({required this.play});

  @override
  State<_FaceView> createState() => _FaceViewState();
}

class _FaceViewState extends State<_FaceView> with Ticker {
  late FacePuzzle p;
  _Phase phase = _Phase.study;
  int round = 0, q = 0, lives = 3, correct = 0, asked = 0, token = 0;
  int? picked;

  BrainPlay get play => widget.play;
  FaceRound get rd => p.rounds[round];
  List<String> get names => namesFor(play.lang);

  @override
  void initState() {
    super.initState();
    p = play.puzzle as FacePuzzle;
    startClock();
    _study();
  }

  void _study() {
    final t = ++token;
    setState(() {
      phase = _Phase.study;
      q = 0;
      picked = null;
    });
    later(p.studyMs, () {
      if (t == token) _wait();
    });
  }

  void _wait() {
    final t = ++token;
    setState(() => phase = _Phase.wait);
    later(p.delayMs, () {
      if (t == token) setState(() => phase = _Phase.recall);
    });
  }

  void _answer(int name) {
    if (phase != _Phase.recall || picked != null || ended) return;
    final ok = name == rd.names[rd.order[q]];
    asked++;
    setState(() => picked = name);
    if (ok) {
      correct++;
      play.ctx.sfx(Sfx.place);
    } else {
      lives--;
      play.ctx.sfx(Sfx.error);
    }
    if (lives <= 0) {
      ended = true;
      later(800, () => play.lose(seconds: seconds, correct: correct, headline: '${bt(play.lang, 'accuracy')}: ${(correct * 100 / asked).round()}%'));
      return;
    }
    later(ok ? 450 : 900, () {
      if (q + 1 < rd.order.length) {
        setState(() {
          q++;
          picked = null;
        });
        return;
      }
      if (round + 1 < p.rounds.length) {
        play.ctx.sfx(Sfx.clear);
        round++;
        _study();
        return;
      }
      ended = true;
      play.ctx.sfx(Sfx.win);
      final acc = asked == 0 ? 0.0 : correct / asked;
      play.win(score: (acc * 600).round() + lives * 80, stars: lives, seconds: seconds, correct: correct);
    });
  }

  Widget _studyView(String lang) {
    final k = rd.faces.length;
    final cols = k <= 4 ? 2 : (k <= 6 ? 3 : 4);
    final rows = (k + cols - 1) ~/ cols;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: FittedBox(fit: BoxFit.scaleDown, child: Text(bt(lang, 'study'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
      ),
      Expanded(
        child: LayoutBuilder(builder: (context, box) {
          final cw = (box.maxWidth - 16) / cols;
          final ch = (box.maxHeight - 8) / rows;
          final fs = math.max(20.0, math.min(cw - 8, ch - 30));
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (var row = 0; row < rows; row++)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  for (var col = 0; col < cols; col++)
                    SizedBox(
                      width: cw,
                      height: math.min(ch, fs + 30),
                      child: row * cols + col < k
                          ? FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                              faceWidget(rd.faces[row * cols + col], fs),
                              SizedBox(
                                height: 24,
                                width: cw - 4,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(names[rd.names[row * cols + col]], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                                ),
                              ),
                            ]))
                          : null,
                    ),
                ]),
            ]),
          );
        }),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: FilledButton.icon(onPressed: _wait, icon: const Icon(Icons.check), label: Text(bt(lang, 'ready'))),
      ),
    ]);
  }

  Widget _recallView(String lang) {
    final fi = rd.order[q];
    final answer = rd.names[fi];
    return Column(children: [
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(bt(lang, 'whoIs'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
      ),
      Expanded(
        child: LayoutBuilder(builder: (context, box) {
          final s = math.max(40.0, math.min(box.maxWidth - 40, box.maxHeight - 16));
          return Center(child: faceWidget(rd.faces[fi], s));
        }),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        child: Column(children: [
          for (var row = 0; row < 2; row++)
            Row(children: [
              for (var col = 0; col < 2; col++)
                Expanded(child: _option(rd.options[q][row * 2 + col], answer)),
            ]),
        ]),
      ),
    ]);
  }

  Widget _option(int name, int answer) {
    Color bg = BColors.soft;
    if (picked != null) {
      if (name == answer) {
        bg = BColors.good;
      } else if (name == picked) {
        bg = BColors.bad;
      }
    }
    return Padding(
      padding: const EdgeInsets.all(5),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _answer(name),
          child: SizedBox(
            height: 56,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(names[name],
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: picked != null && (name == answer || name == picked) ? Colors.white : BColors.ink)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = play.lang;
    final Widget body = switch (phase) {
      _Phase.study => _studyView(lang),
      _Phase.wait => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.hourglass_bottom, size: 64, color: BColors.accent),
            const SizedBox(height: 12),
            Text(bt(lang, 'yourTurn'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ]),
        ),
      _Phase.recall => _recallView(lang),
    };
    return Column(children: [
      BrainBar(lang: lang, left: '${round + 1}/${p.rounds.length}', status: '${bt(lang, 'lives')}: ${'♥' * lives}'),
      Expanded(child: body),
    ]);
  }
}
