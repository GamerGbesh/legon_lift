// Owner: WS2. Load rounding (SPEC 6.1).
//
// Every prescribed weight goes through these functions, so the player never asks for a load the
// gym cannot make: a dumbbell that is not on the rack, a plate combination that does not exist,
// or a pin that is not on the stack. Weights follow SPEC 0.4 (one dumbbell, total bar including
// the bar, plates added to the leg-press sled, pin number).
import '../data/models/models.dart';

/// Each plate size can be used up to this many times per side (SPEC 6.1).
const int maxPlatesPerSizePerSide = 4;

/// Per-side loads above this are never offered (SPEC 6.1).
const double maxPerSideKg = 150;

/// Stack and cable machines offer `k * increment` for k = 1..[maxStackSteps].
const int maxStackSteps = 60;

/// Two loads closer than this are the same load (floating point guard).
const double loadEpsilon = 1e-6;

/// Default dumbbell rack when the user's list is empty (personalization gym defaults).
const double _defaultDumbbellStepKg = 2;
const double _defaultDumbbellMaxKg = 40;

/// Load step for [ex] (SPEC 6.1): the user's per-exercise setting, then the program item, then
/// the exercise, then 2.5 kg.
double increment(Exercise ex, ProgramItem? item, ExercisePrefs? prefs) {
  final step = prefs?.incrementKg ?? item?.weightIncrementKg ?? ex.weightIncrementKg;
  return step == null || step <= 0 ? 2.5 : step;
}

/// Every load the user can set for [ex] with the equipment [eq], ascending and distinct.
List<double> availableLoads(Exercise ex, EquipmentProfile eq, ExercisePrefs? prefs) {
  switch (ex.loadType) {
    case LoadType.bodyweight || LoadType.time:
      return const [0];
    case LoadType.dumbbell:
      final rack = eq.dumbbellsKg.where((w) => w > 0).toList();
      if (rack.isEmpty) {
        return [
          for (var w = _defaultDumbbellStepKg; w <= _defaultDumbbellMaxKg + loadEpsilon; w += _defaultDumbbellStepKg)
            _clean(w),
        ];
      }
      return _sortedDistinct(rack);
    case LoadType.smith:
      return _barLoads(eq.smithBarKg, eq.platesKg);
    case LoadType.barbell:
      return _barLoads(eq.barKg, eq.platesKg);
    case LoadType.plateLoaded:
      return _barLoads(0, eq.platesKg);
    case LoadType.stack || LoadType.cable:
      final step = increment(ex, null, prefs);
      return [for (var k = 1; k <= maxStackSteps; k++) _clean(k * step)];
  }
}

/// Nearest available load to [kg] (ties -> the lower load).
double roundToAvailable(double kg, Exercise ex, EquipmentProfile eq, ExercisePrefs? prefs) =>
    nearestLoad(kg, availableLoads(ex, eq, prefs));

/// Largest available load <= [kg], or the smallest available load when every load is heavier.
double roundDown(double kg, Exercise ex, EquipmentProfile eq, ExercisePrefs? prefs) =>
    floorLoad(kg, availableLoads(ex, eq, prefs));

/// Smallest available load > [kg], or [kg] itself when nothing is heavier.
double nextUp(double kg, Exercise ex, EquipmentProfile eq, ExercisePrefs? prefs) =>
    ceilAboveLoad(kg, availableLoads(ex, eq, prefs));

/// Smallest available load for [ex].
double smallestLoad(Exercise ex, EquipmentProfile eq, ExercisePrefs? prefs) => availableLoads(ex, eq, prefs).first;

/// [nearestLoad], [floorLoad] and [ceilAboveLoad] on an ascending list (shared with the plate
/// calculator and the tests).
double nearestLoad(double kg, List<double> ascending) {
  if (ascending.isEmpty) return kg;
  var best = ascending.first;
  for (final l in ascending) {
    // Strictly closer wins, so on a tie the lower (earlier) load stays.
    if ((l - kg).abs() < (best - kg).abs() - loadEpsilon) best = l;
  }
  return best;
}

double floorLoad(double kg, List<double> ascending) {
  if (ascending.isEmpty) return kg;
  var best = ascending.first;
  for (final l in ascending) {
    if (l <= kg + loadEpsilon) {
      best = l;
    } else {
      break;
    }
  }
  return best;
}

double ceilAboveLoad(double kg, List<double> ascending) {
  for (final l in ascending) {
    if (l > kg + loadEpsilon) return l;
  }
  return kg;
}

/// Every per-side load that [platesKg] can make with each size used up to 4 times per side,
/// capped at 150 kg, ascending and including 0 (SPEC 6.1 `achievablePerSide`).
List<double> achievablePerSide(List<double> platesKg) => _perSideCache.putIfAbsent(_platesKey(platesKg), () {
      // Work in hundredths of a kg so sums are exact.
      final cap = (maxPerSideKg * 100).round();
      var sums = <int>{0};
      for (final p in platesKg.where((p) => p > 0).toSet()) {
        final unit = (p * 100).round();
        final next = <int>{};
        for (final s in sums) {
          for (var n = 0; n <= maxPlatesPerSizePerSide; n++) {
            final v = s + n * unit;
            if (v > cap) break;
            next.add(v);
          }
        }
        sums = next;
      }
      final out = sums.toList()..sort();
      return List.unmodifiable([for (final v in out) v / 100]);
    });

final Map<String, List<double>> _perSideCache = {};
final Map<String, List<double>> _barCache = {};

String _platesKey(List<double> plates) => ([...plates]..sort()).join(',');

/// `{ bar + 2 * s : s in achievablePerSide(plates) }`.
List<double> _barLoads(double barKg, List<double> plates) =>
    _barCache.putIfAbsent('$barKg|${_platesKey(plates)}', () {
      return List.unmodifiable(_sortedDistinct([for (final s in achievablePerSide(plates)) _clean(barKg + 2 * s)]));
    });

List<double> _sortedDistinct(Iterable<double> values) {
  final sorted = values.map(_clean).toList()..sort();
  final out = <double>[];
  for (final v in sorted) {
    if (out.isEmpty || (v - out.last).abs() > loadEpsilon) out.add(v);
  }
  return out;
}

/// Removes floating point noise (0.1 + 0.2 style) by rounding to 1 g.
double _clean(double kg) => (kg * 1000).round() / 1000;
