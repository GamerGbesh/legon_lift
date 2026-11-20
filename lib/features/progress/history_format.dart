// Owner: WS5. Plain-language text for logged sets and sessions (Library history, Progress, session detail).
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/models/models.dart';
import '../../state/profile_store.dart';
import '../../widgets/weight_text.dart';

/// Whether the user shows weights in lb (Profile), false when no profile is provided.
bool useLbOf(BuildContext context) {
  try {
    return context.select<ProfileStore, bool>((s) => s.profile?.useLb ?? false);
  } on ProviderNotFoundException {
    return false;
  }
}

/// Whether the user shows lengths in ft/in (waist in inches), false when no profile is provided.
bool useInchesOf(BuildContext context) {
  try {
    return context.select<ProfileStore, bool>((s) => s.profile?.useFtIn ?? false);
  } on ProviderNotFoundException {
    return false;
  }
}

/// What was done in [s]: "2 × 12.5 kg, 10 reps", "12 reps each side", "45 s".
String setSummary(SetLog s, Exercise ex, {bool useLb = false}) {
  final each = ex.unilateral ? ' each side' : '';
  switch (ex.tracking) {
    case Tracking.weightReps:
      return '${WeightText.label(s.weightKg, ex, useLb: useLb)}, ${repsText(s.reps)}$each';
    case Tracking.reps:
      return '${repsText(s.reps)}$each';
    case Tracking.time:
      return durationText(s.durationSec ?? 0) + each;
  }
}

String repsText(int reps) => reps == 1 ? '1 rep' : '$reps reps';

/// 45 -> "45 s", 90 -> "1:30 min", 600 -> "10 min".
String durationText(int seconds) {
  if (seconds < 60) return '$seconds s';
  if (seconds % 60 == 0) return '${seconds ~/ 60} min';
  return '${Fmt.clock(seconds)} min';
}

/// Label of a set row: warm-up, "find your weight" sets, then numbered working sets.
String setKindLabel(SetLog s, int workingNumber) => switch (s.kind) {
      SetKind.warmup => 'Warm-up',
      SetKind.ramp => 'Finding weight',
      SetKind.test => 'Test set',
      SetKind.calibration => 'Check set',
      SetKind.working => 'Set $workingNumber',
    };

/// "Mon 9 Nov" (this year) or "Mon 9 Nov 2025".
String shortDate(DateTime d, {DateTime? now}) {
  final sameYear = d.year == (now ?? DateTime.now()).year;
  return DateFormat(sameYear ? 'EEE d MMM' : 'EEE d MMM y').format(d);
}

/// "9 Nov".
String dayMonth(DateTime d) => DateFormat('d MMM').format(d);

/// Compact axis numbers: 950 -> "950", 12500 -> "12.5k", 1200000 -> "1.2M".
String compactNumber(double v) {
  final a = v.abs();
  if (a >= 1e6) return '${Fmt.number(v / 1e6, maxDecimals: 1)}M';
  if (a >= 1e3) return '${Fmt.number(v / 1e3, maxDecimals: 1)}k';
  return Fmt.number(v, maxDecimals: a < 10 ? 1 : 0);
}
