import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/data/models/models.dart';
import 'package:legon_lift/domain/api.dart';

import '../fakes/test_catalog.dart';

void main() {
  final p = loadTestCatalog().personalization;
  final start = DateTime(2026, 9, 7, 9); // a Monday
  UserProfile user({
    Sex sex = Sex.male,
    int age = 22,
    double heightCm = 172,
    double weightKg = 95,
    double? goalWeightKg,
    ActivityLevel activity = ActivityLevel.lightlyActive,
    Goal goal = Goal.recomp,
    int sessionMinutes = 60,
    int? baselineSteps,
  }) =>
      UserProfile.defaults(start).copyWith(
        sex: sex,
        ageY: age,
        heightCm: heightCm,
        weightKg: weightKg,
        goalWeightKg: () => goalWeightKg,
        activityLevel: activity,
        goal: goal,
        sessionMinutes: sessionMinutes,
        baselineSteps: () => baselineSteps,
      );

  group('worked_example (SPEC 10.1 fixture)', () {
    final ex = p.workedExample;
    final inputs = (ex['inputs'] as Map).cast<String, Object?>();
    final u = user(
      sex: Sex.fromWire(inputs['sex']! as String),
      weightKg: (inputs['weight_kg']! as num).toDouble(),
      heightCm: (inputs['height_cm']! as num).toDouble(),
      age: (inputs['age_y']! as num).toInt(),
      activity: ActivityLevel.fromWire(inputs['activity_level']! as String),
      goal: Goal.fromWire(inputs['goal']! as String),
      sessionMinutes: (inputs['session_minutes']! as num).toInt(),
    );
    final t = nutritionTargets(u, p);
    num v(String key, [String? sub]) {
      final x = ex[key];
      return (sub == null ? x : (x as Map)[sub]) as num;
    }

    test('bmi, bmr, tdee, calorie target and deficit', () {
      expect((t.bmi * 10).round() / 10, v('bmi'));
      expect(t.bmrKcal, v('bmr_kcal'));
      expect(t.tdeeKcal, v('tdee_kcal'));
      expect(t.calorieTargetKcal, v('calorie_target_kcal'));
      expect(t.tdeeKcal - t.calorieTargetKcal, v('daily_deficit_kcal'));
    });

    test('target loss rate in kg per week', () {
      final rate = (ex['target_rate_kg_per_week'] as List).cast<num>();
      expect(((u.weightKg * t.ratePctPerWeek.$1 / 100) * 100).round() / 100, rate[0]);
      expect(((u.weightKg * t.ratePctPerWeek.$2 / 100) * 100).round() / 100, rate[1]);
    });

    test('reference weight, protein and points', () {
      expect(t.referenceWeightKg, v('reference_weight_kg'));
      expect(t.proteinMinG, v('protein_g', 'min'));
      expect(t.proteinTargetG, v('protein_g', 'target'));
      expect(t.proteinMaxG, v('protein_g', 'max'));
      expect(t.proteinPointsTarget, v('protein_points_per_day'));
      expect(t.proteinPointsGoodDay, 6);
      // 0.4 g/kg of reference weight per meal.
      expect(((t.referenceWeightKg * 0.4) / 5).round() * 5, v('per_meal_protein_g'));
    });

    test('water and sachets, steps', () {
      expect(t.waterRestMl, v('water_ml', 'rest_day'));
      expect(t.waterTrainingMl, v('water_ml', 'training_day'));
      expect(sachetsFor(t.waterRestMl), v('water_ml', 'rest_day_sachets'));
      expect(sachetsFor(t.waterTrainingMl), v('water_ml', 'training_day_sachets'));
      expect(t.stepsTarget, v('steps_target'));
    });
  });

  group('nutritionTargets edge cases', () {
    test('BMI under 25 uses the actual weight as reference and -10% for recomp', () {
      final t = nutritionTargets(user(weightKg: 70), p);
      expect(t.bmi, lessThan(25));
      expect(t.referenceWeightKg, 70);
      // bmr = 700 + 1075 - 110 + 5 = 1670; tdee = 2296.25; * 0.9 = 2066.6 -> 2050.
      expect(t.calorieTargetKcal, 2050);
      expect(t.proteinTargetG, 135); // 70 * 1.9 = 133 -> 135
    });

    test('goal weight above the BMI-25 weight raises the reference weight', () {
      final t = nutritionTargets(user(goalWeightKg: 85), p);
      expect(t.referenceWeightKg, 85);
      expect(t.proteinTargetG, 160); // 85 * 1.9 = 161.5 -> 160
    });

    test('protein never below 1.2 g per kg of actual weight', () {
      final t = nutritionTargets(user(weightKg: 160), p);
      expect(t.proteinMinG, greaterThanOrEqualTo(192));
      expect(t.proteinTargetG, greaterThanOrEqualTo(t.proteinMinG));
      expect(t.proteinMaxG, greaterThanOrEqualTo(t.proteinTargetG));
    });

    test('calorie floor: never below BMR for men, rounded up', () {
      final t = nutritionTargets(user(activity: ActivityLevel.sedentary, goal: Goal.fatLoss, weightKg: 60, heightCm: 180), p);
      final floor = calorieFloorKcal(Sex.male, t.bmrKcal, p);
      expect(t.calorieTargetKcal, greaterThanOrEqualTo(floor));
      expect(t.calorieTargetKcal % 50, 0);
    });

    test('female floor is max(1200, 0.95 BMR)', () {
      final t = nutritionTargets(user(sex: Sex.female, weightKg: 50, heightCm: 150, activity: ActivityLevel.sedentary, goal: Goal.fatLoss), p);
      // bmr = 500 + 937.5 - 110 - 161 = 1166.5; floor = 1200.
      expect(calorieFloorKcal(Sex.female, t.bmrKcal, p), 1200);
      expect(t.calorieTargetKcal, 1200);
    });

    test('muscle gain adds 7.5%, maintain keeps TDEE', () {
      expect(nutritionTargets(user(goal: Goal.muscleGain), p).calorieTargetKcal, 2850); // 2640 * 1.075 = 2838
      expect(nutritionTargets(user(goal: Goal.maintain), p).calorieTargetKcal, 2650); // 2640 -> 2650
    });

    test('steps start from the baseline + 2,000, clamped to 6,000-10,000', () {
      expect(nutritionTargets(user(baselineSteps: 3000), p).stepsTarget, 6000);
      expect(nutritionTargets(user(baselineSteps: 5500), p).stepsTarget, 7500);
      expect(nutritionTargets(user(baselineSteps: 12000), p).stepsTarget, 10000);
    });

    test('water is clamped and capped', () {
      final light = nutritionTargets(user(weightKg: 50, heightCm: 160), p);
      expect(light.waterRestMl, 2500); // 2000 + 500
      final heavy = nutritionTargets(user(weightKg: 200, sessionMinutes: 75), p);
      expect(heavy.waterRestMl, 4500);
      expect(heavy.waterTrainingMl, 5000); // 4500 + 937.5 -> capped
    });

    test('currentWeightKg replaces the profile weight', () {
      final t = nutritionTargets(user(), p, currentWeightKg: 90);
      expect(t.bmrKcal, 1870);
    });
  });

  group('avg7Series', () {
    test('needs 3 weigh-ins in the 7-day window', () {
      final s = avg7Series(const [
        BodyEntry(date: '2026-09-07', weightKg: 95),
        BodyEntry(date: '2026-09-08', weightKg: 94),
        BodyEntry(date: '2026-09-09', waistCm: 100),
        BodyEntry(date: '2026-09-10', weightKg: 93),
        BodyEntry(date: '2026-09-20', weightKg: 92),
      ]);
      expect(s, hasLength(1));
      expect(s.single.date, '2026-09-10');
      expect(s.single.kg, closeTo(94, 1e-9));
    });

    test('window drops entries older than 6 days', () {
      final s = avg7Series([
        for (var d = 1; d <= 10; d++) BodyEntry(date: '2026-09-${d.toString().padLeft(2, '0')}', weightKg: 100.0 - d),
      ]);
      // On the 10th: days 4..10 -> weights 96..90, mean 93.
      expect(s.last.kg, closeTo(93, 1e-9));
    });
  });

  group('targetsWeightFor (recalculate every 4 kg or 8 weeks)', () {
    List<BodyEntry> daily(DateTime from, int days, double Function(int day) kg) => [
          for (var i = 0; i < days; i++)
            BodyEntry(date: _key(from.add(Duration(days: i))), weightKg: kg(i)),
        ];

    test('profile weight until a 7-day average exists, then the first average', () {
      final u = user();
      expect(targetsWeightFor(u, const [], start, p).kg, 95);
      final body = daily(start, 3, (_) => 94);
      final w = targetsWeightFor(u, body, start.add(const Duration(days: 3)), p);
      expect(w.kg, 94);
      expect(w.fromAverage, isTrue);
      expect(w.date, '2026-09-09');
    });

    test('small drifts do not move the targets, 4 kg does', () {
      final u = user();
      // Lose 0.1 kg a day from 95 kg.
      final body = daily(start, 60, (d) => 95 - d * 0.1);
      final at30 = targetsWeightFor(u, body, start.add(const Duration(days: 30)), p);
      expect(at30.kg, closeTo(94.9, 1e-6)); // first average (days 0-2) kept
      final at50 = targetsWeightFor(u, body, start.add(const Duration(days: 50)), p);
      expect(at50.kg, lessThanOrEqualTo(94.9 - 4 + 1e-6));
      expect(at50.date, isNot(at30.date));
    });

    test('8 weeks pass without 4 kg change: recalculated anyway', () {
      final u = user();
      final body = daily(start, 70, (d) => 95 - d * 0.02);
      final w = targetsWeightFor(u, body, start.add(const Duration(days: 69)), p);
      expect(w.date, _key(start.add(const Duration(days: 2 + 56))));
    });
  });

  group('stepsTargetFor', () {
    List<NutritionDay> hits(DateTime from, int days, {required bool Function(int d) hit}) => [
          for (var i = 0; i < days; i++) NutritionDay(date: _key(from.add(Duration(days: i))), stepsHit: hit(i)),
        ];

    test('+1,000 per 2-week block with >= 5 of the last 7 days hit, capped at 10,000', () {
      final days = hits(start, 200, hit: (_) => true);
      expect(stepsTargetFor(7000, days, start, start.add(const Duration(days: 13)), p), 7000);
      expect(stepsTargetFor(7000, days, start, start.add(const Duration(days: 14)), p), 8000);
      expect(stepsTargetFor(7000, days, start, start.add(const Duration(days: 28)), p), 9000);
      expect(stepsTargetFor(7000, days, start, start.add(const Duration(days: 150)), p), 10000);
    });

    test('blocks with fewer than 5 hit days do not increase', () {
      final days = hits(start, 28, hit: (d) => d % 7 < 4); // 4 of 7
      expect(stepsTargetFor(7000, days, start, start.add(const Duration(days: 28)), p), 7000);
    });

    test('a step count at or above the target counts as hit', () {
      final days = [
        for (var i = 7; i < 14; i++) NutritionDay(date: _key(start.add(Duration(days: i))), steps: 7200),
      ];
      expect(stepsTargetFor(7000, days, start, start.add(const Duration(days: 14)), p), 8000);
    });
  });

  group('meal filters', () {
    MealIdea meal(String id) => p.meals.firstWhere((m) => m.id == id);

    test('diet notes hide clashing meals', () {
      expect(mealFitsDiet(meal('kenkey_fish'), const []), isTrue);
      expect(mealFitsDiet(meal('kenkey_fish'), const ['fish_allergy']), isFalse);
      expect(mealFitsDiet(meal('oats_milk_eggs'), const ['lactose_intolerant']), isFalse);
      expect(mealFitsDiet(meal('yoghurt_groundnuts'), const ['groundnut_allergy']), isFalse);
      expect(mealFitsDiet(meal('jollof_chicken'), const ['vegetarian']), isFalse);
      expect(mealFitsDiet(meal('soya_chunks_stew'), const ['vegetarian', 'fish_allergy']), isTrue);
      final vegetarianLactoseFree = p.meals.where((m) => mealFitsDiet(m, const ['vegetarian', 'lactose_intolerant']));
      expect(vegetarianLactoseFree.map((m) => m.id), containsAll(['soya_chunks_stew', 'boiled_eggs']));
    });

    test('lunch_or_dinner shows under lunch and dinner', () {
      expect(mealMatchesType(meal('kenkey_fish'), 'lunch'), isTrue);
      expect(mealMatchesType(meal('kenkey_fish'), 'dinner'), isTrue);
      expect(mealMatchesType(meal('kenkey_fish'), 'breakfast'), isFalse);
      expect(mealMatchesType(meal('egg_bread'), null), isTrue);
    });
  });

  group('adjustedTargets and the good-day rule', () {
    final base = nutritionTargets(user(), p);

    test('sums check-in deltas, never below the floor', () {
      final t = adjustedTargets(base, const [
        CalorieAdjustment(id: 'a', date: '2026-10-01', ruleId: 'plateau', deltaKcal: -150),
        CalorieAdjustment(id: 'b', date: '2026-10-20', ruleId: 'slow_ok', deltaKcal: 0, deltaSteps: 1000),
      ], floorKcal: 1920);
      expect(t.calorieTargetKcal, 1950);
      expect(t.stepsTarget, 8000);
      final floored = adjustedTargets(base, const [
        CalorieAdjustment(id: 'a', date: '2026-10-01', ruleId: 'plateau', deltaKcal: -400),
      ], floorKcal: 1920);
      expect(floored.calorieTargetKcal, 1920);
    });

    test('good day: protein >= good-day points and 3 of the other 5', () {
      const day = NutritionDay(date: '2026-09-07', proteinPoints: 6, vegFruit: true, sleepOk: true);
      expect(isGoodNutritionDay(day, base, trainingDay: false), isFalse);
      expect(isGoodNutritionDay(day.copyWith(noSugaryDrinks: true), base, trainingDay: false), isTrue);
      expect(isGoodNutritionDay(day.copyWith(noSugaryDrinks: true, proteinPoints: 5.5), base, trainingDay: false), isFalse);
      // Water: 6.5 sachets on a rest day, 8 on a training day.
      final water = day.copyWith(waterSachets: 6.5);
      expect(checklistItemsMet(water, base, trainingDay: false), 3);
      expect(checklistItemsMet(water, base, trainingDay: true), 2);
    });
  });
}

String _key(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
