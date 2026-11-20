// Owner: WS2. First exposure: the "find your weight" ramp and the seed weights (SPEC 6.2).
import 'dart:math' as math;

import '../data/models/models.dart';
import 'api.dart';

/// Ramp sets never go past this step (SPEC 6.2: at most 4 ramp sets).
const int maxRampSteps = 4;

/// Rest between ramp sets, seconds (SPEC 6.2).
const int rampRestSeconds = 75;

/// Lifts that appear in later phases seed from the lift they replace (SPEC 6.2 `SEED_TRANSFER`).
/// Values are the source ids in priority order.
const Map<String, List<String>> seedTransferSources = {
  'smith_machine_bench_press': ['machine_chest_press'],
  'smith_machine_squat': ['leg_press'],
  'barbell_romanian_deadlift': ['dumbbell_romanian_deadlift'],
  'barbell_bent_over_row': ['chest_supported_db_row', 'one_arm_db_row'],
  'seated_dumbbell_shoulder_press': ['machine_shoulder_press'],
};

/// SEED_TRANSFER seed for [exerciseId] from the working weight of the lift it replaces
/// (SPEC 6.2), or null when the exercise has no transfer or no source has a working weight.
///
/// The value is NOT rounded: `seed(...)` (here [seedWeight], or `prescribe(seedKg: ...)`) rounds
/// it down to an available load for the exercise.
double? transferSeed(String exerciseId, Map<String, ExerciseState> states, EquipmentProfile eq) {
  final sources = seedTransferSources[exerciseId];
  if (sources == null) return null;
  for (final source in sources) {
    final src = states[source]?.workingKg;
    if (src == null || src <= 0) continue;
    return switch (exerciseId) {
      'smith_machine_bench_press' => 0.8 * src, // total including the bar
      'smith_machine_squat' => math.max(eq.smithBarKg + 10, 0.4 * src),
      'barbell_romanian_deadlift' => 1.6 * src, // src is per dumbbell
      'barbell_bent_over_row' => 1.5 * src,
      'seated_dumbbell_shoulder_press' => 0.35 * src, // per dumbbell
      _ => null,
    };
  }
  return null;
}

/// `seed(ex, eq, lastKnown?)` of SPEC 6.2: the first weight to try.
///
/// 1. [lastKnownKg] (a skipped ramp, a long break, or a transfer seed) rounded down;
/// 2. else [transferKg] (from [transferSeed]) rounded down;
/// 3. else the exercise's conservative starting weight (`startingWeightKg.low`) rounded down;
/// 4. else the smallest available load.
double seedWeight(Exercise ex, EquipmentProfile eq, {double? lastKnownKg, double? transferKg, ExercisePrefs? prefs}) {
  if (lastKnownKg != null) return roundDown(lastKnownKg, ex, eq, prefs);
  if (transferKg != null) return roundDown(transferKg, ex, eq, prefs);
  final start = ex.startingWeightKg;
  if (start == null) return smallestLoad(ex, eq, prefs);
  return roundDown(start.low, ex, eq, prefs);
}

/// Starts the "find your weight" ramp for [item] (SPEC 6.2 `start`). Pass the prescription's
/// seed (`rx.working.first.weightKg`, which already includes SEED_TRANSFER and the long-break
/// rule) or the last ramp weight of a skipped ramp as [lastKnownKg].
FindWeightState startFindWeight(Exercise ex, ProgramItem item, int targetRir, EquipmentProfile eq,
    {double? lastKnownKg}) {
  final lo = (item.repRange ?? ex.repRange ?? (8, 12)).$1;
  return FindWeightState(
    currentKg: seedWeight(ex, eq, lastKnownKg: lastKnownKg),
    step: 1,
    targetReps: lo + 2,
    targetRir: targetRir.clamp(0, 4),
  );
}

/// The ramp state after [RampNext]: the weight just done becomes `previousKg`.
FindWeightState advanceFindWeight(FindWeightState s, RampNext next) =>
    s.copyWith(previousKg: () => s.currentKg, currentKg: next.nextKg, step: s.step + 1);

/// One ramp set done (SPEC 6.2 `findWeightStep`): ramp again ([RampNext]) or start the working
/// sets ([RampDone]).
///
/// [reportedRir] is the "how many more could you have done?" answer, 0..4; null (not
/// answered) is read as `targetRir + 1`. [formBrokeOrPain] ends the ramp at the previous
/// weight, or 80% of this one on the first set.
RampResult findWeightStep(FindWeightState s, int reps, int? reportedRir, bool formBrokeOrPain, Exercise ex,
    EquipmentProfile eq) {
  final smallest = smallestLoad(ex, eq, null);
  if (formBrokeOrPain) return RampDone(roundDown(s.previousKg ?? s.currentKg * 0.8, ex, eq, null));
  final r = (reportedRir ?? s.targetRir + 1).clamp(0, 4);
  final e1rm = s.currentKg * (1 + (reps + r) / 30);
  // The load that gives targetReps with targetRir left.
  final ideal = e1rm / (1 + (s.targetReps + s.targetRir) / 30);
  final cand = roundToAvailable(ideal, ex, eq, null);
  if (cand < s.currentKg - loadEpsilon) {
    // Too heavy: stop ramping and step down.
    return RampDone(math.max(roundDown(ideal, ex, eq, null), smallest));
  }
  if ((cand - s.currentKg).abs() <= loadEpsilon) return RampDone(s.currentKg); // close enough
  if (s.step >= maxRampSteps) return RampDone(roundDown(ideal, ex, eq, null));
  var next = math.min(cand, roundDown(s.currentKg * 1.5, ex, eq, null));
  if (next <= s.currentKg + loadEpsilon) next = nextUp(s.currentKg, ex, eq, null);
  return RampNext(next);
}
