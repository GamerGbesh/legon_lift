// Owner: WS2. Load semantics (SPEC 0.4) and training stats (SPEC 6.11).
import '../core/format.dart';
import '../data/assets/asset_catalog.dart';
import '../data/models/models.dart';
import 'api.dart';

/// Total external load of a set (SPEC 0.4): both dumbbells, the whole bar, the leg-press plates
/// plus the sled when its weight is known, the pin; 0 for bodyweight and timed work.
double totalLoadKg(SetLog s, Exercise ex, EquipmentProfile eq) => totalLoadForWeight(s.weightKg, ex, eq);

/// [totalLoadKg] for a weight in the logging semantics of SPEC 0.4.
double totalLoadForWeight(double weightKg, Exercise ex, EquipmentProfile eq) => switch (ex.loadType) {
      LoadType.dumbbell => weightKg * (ex.dumbbellCount ?? 1),
      LoadType.plateLoaded => weightKg + (eq.legPressSledKnown ? eq.legPressSledKg : 0),
      LoadType.bodyweight || LoadType.time => 0,
      LoadType.smith || LoadType.barbell || LoadType.stack || LoadType.cable => weightKg,
    };

/// Inverse of [totalLoadForWeight]: the weight to log (per dumbbell, plates only, ...) for a
/// total external load. Used to turn an estimated best single back into a prescription.
double weightForTotalLoad(double totalKg, Exercise ex, EquipmentProfile eq) => switch (ex.loadType) {
      LoadType.dumbbell => totalKg / (ex.dumbbellCount ?? 1),
      LoadType.plateLoaded => totalKg - (eq.legPressSledKnown ? eq.legPressSledKg : 0),
      LoadType.bodyweight || LoadType.time => 0,
      LoadType.smith || LoadType.barbell || LoadType.stack || LoadType.cable => totalKg,
    };

/// Volume of one set (SPEC 0.4): total load x reps, doubled for unilateral exercises (reps are
/// logged per side). Warm-up and ramp sets have no volume.
double setVolumeKg(SetLog s, Exercise ex, EquipmentProfile eq) =>
    s.countsAsWork ? totalLoadKg(s, ex, eq) * s.reps * (ex.unilateral ? 2 : 1) : 0;

/// Training stats of the given sessions, normally one ISO week (SPEC 6.11). Discarded sessions
/// are ignored. Working sets are the sets that count as work (working, test and calibration).
/// Hard sets per muscle: working sets with `rir == null or rir <= 4`, 1.0 for each primary
/// muscle and 0.5 for each secondary muscle.
WeeklyStats weeklyStats(List<Session> sessions, AssetCatalog c, EquipmentProfile eq) {
  var count = 0;
  var sets = 0;
  var volume = 0.0;
  final hard = <Muscle, double>{};
  for (final session in sessions) {
    if (session.status == SessionStatus.discarded) continue;
    count++;
    for (final s in session.allSets) {
      if (!s.countsAsWork) continue;
      sets++;
      final ex = c.tryExercise(s.exerciseId);
      if (ex == null) continue;
      volume += setVolumeKg(s, ex, eq);
      if (s.rir == null || s.rir! <= 4) {
        for (final m in ex.primaryMuscles) {
          hard[m] = (hard[m] ?? 0) + 1.0;
        }
        for (final m in ex.secondaryMuscles) {
          hard[m] = (hard[m] ?? 0) + 0.5;
        }
      }
    }
  }
  return WeeklyStats(sessions: count, workingSets: sets, volumeKg: volume, hardSets: hard);
}

/// Monday 00:00 (local) of the ISO week containing [day].
DateTime isoWeekStart(DateTime day) {
  final d = DateTime(day.year, day.month, day.day);
  return DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday));
}

/// Mean weight of the entries dated in `[date - 6, date]`; null with fewer than 3 weigh-ins
/// in that window (SPEC 6.11).
double? movingAverage7(List<BodyEntry> entries, String date) {
  final end = Fmt.parseDateKey(date);
  final start = DateTime(end.year, end.month, end.day - 6);
  final weights = <double>[];
  for (final e in entries) {
    final w = e.weightKg;
    if (w == null) continue;
    final d = Fmt.parseDateKey(e.date);
    if (d.isBefore(start) || d.isAfter(end)) continue;
    weights.add(w);
  }
  if (weights.length < 3) return null;
  return weights.reduce((a, b) => a + b) / weights.length;
}

/// Calendar heatmap intensity (SPEC 6.11) for the number of working sets on a day:
/// 0 -> 0, 1-9 -> 1, 10-14 -> 2, 15-19 -> 3, 20+ -> 4.
int heatmapBucket(int workingSets) {
  if (workingSets <= 0) return 0;
  if (workingSets < 10) return 1;
  if (workingSets < 15) return 2;
  if (workingSets < 20) return 3;
  return 4;
}
