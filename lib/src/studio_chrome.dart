/// Motor içi arayüzün onaylı tasarımı: oyun içi paneller, pencereler, alt
/// sayfalar, kurulum ve kural ekranları merkezle aynı koyu paleti
/// (studio-core [StudioLook]) ve yapı taşlarını ([StudioPanel],
/// [StudioButton], [StudioPill]…) kullanır. Tahta çizimleri kendi
/// renklerini korur.
library;

import 'package:flutter/material.dart';
import 'package:studio_core/app/studio_ui.dart';

export 'package:studio_core/app/studio_ui.dart';

final Map<StudioLook, ThemeData> _cache = {};

/// Ağaçtaki paletten kurulmuş onaylı koyu tema (önbellekli).
ThemeData studioThemeOf(BuildContext context) {
  final look = StudioLook.of(context);
  final hit = _cache[look];
  if (hit != null) return hit;
  if (_cache.length > 8) _cache.clear();
  final base = buildStudioTheme(look);
  // Seçili çipte beyaz yazı okunur kalsın: vurgu rengi koyu zemine karıştırılır.
  final chipSel = Color.lerp(look.base, look.accent, 0.45)!;
  return _cache[look] = base.copyWith(
    chipTheme: base.chipTheme.copyWith(
      selectedColor: chipSel,
      secondarySelectedColor: chipSel,
      checkmarkColor: Colors.white,
      secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      side: BorderSide(color: look.accent.withValues(alpha: 0.55)),
    ),
  );
}

/// Alt ağacı onaylı koyu temayla çizer; buradan açılan diyalog ve alt
/// sayfalar da aynı temayı alır.
class StudioChrome extends StatelessWidget {
  final Widget child;
  const StudioChrome({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = studioThemeOf(context);
    return Theme(
      data: theme,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: theme.colorScheme.onSurface),
        child: IconTheme.merge(data: const IconThemeData(color: Colors.white), child: child),
      ),
    );
  }
}

/// Koyu zemin üstünde okunur ikincil yazı rengi.
const Color kStudioSubtle = Color(0xFFC9CCE4);
