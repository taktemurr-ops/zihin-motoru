import 'core.dart';
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
};

BrainRules brainRulesFor(String gameId, String kind) => brainRules(gameId, kBrainKinds[kind]!);
