import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/data/models/models.dart';
import 'package:legon_lift/domain/api.dart';

import '../fakes/test_catalog.dart';
import 'milestone_fixtures.dart';

void main() {
  final p = loadTestCatalog().personalization;
  final start = DateTime(2026, 9, 7, 8); // Monday; week n = days [7(n-1), 7n)
  final u = profileAt(start);
  DateTime weekStart(int n) => DateTime(start.year, start.month, start.day + 7 * (n - 1), 7);

  /// Daily weigh-ins: [kgByWeek][i] for week i + 1.
  List<BodyEntry> body(List<double> kgByWeek, {Map<int, double> waistByWeek = const {}}) => [
        for (final (i, kg) in kgByWeek.indexed)
          for (var d = 0; d < 7; d++)
            BodyEntry(
              date: dateKey(weekStart(i + 1).add(Duration(days: d))),
              weightKg: kg,
              waistCm: d == 6 ? waistByWeek[i + 1] : null,
            ),
      ];

  CheckinAdvice advise(
    List<double> kgByWeek, {
    Map<int, double> waist = const {},
    List<NutritionDay> nutrition = const [],
    List<CalorieAdjustment> adjustments = const [],
    Map<String, ExerciseState> anchors = const {},
    UserProfile? profile,
    int? weeksDone,
  }) =>
      weeklyCheckin(CheckinInput(
        body: body(kgByWeek, waistByWeek: waist),
        nutrition: nutrition,
        adjustments: adjustments,
        anchorStates: anchors,
        profile: profile ?? u,
        p: p,
        now: weekStart((weeksDone ?? kgByWeek.length) + 1).add(const Duration(hours: 10)),
      ));

  test('weeks 1-2 never change anything', () {
    final a = advise([95, 93]);
    expect(a.ruleId, CheckinRuleIds.notEnoughData);
    expect(a.canApply, isFalse);
  });

  test('weeks with fewer than 3 weigh-ins are not usable', () {
    final a = weeklyCheckin(CheckinInput(
      body: [
        for (var w = 1; w <= 4; w++) BodyEntry(date: dateKey(weekStart(w)), weightKg: 95.0 - w),
      ],
      nutrition: const [],
      adjustments: const [],
      anchorStates: const {},
      profile: u,
      p: p,
      now: weekStart(5),
    ));
    expect(a.ruleId, CheckinRuleIds.notEnoughData);
  });

  test('on track for 2 weeks: no action', () {
    final a = advise([96, 94, 93.3, 92.6]);
    expect(a.ruleId, 'on_track');
    expect(a.canApply, isFalse);
    expect(a.deltaKcal, 0);
    expect(a.message, startsWith('On track'));
  });

  test('a single on-track week is not enough (consecutive 2)', () {
    final a = advise([96, 94, 94, 93.3]);
    expect(a.ruleId, CheckinRuleIds.keepGoing);
  });

  test('too fast after week 3: +150 kcal', () {
    // Week 3's rate alone is not judged as too fast (needs weeks 4 and 5).
    expect(advise([96, 94, 92.8, 91.6]).ruleId, isNot('too_fast'));
    final a = advise([96, 94, 92.8, 91.6, 90.4]);
    expect(a.ruleId, 'too_fast');
    expect(a.deltaKcal, 150);
    expect(a.canApply, isTrue);
  });

  test('latestWeeklyChange reports the averaged change', () {
    final c = latestWeeklyChange(CheckinInput(
      body: body([96, 94, 93.3, 92.6]),
      nutrition: const [],
      adjustments: const [],
      anchorStates: const {},
      profile: u,
      p: p,
      now: weekStart(5),
    ))!;
    expect(c.week, 4);
    expect(c.kg, closeTo(0.7, 1e-9));
    expect(c.lossPct, closeTo(0.747, 0.001));
  });

  test('slow but steady with a flat waist: +1,000 steps', () {
    final a = advise([96, 94, 93.65, 93.3], waist: {2: 100, 3: 100, 4: 100});
    expect(a.ruleId, 'slow_ok');
    expect(a.deltaSteps, 1000);
    expect(a.deltaKcal, 0);
    expect(a.canApply, isTrue);
    final shrinking = advise([96, 94, 93.65, 93.3], waist: {2: 101, 3: 100, 4: 99});
    expect(shrinking.ruleId, 'slow_ok');
    expect(shrinking.canApply, isFalse);
  });

  test('plateau needs 3 weeks, then trims 150 kcal', () {
    expect(advise([96, 94, 94, 94]).ruleId, isNot('plateau'));
    final a = advise([96, 94, 94, 94, 94]);
    expect(a.ruleId, 'plateau');
    expect(a.deltaKcal, -150);
    expect(a.canApply, isTrue);
  });

  test('plateau with weak protein: fix adherence first, nothing to apply', () {
    final now = weekStart(6);
    final nutrition = [
      for (var d = 1; d <= 7; d++)
        NutritionDay(date: dateKey(now.subtract(Duration(days: d))), proteinPoints: 3, noSugaryDrinks: true),
    ];
    final a = advise([96, 94, 94, 94, 94], nutrition: nutrition);
    expect(a.ruleId, 'plateau');
    expect(a.canApply, isFalse);
    expect(a.message, contains('protein on 0'));
  });

  test('recomp: weight flat, waist down, strength up', () {
    final anchors = {
      for (final id in ['leg_press', 'machine_chest_press', 'lat_pulldown_wide'])
        id: ExerciseState(exerciseId: id, firstE1rm: 50, bestE1rm: 65, updatedAt: start),
    };
    final a = advise([96, 94, 94, 94], waist: {2: 102, 3: 101, 4: 100}, anchors: anchors);
    expect(a.ruleId, 'recomp');
    expect(a.canApply, isFalse);
  });

  test('gaining: -150 kcal', () {
    final a = advise([96, 94, 94.6, 95.2], waist: {2: 100, 3: 99, 4: 98});
    expect(a.ruleId, 'gaining');
    expect(a.deltaKcal, -150);
  });

  test('guards: no second change within 2 weeks', () {
    final a = advise([96, 94, 92.8, 91.6, 90.4], adjustments: [
      CalorieAdjustment(id: 'a', date: dateKey(weekStart(5)), ruleId: 'too_fast', deltaKcal: 150),
    ]);
    expect(a.ruleId, 'too_fast');
    expect(a.deltaKcal, 150);
    expect(a.canApply, isFalse);
    expect(a.message, contains('wait'));
  });

  test('guards: never below the calorie floor', () {
    // Targets use the first 7-day average (96 kg): 2,100 kcal, floor 1,930 (BMR). After a
    // -150 cut only 20 kcal of room is left; at the floor the plateau adds steps instead.
    final a = advise([96, 94, 94, 94, 94], adjustments: [
      CalorieAdjustment(id: 'a', date: dateKey(weekStart(1)), ruleId: 'plateau', deltaKcal: -150),
    ]);
    expect(a.ruleId, 'plateau');
    expect(a.deltaKcal, -20);
    final floored = advise([96, 94, 94, 94, 94], adjustments: [
      CalorieAdjustment(id: 'a', date: dateKey(weekStart(1)), ruleId: 'plateau', deltaKcal: -180),
    ]);
    expect(floored.deltaKcal, 0);
    expect(floored.deltaSteps, 2000);
    expect(floored.canApply, isTrue);
  });

  test('not for muscle gain or maintain', () {
    final a = advise([96, 94, 93, 92], profile: u.copyWith(goal: Goal.muscleGain));
    expect(a.ruleId, CheckinRuleIds.notForGoal);
  });

  test('checkinDue: first workout weekday from week 3', () {
    expect(checkinDue(u, weekStart(3)), isTrue); // Monday of week 3
    expect(checkinDue(u, weekStart(2)), isFalse);
    expect(checkinDue(u, weekStart(3).add(const Duration(days: 2))), isFalse);
    expect(checkinDue(u.copyWith(workoutWeekdays: [2, 4, 6]), weekStart(3).add(const Duration(days: 1))), isTrue);
  });
}
