// Onaylı koyu tasarımda okunurluk denetimi (testler için ortak yardımcı).
//
// Ekrandaki her yazının rengi, altındaki (en yakın atadaki) zemin rengiyle
// karşılaştırılır; yarı saydam zeminler alttakilerle karıştırılır, zemin
// bulunmazsa oyunun koyu degrade zemini varsayılır. Karşıtlık 3:1'in
// altındaysa yazı okunmaz sayılır.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_core/app/studio_ui.dart';
import 'package:studio_core/app/theme.dart' show buildTheme;

const StudioLook kTestLook = StudioLook();

/// Merkezdeki oyun ekranının benzeri: onaylı tema, koyu degrade zemin, tahta
/// için eski tema (studio-core play.dart ile aynı düzen).
Widget studioHost(Widget stage, {Color seed = const Color(0xFF3F6FD8), Locale? locale}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildStudioTheme(kTestLook),
    locale: locale,
    home: StudioLookScope(
      look: kTestLook,
      child: Scaffold(
        body: StudioBackdrop(
          child: SafeArea(
            child: Builder(
              builder: (context) => Theme(
                data: buildTheme(seed, Brightness.light).copyWith(extensions: [StudioLook.of(context)]),
                child: stage,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Color _avg(List<Color> cs) {
  double r = 0, g = 0, b = 0, a = 0;
  for (final c in cs) {
    r += c.r;
    g += c.g;
    b += c.b;
    a += c.a;
  }
  final n = cs.length;
  return Color.from(alpha: a / n, red: r / n, green: g / n, blue: b / n);
}

Color? _fromDecoration(Decoration? d) {
  if (d is BoxDecoration) {
    if (d.color != null) return d.color;
    if (d.gradient != null) return _avg(d.gradient!.colors);
  } else if (d is ShapeDecoration) {
    if (d.color != null) return d.color;
    if (d.gradient != null) return _avg(d.gradient!.colors);
  }
  return null;
}

Color _over(Color top, Color under) {
  final a = top.a;
  return Color.from(
    alpha: 1,
    red: top.r * a + under.r * (1 - a),
    green: top.g * a + under.g * (1 - a),
    blue: top.b * a + under.b * (1 - a),
  );
}

/// Yazının altındaki zemin (atalar boyunca, saydamlar karıştırılarak).
Color backgroundOf(Element e, Color base) {
  final layers = <Color>[];
  var stop = false;
  e.visitAncestorElements((a) {
    final w = a.widget;
    Color? c;
    if (w is ColoredBox) {
      c = w.color;
    } else if (w is DecoratedBox && w.position == DecorationPosition.background) {
      c = _fromDecoration(w.decoration);
    } else if (w is Ink) {
      c = w.decoration != null ? _fromDecoration(w.decoration) : null;
    } else if (w is Material) {
      if (w.type != MaterialType.transparency && w.color != null) c = w.color;
    } else if (w is StudioBackdrop) {
      c = _avg(w.colors ?? kTestLook.background);
    }
    if (c != null && c.a > 0.02) {
      layers.add(c);
      if (c.a > 0.95) stop = true;
    }
    return !stop;
  });
  var bg = base;
  for (final c in layers.reversed) {
    bg = _over(c, bg);
  }
  return bg;
}

bool _decorative(String s) {
  final t = s.trim();
  if (t.isEmpty) return true;
  // Yalnız emoji / simge karakterleri (çıkartma, yüz, piyon) okunurluk ölçüsüne girmez.
  return !RegExp(r'[0-9A-Za-zÀ-ɏͰ-ϿЀ-ӿ֐-׿؀-ۿऀ-෿฀-๿ᄀ-ᇿ぀-ヿ一-鿿가-힯]')
      .hasMatch(t);
}

/// Ekrandaki okunmayan yazılar ("yazı (renk / zemin = oran)").
List<String> unreadableTexts(WidgetTester tester, {double min = 3.0}) {
  final bad = <String>[];
  for (final e in find.byType(RichText).evaluate()) {
    final ro = e.renderObject;
    if (ro is! RenderParagraph || !ro.attached || ro.size.isEmpty) continue;
    final span = ro.text;
    final plain = span.toPlainText();
    final icon = (span.style?.fontFamily ?? '').contains('MaterialIcons');
    if (!icon && _decorative(plain)) continue;
    final color = span.style?.color;
    if (color == null || color.a < 0.36) continue;
    // Görünmez (saydamlıkla gizlenmiş) yazılar atlanır.
    var hidden = false;
    e.visitAncestorElements((a) {
      final w = a.widget;
      if ((w is Opacity && w.opacity < 0.3) || w is Offstage && w.offstage) hidden = true;
      return !hidden;
    });
    if (hidden) continue;
    final bg = backgroundOf(e, kTestLook.base);
    final effective = _over(color, bg);
    final r = contrastRatio(effective, bg);
    if (r < min) {
      final short = icon ? 'simge U+${plain.runes.first.toRadixString(16)}' : (plain.length > 30 ? '${plain.substring(0, 30)}…' : plain);
      bad.add('"$short" (${color.toARGB32().toRadixString(16)} / ${bg.toARGB32().toRadixString(16)} = ${r.toStringAsFixed(2)})');
    }
  }
  return bad;
}

void expectReadable(WidgetTester tester, {String where = '', double min = 3.0}) {
  final bad = unreadableTexts(tester, min: min);
  expect(bad, isEmpty, reason: 'Okunmayan yazı $where: ${bad.join(', ')}');
}

/// Açık renkli büyük yüzeyler (eski açık görünümün izleri): rapor için.
List<String> lightSurfaces(WidgetTester tester, {double minArea = 2400}) {
  final out = <String>[];
  for (final e in find
      .byWidgetPredicate((w) => w is DecoratedBox || w is ColoredBox || w is Ink || w is Material)
      .evaluate()) {
    final w = e.widget;
    Color? c;
    if (w is ColoredBox) {
      c = w.color;
    } else if (w is DecoratedBox) {
      c = _fromDecoration(w.decoration);
    } else if (w is Ink) {
      c = _fromDecoration(w.decoration);
    } else if (w is Material && w.type != MaterialType.transparency) {
      c = w.color;
    }
    if (c == null || c.a < 0.6 || c.computeLuminance() < 0.45) continue;
    final ro = e.renderObject;
    if (ro is! RenderBox || !ro.hasSize || ro.size.width * ro.size.height < minArea) continue;
    final texts = <String>[];
    void walk(Element x) {
      if (texts.length >= 3) return;
      final rw = x.widget;
      if (rw is RichText) {
        final t = rw.text.toPlainText().trim();
        if (t.isNotEmpty) texts.add(t.length > 18 ? t.substring(0, 18) : t);
      }
      x.visitChildElements(walk);
    }

    e.visitChildElements(walk);
    out.add('${w.runtimeType} #${c.toARGB32().toRadixString(16)} '
        '${ro.size.width.round()}x${ro.size.height.round()} ${texts.join(' | ')}');
  }
  return out;
}

final Set<String> _reported = {};

/// Açık yüzeyleri test çıktısına yazar (aynı satır bir kez).
void reportLight(WidgetTester tester, String where) {
  for (final s in lightSurfaces(tester)) {
    final line = 'AÇIK ZEMİN [$where] $s';
    if (_reported.add(line)) debugPrint(line);
  }
}

bool _isOverlay(Widget w) => w is Dialog || w is AlertDialog || w is SimpleDialog || w is BottomSheet;

/// Ekranı ızgara halinde dokunarak gezer; açılan her pencere ve her adımda
/// okunurluğu toplar (pencereler kapatılır).
Future<List<String>> sweepReadability(WidgetTester tester, String name, {int rows = 9, int cols = 6, double top = 60}) async {
  final issues = <String>{};
  void check(String where) {
    for (final s in unreadableTexts(tester)) {
      issues.add('$where: $s');
    }
    reportLight(tester, '$name $where');
  }

  check('açılış');
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  for (var y = top; y < size.height - 10; y += size.height / rows) {
    for (var x = 20.0; x < size.width; x += size.width / cols) {
      await tester.tapAt(Offset(x, y));
      await tester.pump(const Duration(milliseconds: 150));
      if (find.byWidgetPredicate(_isOverlay).evaluate().isNotEmpty) {
        await tester.pump(const Duration(milliseconds: 300));
        check('pencere');
        await tester.tapAt(const Offset(5, 5));
        await tester.pump(const Duration(milliseconds: 300));
        if (find.byWidgetPredicate(_isOverlay).evaluate().isNotEmpty) {
          await tester.state<NavigatorState>(find.byType(Navigator).last).maybePop();
          await tester.pump(const Duration(milliseconds: 300));
        }
      }
    }
    check('oyun');
  }
  return issues.toList();
}
