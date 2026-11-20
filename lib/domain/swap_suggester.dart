// Owner: WS2. "Machine busy?" alternatives (SPEC 6.9) and the availability / limitation checks
// shared with the session builder (SPEC 6.8).
import '../data/assets/asset_catalog.dart';
import '../data/models/models.dart';
import 'api.dart';

/// Exercises the user flagged as painful are not suggested for this long (SPEC 6.9).
const Duration painCooldown = Duration(days: 14);

/// The exercise that needs bench uprights + a spotter (SPEC 2.1).
const String barbellBenchPressId = 'barbell_bench_press';

/// Whether the gym has everything [ex] needs (SPEC 6.8 `available`): every equipment id is
/// ticked, except that an exercise listing both bike and treadmill needs either one, and the
/// barbell bench press also needs "bench with uprights + spotter".
bool exerciseAvailable(Exercise ex, EquipmentProfile eq) {
  final needs = ex.equipment.toSet();
  if (needs.contains(Equipment.bike) && needs.contains(Equipment.treadmill)) {
    if (!eq.has(Equipment.bike) && !eq.has(Equipment.treadmill)) return false;
    needs
      ..remove(Equipment.bike)
      ..remove(Equipment.treadmill);
  }
  if (!needs.every(eq.available.contains)) return false;
  if (ex.id == barbellBenchPressId && !eq.hasBenchUprights) return false;
  return true;
}

/// Whether [ex] runs on a bike or treadmill (dropped when "cardio machines off", SPEC 6.8).
bool usesCardioMachine(Exercise ex) =>
    ex.equipment.contains(Equipment.bike) || ex.equipment.contains(Equipment.treadmill);

/// The equipment of [ex] that the gym is missing (empty when [exerciseAvailable]).
List<Equipment> missingEquipment(Exercise ex, EquipmentProfile eq) {
  final needs = ex.equipment.toSet();
  final missing = <Equipment>[];
  if (needs.contains(Equipment.bike) && needs.contains(Equipment.treadmill)) {
    if (!eq.has(Equipment.bike) && !eq.has(Equipment.treadmill)) missing.addAll([Equipment.bike, Equipment.treadmill]);
    needs
      ..remove(Equipment.bike)
      ..remove(Equipment.treadmill);
  }
  missing.addAll(needs.where((e) => !eq.has(e)));
  return missing;
}

/// Whether one of the user's [limitations] rules out [ex] (SPEC 6.8 `avoided`): its id is in
/// `limitation_rules[l].avoid_ids` or its movement pattern in `avoid_patterns`.
bool exerciseAvoided(Exercise ex, List<String> limitations, Map<String, dynamic> limitationRules) {
  for (final l in limitations) {
    final rule = limitationRules[l];
    if (rule is! Map) continue;
    if (_strings(rule['avoid_ids']).contains(ex.id)) return true;
    if (_strings(rule['avoid_patterns']).contains(ex.movementPattern.wire)) return true;
  }
  return false;
}

/// [phase]'s unlock keys minus the keys a limitation locks (`lock_unlocks`, SPEC 6.8).
Set<String> effectiveUnlocks(Phase phase, List<String> limitations, Map<String, dynamic> limitationRules) {
  final unlocks = {...phase.unlocks};
  for (final l in limitations) {
    final rule = limitationRules[l];
    if (rule is Map) unlocks.removeAll(_strings(rule['lock_unlocks']));
  }
  return unlocks;
}

/// Whether [ex] is allowed in a phase with [unlocks] (`unlockKey` is in it or is 'always').
bool exerciseUnlocked(Exercise ex, Set<String> unlocks) => ex.unlockKey == 'always' || unlocks.contains(ex.unlockKey);

/// The `cue` of each active limitation, once each, in the user's order.
List<String> limitationCues(List<String> limitations, Map<String, dynamic> limitationRules) {
  final out = <String>[];
  for (final l in limitations) {
    final rule = limitationRules[l];
    final cue = rule is Map ? rule['cue'] : null;
    if (cue is String && cue.isNotEmpty && !out.contains(cue)) out.add(cue);
  }
  return out;
}

/// Display label of the equipment that best describes [ex] ("Cable machine", "Dumbbells"),
/// skipping supporting kit (bench, plates, floor space).
String equipmentLabel(Exercise ex, GymProfileDefaults gym) {
  const supporting = {Equipment.bench, Equipment.plates, Equipment.bodyweight};
  if (ex.equipment.isEmpty) return gym.labelFor(Equipment.bodyweight);
  final main = ex.equipment.firstWhere((e) => !supporting.contains(e), orElse: () => ex.equipment.first);
  return gym.labelFor(main);
}

/// Up to [max] alternatives for [ex] in [item]'s slot (SPEC 6.9), best first:
/// the item's substitutions, then the exercise's, then every exercise with the same movement
/// pattern sharing a primary muscle (easiest first, then by name). An alternative is kept when
/// the gym has it, it is unlocked in [phase] (after limitation locks), it is not already in
/// today's session ([todayIds]), it was not flagged as painful in the last 14 days, it is not
/// hidden ("not at this gym"), and none of the user's [limitations] rules it out.
///
/// [limitations] are `UserProfile.limitations` (rules come from the catalog); [now] dates the
/// pain cool-down (defaults to the current time).
List<SwapOption> suggestSwaps(Exercise ex, ProgramItem item, AssetCatalog c, EquipmentProfile eq, Phase phase,
    Set<String> todayIds, Map<String, ExercisePrefs> prefs, Map<String, ExerciseState> states,
    {int max = 4, List<String> limitations = const [], DateTime? now}) {
  if (max <= 0) return const [];
  final rules = c.personalization.limitationRules;
  final unlocks = effectiveUnlocks(phase, limitations, rules);
  final at = now ?? DateTime.now();

  final similar = c.exercises
      .where((e) =>
          e.movementPattern == ex.movementPattern && e.primaryMuscles.any((m) => ex.primaryMuscles.contains(m)))
      .toList()
    ..sort((a, b) {
      final d = a.difficulty.compareTo(b.difficulty);
      return d != 0 ? d : a.name.compareTo(b.name);
    });
  final candidates = <Exercise>[
    for (final id in [...item.substitutions, ...ex.substitutions]) ?c.tryExercise(id),
    ...similar,
  ];

  final out = <SwapOption>[];
  final seen = <String>{ex.id};
  for (final cand in candidates) {
    if (out.length >= max) break;
    if (!seen.add(cand.id)) continue;
    if (todayIds.contains(cand.id)) continue;
    if (!exerciseAvailable(cand, eq) || !exerciseUnlocked(cand, unlocks)) continue;
    final p = prefs[cand.id];
    if (p != null && p.hidden) continue;
    final painAt = p?.lastPainAt;
    if (painAt != null && at.difference(painAt) < painCooldown) continue;
    if (exerciseAvoided(cand, limitations, rules)) continue;
    final sameMuscles = cand.primaryMuscles.any((m) => ex.primaryMuscles.contains(m));
    out.add(SwapOption(
      exercise: cand,
      why: '${sameMuscles ? 'Same muscles' : 'Similar exercise'} · ${equipmentLabel(cand, c.personalization.gym)}',
      hasHistory: states[cand.id]?.workingKg != null,
    ));
  }
  return out;
}

List<String> _strings(Object? v) => v is List ? [for (final x in v) if (x is String) x] : const [];
