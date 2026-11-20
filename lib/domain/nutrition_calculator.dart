// Owner: WS6. Nutrition targets (SPEC 10.1), driven by `personalization.formulas`.
//
// Pure Dart. Every coefficient is read from `formulas` with the SPEC value as a fallback, so the
// data file stays the single source of truth; the test fixture is `worked_example`.
import 'dart:math' as math;

import '../data/models/models.dart';
import 'api.dart';

/// Grams of protein in one "protein point" (`protein_points.grams_per_point`).
const int proteinGramsPerPoint = 20;

/// One water sachet in ml (`formulas.water.sachet_ml`).
const int sachetMl = 500;

/// Daily nutrition targets (SPEC 10.1) for [u]. [currentWeightKg] replaces the profile weight
/// (normally the weight from [targetsWeightFor], i.e. the 7-day average at the last recalculation).
NutritionTargets nutritionTargets(UserProfile u, Personalization p, {double? currentWeightKg}) {
  final f = _Formulas(p.formulas);
  final w = currentWeightKg ?? u.weightKg;
  final hM = u.heightCm / 100;
  final bmi = w / (hM * hM);

  final bmr = f.bmr(u.sex, w, u.heightCm, u.ageY);
  final tdee = bmr * f.activityMultiplier(u.activityLevel);
  final adjustment = f.goalAdjustment(u.goal, bmi);
  final floor = f.calorieFloor(u.sex, bmr);
  final rawTarget = _roundTo(tdee * (1 + adjustment), f.calorieRounding);
  // The floor itself is lifted to the next rounding step so the shown target stays a round number.
  final calorieTarget = rawTarget >= floor ? rawTarget : _ceilTo(floor, f.calorieRounding);

  final refBmi = f.referenceBmi;
  final bmiWeight = refBmi * hM * hM;
  final goal = u.goalWeightKg;
  final referenceWeight = bmi < refBmi ? w : (goal != null ? math.max(goal, bmiWeight) : bmiWeight);

  final sanity = _ceilTo(f.proteinSanityGPerKg * w, f.proteinRounding);
  double protein(double gPerKg) => math.max(_roundTo(referenceWeight * gPerKg, f.proteinRounding), sanity);
  final proteinMin = protein(f.proteinMin);
  final proteinTarget = math.max(protein(f.proteinTarget), proteinMin);
  final proteinMax = math.max(protein(f.proteinMax), proteinTarget);

  final waterBase = w * f.waterPerKg;
  final waterClamped = waterBase.clamp(f.waterClampLow, f.waterClampHigh) + f.waterHotClimate;
  double water(double extra) => math.min(_roundTo(waterClamped + extra, f.waterRounding), f.waterCap);
  final waterRest = water(0);
  final waterTraining = water(f.waterTrainingPerHour * u.sessionMinutes / 60);

  final baseline = u.baselineSteps;
  final steps = baseline == null
      ? f.stepsDefault
      : (baseline + f.stepsBaselineAdd).clamp(f.stepsStartLow, f.stepsMax).toDouble();

  return NutritionTargets(
    bmi: bmi,
    bmrKcal: bmr.round(),
    tdeeKcal: tdee.round(),
    calorieTargetKcal: calorieTarget.round(),
    proteinMinG: proteinMin.round(),
    proteinTargetG: proteinTarget.round(),
    proteinMaxG: proteinMax.round(),
    proteinPointsTarget: (proteinTarget / proteinGramsPerPoint).round(),
    proteinPointsGoodDay: (proteinMin / proteinGramsPerPoint).round(),
    waterRestMl: waterRest.round(),
    waterTrainingMl: waterTraining.round(),
    stepsTarget: steps.round(),
    referenceWeightKg: (referenceWeight * 10).round() / 10,
    ratePctPerWeek: f.ratePctPerWeek,
  );
}

/// Lowest calorie target allowed for [sex] at [bmrKcal]: `max(min_kcal, bmr * min_fraction_of_bmr)`.
int calorieFloorKcal(Sex sex, int bmrKcal, Personalization p) => _Formulas(p.formulas).calorieFloor(sex, bmrKcal.toDouble()).ceil();

/// The weight the targets are calculated from, and when it was last updated (SPEC 10.1).
///
/// Starts at the profile weight; the first available 7-day average replaces it, then it only
/// changes when the average has moved by `recalculate_targets.every_kg_lost` (4 kg) or
/// `or_every_weeks` (8 weeks) have passed. The walk over the weigh-ins makes this deterministic
/// without storing any state.
({double kg, String? date, bool fromAverage}) targetsWeightFor(
  UserProfile u,
  List<BodyEntry> body,
  DateTime now,
  Personalization p,
) {
  final f = _Formulas(p.formulas);
  final today = _dayNumber(now);
  var kg = u.weightKg;
  String? date;
  int? anchorDay;
  for (final a in avg7Series(body)) {
    final day = _dayNumberOfKey(a.date);
    if (day > today) break;
    if (anchorDay == null ||
        (kg - a.kg).abs() >= f.recalcEveryKg - 1e-9 ||
        day - anchorDay >= f.recalcEveryWeeks * 7) {
      kg = a.kg;
      date = a.date;
      anchorDay = day;
    }
  }
  return (kg: kg, date: date, fromAverage: date != null);
}

/// 7-day moving averages at every date with a weigh-in, oldest first: the mean of the weigh-ins
/// in `[date - 6, date]`, only where that window holds at least 3 (SPEC 6.11 / 4.8).
List<({String date, double kg})> avg7Series(List<BodyEntry> entries, {int minWeighIns = 3}) {
  final weighed = [
    for (final e in entries)
      if (e.weightKg != null) (day: _dayNumberOfKey(e.date), date: e.date, kg: e.weightKg!),
  ]..sort((a, b) => a.day.compareTo(b.day));
  final out = <({String date, double kg})>[];
  var start = 0;
  var sum = 0.0;
  for (var i = 0; i < weighed.length; i++) {
    sum += weighed[i].kg;
    while (weighed[start].day < weighed[i].day - 6) {
      sum -= weighed[start].kg;
      start++;
    }
    final n = i - start + 1;
    if (n >= minWeighIns) out.add((date: weighed[i].date, kg: sum / n));
  }
  return out;
}

/// The step target after the weekly progression of SPEC 10.1: +`increase` (1,000) at the end of
/// every `every_weeks` (2-week) block since [startedAt] in which the target was reached on at
/// least `if_hit_days_of_7` (5) days of the block's last 7 days, up to `max` (10,000).
int stepsTargetFor(int startTarget, List<NutritionDay> days, DateTime startedAt, DateTime now, Personalization p) {
  final f = _Formulas(p.formulas);
  final byDay = {for (final d in days) _dayNumberOfKey(d.date): d};
  final start = _dayNumber(startedAt);
  final today = _dayNumber(now);
  final blockDays = f.stepsEveryWeeks * 7;
  var target = startTarget;
  for (var blockEnd = start + blockDays; blockEnd <= today; blockEnd += blockDays) {
    if (target >= f.stepsMax) break;
    var hit = 0;
    for (var d = blockEnd - 7; d < blockEnd; d++) {
      final day = byDay[d];
      if (day != null && (day.stepsHit || (day.steps ?? 0) >= target)) hit++;
    }
    if (hit >= f.stepsHitDays) target = math.min(target + f.stepsIncrease, f.stepsMax.round());
  }
  return target;
}

/// [base] with the applied check-in changes added (SPEC 10.2: shown target = formula target +
/// sum of deltas), never below [floorKcal] and with steps capped at the progression maximum.
NutritionTargets adjustedTargets(
  NutritionTargets base,
  List<CalorieAdjustment> adjustments, {
  required int floorKcal,
  int? stepsTarget,
  int stepsMax = 10000,
}) {
  final kcal = adjustments.fold<int>(0, (s, a) => s + a.deltaKcal);
  final steps = adjustments.fold<int>(0, (s, a) => s + (a.deltaSteps ?? 0));
  final startSteps = stepsTarget ?? base.stepsTarget;
  return NutritionTargets(
    bmi: base.bmi,
    bmrKcal: base.bmrKcal,
    tdeeKcal: base.tdeeKcal,
    calorieTargetKcal: math.max(base.calorieTargetKcal + kcal, floorKcal),
    proteinMinG: base.proteinMinG,
    proteinTargetG: base.proteinTargetG,
    proteinMaxG: base.proteinMaxG,
    proteinPointsTarget: base.proteinPointsTarget,
    proteinPointsGoodDay: base.proteinPointsGoodDay,
    waterRestMl: base.waterRestMl,
    waterTrainingMl: base.waterTrainingMl,
    stepsTarget: math.min(startSteps + steps, math.max(stepsMax, startSteps)),
    referenceWeightKg: base.referenceWeightKg,
    ratePctPerWeek: base.ratePctPerWeek,
  );
}

/// Water target in 500 ml sachets (6.5, 8 ...).
double sachetsFor(int ml) => ml / sachetMl;

/// How many of the 5 non-protein checklist items were met on [d]: water target, veg/fruit,
/// steps, sleep, no sugary drinks.
int checklistItemsMet(NutritionDay d, NutritionTargets t, {required bool trainingDay}) {
  final waterTarget = sachetsFor(trainingDay ? t.waterTrainingMl : t.waterRestMl);
  return [
    d.waterSachets >= waterTarget - 1e-9,
    d.vegFruit,
    d.stepsHit || (d.steps ?? 0) >= t.stepsTarget,
    d.sleepOk,
    d.noSugaryDrinks,
  ].where((x) => x).length;
}

/// `good_day_rule`: protein >= good-day points AND >= 3 of the other 5 items.
bool isGoodNutritionDay(NutritionDay d, NutritionTargets t, {required bool trainingDay}) =>
    d.proteinPoints >= t.proteinPointsGoodDay - 1e-9 && checklistItemsMet(d, t, trainingDay: trainingDay) >= 3;

/// Ingredients (`meal_ideas[].contains`) each onboarding diet note rules out.
const Map<String, Set<String>> dietNoteClashes = {
  'lactose_intolerant': {'milk'},
  'groundnut_allergy': {'groundnut'},
  'fish_allergy': {'fish'},
  'no_pork': {'pork'},
};

/// False when [meal] clashes with [dietNotes]: an ingredient in [dietNoteClashes], or
/// "vegetarian" and the meal is not tagged vegetarian (meat is not listed in `contains`).
bool mealFitsDiet(MealIdea meal, List<String> dietNotes) {
  if (dietNotes.contains('vegetarian') && !meal.tags.contains('vegetarian')) return false;
  for (final note in dietNotes) {
    final clash = dietNoteClashes[note];
    if (clash != null && meal.contains.any(clash.contains)) return false;
  }
  return true;
}

/// Meal-type filter: `lunch_or_dinner` meals show under both lunch and dinner; null = all.
bool mealMatchesType(MealIdea meal, String? type) =>
    type == null || meal.mealType == type || (meal.mealType == 'lunch_or_dinner' && (type == 'lunch' || type == 'dinner'));

// ---------------------------------------------------------------------------------------------

double _roundTo(double x, double step) => (x / step).round() * step;

double _ceilTo(double x, double step) => (x / step - 1e-9).ceil() * step;

int _dayNumber(DateTime t) => DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

int _dayNumberOfKey(String key) {
  final d = DateTime.parse(key);
  return _dayNumber(d);
}

/// Typed reads of `personalization.formulas` with the SPEC values as fallbacks.
class _Formulas {
  _Formulas(this.f);

  final Map<String, dynamic> f;

  Object? _at(List<String> path) {
    Object? node = f;
    for (final k in path) {
      if (node is! Map) return null;
      node = node[k];
    }
    return node;
  }

  double _num(List<String> path, double fallback) {
    final v = _at(path);
    return v is num ? v.toDouble() : fallback;
  }

  double bmr(Sex sex, double w, double hCm, int age) {
    final constant = _num(['bmr', 'constant', sex.wire], sex == Sex.male ? 5 : -161);
    return _num(['bmr', 'coef_weight'], 10) * w +
        _num(['bmr', 'coef_height'], 6.25) * hCm +
        _num(['bmr', 'coef_age'], -5) * age +
        constant;
  }

  double activityMultiplier(ActivityLevel level) => _num(['activity_multipliers', level.wire], switch (level) {
        ActivityLevel.sedentary => 1.2,
        ActivityLevel.lightlyActive => 1.375,
        ActivityLevel.moderatelyActive => 1.55,
        ActivityLevel.veryActive => 1.725,
        ActivityLevel.extraActive => 1.9,
      });

  /// recomp: -20% at BMI >= 25 else -10%; fat_loss: -20% (the -25% is only an upper bound for
  /// BMI >= 30, never applied automatically); muscle_gain +7.5%; maintain 0.
  double goalAdjustment(Goal goal, double bmi) {
    const g = ['calorie_target', 'goal_adjustment'];
    return switch (goal) {
      Goal.recomp => bmi >= 25 ? _num([...g, 'recomp', 'bmi_gte_25'], -0.2) : _num([...g, 'recomp', 'bmi_lt_25'], -0.1),
      Goal.fatLoss => _num([...g, 'fat_loss', 'default'], -0.2),
      Goal.muscleGain => _num([...g, 'muscle_gain', 'default'], 0.075),
      Goal.maintain => _num([...g, 'maintain', 'default'], 0),
    };
  }

  double get calorieRounding => _num(['calorie_target', 'rounding_kcal'], 50);

  double calorieFloor(Sex sex, double bmr) {
    final minKcal = _num(['calorie_target', 'floor', sex.wire, 'min_kcal'], sex == Sex.male ? 1500 : 1200);
    final fraction = _num(['calorie_target', 'floor', sex.wire, 'min_fraction_of_bmr'], sex == Sex.male ? 1.0 : 0.95);
    return math.max(minKcal, bmr * fraction);
  }

  double get referenceBmi => _num(['protein', 'reference_weight', 'ref_bmi'], 25);
  double get proteinMin => _num(['protein', 'g_per_kg_ref', 'min'], 1.6);
  double get proteinTarget => _num(['protein', 'g_per_kg_ref', 'target'], 1.9);
  double get proteinMax => _num(['protein', 'g_per_kg_ref', 'max'], 2.2);
  double get proteinRounding => _num(['protein', 'rounding_g'], 5);
  double get proteinSanityGPerKg => _num(['protein', 'sanity_min_g_per_kg_actual'], 1.2);

  double get waterPerKg => _num(['water', 'base_ml_per_kg'], 30);
  double get waterClampLow => _listNum(['water', 'base_clamp_ml'], 0, 2000);
  double get waterClampHigh => _listNum(['water', 'base_clamp_ml'], 1, 4000);
  double get waterHotClimate => _num(['water', 'hot_climate_add_ml'], 500);
  double get waterTrainingPerHour => _num(['water', 'training_add_ml_per_hour'], 750);
  double get waterRounding => _num(['water', 'rounding_ml'], 250);
  double get waterCap => _num(['water', 'cap_ml'], 5000);

  double get stepsDefault => _num(['steps', 'default_start_if_unknown'], 7000);
  double get stepsBaselineAdd => 2000;
  double get stepsStartLow => 6000;
  double get stepsMax => _num(['steps', 'progression', 'max'], 10000);
  int get stepsEveryWeeks => _num(['steps', 'progression', 'every_weeks'], 2).round();
  int get stepsHitDays => _num(['steps', 'progression', 'if_hit_days_of_7'], 5).round();
  int get stepsIncrease => _num(['steps', 'progression', 'increase'], 1000).round();

  double get recalcEveryKg => _num(['recalculate_targets', 'every_kg_lost'], 4);
  int get recalcEveryWeeks => _num(['recalculate_targets', 'or_every_weeks'], 8).round();

  (double, double) get ratePctPerWeek => (
        _listNum(['rate_of_loss', 'target_pct_bw_per_week'], 0, 0.5),
        _listNum(['rate_of_loss', 'target_pct_bw_per_week'], 1, 0.75),
      );

  double _listNum(List<String> path, int index, double fallback) {
    final v = _at(path);
    if (v is List && v.length > index) {
      final x = v[index];
      if (x is num) return x.toDouble();
    }
    return fallback;
  }
}
