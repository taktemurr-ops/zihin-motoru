import 'core.dart';
import 'kinds/dual.dart';
import 'kinds/ek4.dart';
import 'kinds/faces.dart';
import 'kinds/focus.dart';
import 'kinds/logic.dart';
import 'kinds/memory.dart';
import 'kinds/speed.dart';

/// Zihin antrenmanı türleri.
const Map<String, BrainKind> kBrainKinds = {
  'hafiza-dizisi': SequenceKind(),
  'n-geri': NBackKind(),
  'stroop': StroopKind(),
  'schulte': SchulteKind(),
  'hizli-hesap': MathKind(),
  'gorsel-hafiza': GridMemoryKind(),
  'tepki': ReactionKind(),
  'oruntu': PatternKind(),
  'dondurme': RotationKind(),
  'gunluk-program': DailyKind(),
  'yuz-isim': FaceNameKind(),
  'cift-gorev': DualTaskKind(),
  'rakam-dizisi': DigitSpanKind(),
  'gorsel-arama': VisualSearchKind(),
  'kelime-hafizasi': WordMemoryKind(),
  'kestirme': EstimateKind(),
  'iz-surme': TrailKind(),
  'ok-yonu': FlankerKind(),
};

BrainRules brainRulesFor(String gameId, String kind) => brainRules(gameId, kBrainKinds[kind]!);
