// Owner: WS2. Personal records (SPEC 6.11).
import '../data/assets/asset_catalog.dart';
import '../data/models/models.dart';
import 'api.dart';

/// Records broken by this session's sets (SPEC 6.11), at most one per exercise and type, with
/// the set that set it.
///
/// Types per loaded exercise, on the total load of SPEC 0.4 and on sets that count as work:
/// - `e1rm`: estimated best single (Epley, sets of 12 reps or fewer);
/// - `max_weight`: heaviest total load lifted for at least 1 rep;
/// - `best_volume`: best single-set volume (load x reps, x2 for unilateral).
///
/// A value is a record when it beats the best in [existing] (the stored records per exercise).
/// For an exercise with no stored record of that type the result is its **baseline**: store it,
/// but do not celebrate it (SPEC 6.11: the first session sets baselines silently). Use
/// [isCelebratedPr] or [celebratedPrs] to pick the trophies and the sets to mark `is_pr`.
List<PersonalRecord> detectPrs(List<SetLog> sessionSets, Map<String, List<PersonalRecord>> existing, AssetCatalog c,
    EquipmentProfile eq) {
  // exerciseId -> type -> (value, set)
  final best = <String, Map<PrType, (double, SetLog)>>{};
  for (final s in sessionSets) {
    if (!s.countsAsWork || s.reps < 1) continue;
    final ex = c.tryExercise(s.exerciseId);
    if (ex == null || ex.tracking != Tracking.weightReps) continue;
    final total = totalLoadKg(s, ex, eq);
    if (total <= 0) continue;
    final values = <PrType, double>{
      PrType.maxWeight: total,
      PrType.bestVolume: setVolumeKg(s, ex, eq),
      if (s.reps <= maxRepsForE1rm) PrType.e1rm: epley1rm(total, s.reps),
    };
    final perType = best.putIfAbsent(s.exerciseId, () => {});
    for (final MapEntry(key: type, value: v) in values.entries) {
      final current = perType[type];
      if (current == null || v > current.$1 + _epsilon) perType[type] = (v, s);
    }
  }

  final out = <PersonalRecord>[];
  for (final MapEntry(key: exerciseId, value: perType) in best.entries) {
    final stored = existing[exerciseId] ?? const <PersonalRecord>[];
    for (final type in PrType.values) {
      final candidate = perType[type];
      if (candidate == null) continue;
      final (value, set) = candidate;
      final previous = _bestOf(stored, type);
      if (previous != null && value <= previous + _epsilon) continue;
      out.add(PersonalRecord(
        exerciseId: exerciseId,
        type: type,
        value: _round(value),
        setLogId: set.id,
        achievedAt: set.completedAt,
      ));
    }
  }
  return out;
}

/// True when [record] (from [detectPrs]) beats an earlier record, i.e. it is a trophy and not a
/// silent first-session baseline.
bool isCelebratedPr(PersonalRecord record, Map<String, List<PersonalRecord>> existing) =>
    _bestOf(existing[record.exerciseId] ?? const [], record.type) != null;

/// The trophies among [detected] (see [isCelebratedPr]).
List<PersonalRecord> celebratedPrs(List<PersonalRecord> detected, Map<String, List<PersonalRecord>> existing) =>
    [for (final r in detected) if (isCelebratedPr(r, existing)) r];

const double _epsilon = 1e-6;

double? _bestOf(List<PersonalRecord> records, PrType type) {
  double? best;
  for (final r in records) {
    if (r.type == type && (best == null || r.value > best)) best = r.value;
  }
  return best;
}

double _round(double v) => (v * 1000).round() / 1000;
