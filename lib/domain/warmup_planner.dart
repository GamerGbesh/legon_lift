// Owner: WS2. Warm-up sets before the working sets (SPEC 6.3).
import 'dart:math' as math;

import '../data/models/models.dart';
import 'api.dart';

/// Rest after a warm-up set, seconds (SPEC 6.3).
const int warmupRestSeconds = 45;

/// Warm-up sets before working sets at [workingKg] (SPEC 6.3), lightest first.
///
/// Only for loaded exercises (`tracking == weight_reps`). The caller leaves them out when the
/// user turned warm-up sets off (`AppSettings.warmupSets`) and in "find your weight" mode
/// (the ramp sets replace them). Every set is lighter than [workingKg]; a load that would round
/// to the working weight is dropped, and two sets at the same load are merged.
List<WarmupSet> planWarmups(double workingKg, Exercise ex, ProgramItem item, EquipmentProfile eq) {
  if (ex.tracking != Tracking.weightReps || item.warmupSets == 0 || workingKg <= 0) return const [];
  final w = workingKg;
  final minLoad = switch (ex.loadType) {
    LoadType.smith => eq.smithBarKg,
    LoadType.barbell => eq.barKg,
    LoadType.plateLoaded => 0.0,
    _ => smallestLoad(ex, eq, null),
  };

  final List<(double, int)> sets;
  if (ex.loadType == LoadType.dumbbell) {
    sets = [(0.5 * w, 10)];
  } else if (item.warmupSets == 1) {
    sets = [(0.6 * w, 6)];
  } else if (w <= minLoad * 1.5 || w < 30) {
    sets = [(0.5 * w, 10)];
  } else {
    sets = [(0.5 * w, 8), (0.7 * w, 5), if (w >= 60) (0.85 * w, 2)];
  }

  final out = <WarmupSet>[];
  for (final (load, reps) in sets) {
    final rounded = roundDown(load, ex, eq, null);
    if (rounded >= w - loadEpsilon) continue;
    final kg = math.max(minLoad, rounded);
    if (kg >= w - loadEpsilon) continue;
    if (out.any((s) => (s.weightKg - kg).abs() <= loadEpsilon)) continue;
    out.add(WarmupSet(kg, reps));
  }
  return out;
}
