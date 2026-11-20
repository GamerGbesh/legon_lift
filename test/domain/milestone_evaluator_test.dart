import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/data/models/models.dart';
import 'package:legon_lift/domain/api.dart';

import '../fakes/test_catalog.dart';
import 'milestone_fixtures.dart';

void main() {
  final catalog = loadTestCatalog();
  final p = catalog.personalization;
  final start = DateTime(2026, 9, 6, 20); // Sunday evening
  final monday = DateTime(2026, 9, 7);
  final now = DateTime(2026, 12, 30, 12);
  final u = profileAt(start);
  final eq = EquipmentProfile.fromDefaults(p.gym);

  MilestoneInput input({
    List<Session> sessions = const [],
    List<BodyEntry> body = const [],
    List<NutritionDay> nutrition = const [],
    List<CardioLog> cardio = const [],
    List<Pause> pauses = const [],
    Map<String, ExerciseState> states = const {},
    List<PersonalRecord> newPrs = const [],
    UserProfile? profile,
    EquipmentProfile? equipment,
    DateTime? at,
  }) =>
      MilestoneInput(
        sessions: sessions,
        workingSets: [for (final s in sessions) ...s.allSets],
        body: body,
        nutrition: nutrition,
        cardio: cardio,
        pauses: pauses,
        states: states,
        newPrs: newPrs,
        profile: profile ?? u,
        eq: equipment ?? eq,
        catalog: catalog,
        now: at ?? now,
      );

  Set<String> earned(MilestoneInput i, {Set<String> already = const {}}) =>
      {for (final a in evaluateMilestones(i, p, already)) a.milestoneId};

  /// Three sessions a week (Mon/Wed/Fri 17:00) for [weeks] weeks from [from].
  List<Session> regular(int weeks, {DateTime? from, int hour = 17}) {
    final f = from ?? monday;
    return [
      for (var w = 0; w < weeks; w++)
        for (final d in [0, 2, 4]) session(DateTime(f.year, f.month, f.day + 7 * w + d, hour)),
    ];
  }

  test('every milestone in the data has a known rule', () {
    for (final m in p.milestones) {
      expect(isKnownMilestoneRule(m.rule), isTrue, reason: m.id);
    }
    expect(repeatableMilestoneIds(p), {'pr_any'});
    expect(lowEmphasisMilestoneIds(p), {'bmi_lt_30'});
  });

  test('nothing earned with no data', () {
    expect(earned(input()), isEmpty);
  });

  group('consistency', () {
    test('first session, first full week, session counts', () {
      final three = regular(1);
      expect(earned(input(sessions: three.take(1).toList())), contains('akwaaba'));
      final week1 = earned(input(sessions: three));
      expect(week1, containsAll(['akwaaba', 'first_full_week']));
      expect(week1, isNot(contains('sessions_10')));
      // Streaks are current: judged the Monday after the 4 weeks, and long after.
      expect(earned(input(sessions: regular(4), at: DateTime(2026, 10, 5, 9))), containsAll(['sessions_10', 'streak_4w']));
      expect(earned(input(sessions: regular(4))), isNot(contains('streak_4w')));
      expect(earned(input(sessions: regular(8))), isNot(contains('sessions_25'))); // 24 sessions
    });

    test('first full week needs the planned sessions within 7 days of the start', () {
      final late = sessionsOn(DateTime(2026, 9, 10), [0, 1, 5]); // Thu, Fri, next Tue
      expect(earned(input(sessions: late)), isNot(contains('first_full_week')));
    });

    test('already awarded milestones are skipped', () {
      final i = input(sessions: regular(1));
      expect(earned(i, already: {'akwaaba'}), isNot(contains('akwaaba')));
    });

    test('12-week streak', () {
      final after = DateTime(2026, 11, 30, 9);
      expect(earned(input(sessions: regular(12), at: after)), contains('streak_12w'));
      expect(earned(input(sessions: regular(11), at: after.subtract(const Duration(days: 7)))), isNot(contains('streak_12w')));
    });

    test('exam season survivor: every week of a finished 7+ day exams tag counted', () {
      const tag = Pause(id: 't', kind: Pause.kindTag, reason: 'exams', startDate: '2026-09-14', endDate: '2026-09-27');
      expect(earned(input(sessions: regular(4), pauses: [tag])), contains('exam_survivor'));
      final gap = [for (final s in regular(4)) if (s.startedAt.day != 21 && s.startedAt.day != 23) s];
      expect(earned(input(sessions: gap, pauses: [tag])), isNot(contains('exam_survivor')));
      const running = Pause(id: 't', kind: Pause.kindTag, reason: 'exams', startDate: '2026-09-14');
      expect(earned(input(sessions: regular(4), pauses: [running])), isNot(contains('exam_survivor')));
    });

    test('harmattan hero: 8 weeks with training in Dec-Feb within 12 months', () {
      final dec = regular(8, from: DateTime(2025, 12, 1));
      expect(earned(input(sessions: dec, at: DateTime(2026, 3, 1))), contains('harmattan_hero'));
      expect(earned(input(sessions: dec, at: DateTime(2027, 3, 1))), isNot(contains('harmattan_hero')));
      expect(earned(input(sessions: regular(7, from: DateTime(2025, 12, 1)), at: DateTime(2026, 3, 1))),
          isNot(contains('harmattan_hero')));
    });

    test('early bird: 5 sessions started before 08:00', () {
      final early = regular(2, hour: 7).take(5).toList();
      expect(earned(input(sessions: early)), contains('early_bird'));
      expect(earned(input(sessions: regular(2, hour: 8))), isNot(contains('early_bird')));
    });

    test('comeback: a session within 7 days after a missed week', () {
      final s = [...sessionsOn(monday, [0, 2]), ...sessionsOn(DateTime(2026, 9, 21), [1])];
      expect(earned(input(sessions: s)), contains('comeback'));
      const paused = Pause(id: 'x', kind: Pause.kindPause, reason: 'illness', startDate: '2026-09-14', endDate: '2026-09-20');
      expect(earned(input(sessions: s, pauses: [paused])), isNot(contains('comeback')));
      final tooLate = [...sessionsOn(monday, [0, 2]), ...sessionsOn(DateTime(2026, 9, 28), [1])];
      // Two missed weeks: the second one is followed within 7 days, so it still counts.
      expect(earned(input(sessions: tooLate)), contains('comeback'));
      expect(earned(input(sessions: regular(3))), isNot(contains('comeback')));
    });
  });

  group('strength', () {
    Session lift(String exerciseId, double kg, int reps, {DateTime? at}) {
      final t = at ?? DateTime(2026, 12, 20, 17);
      return session(t, sets: [setLog('s${t.millisecondsSinceEpoch}', exerciseId, kg, reps, at: t)]);
    }

    test('fixed loads with minimum reps (dumbbell total counts both hands)', () {
      expect(earned(input(sessions: [lift('smith_machine_bench_press', 60, 1)])), contains('first_plate_bench'));
      expect(earned(input(sessions: [lift('smith_machine_bench_press', 57.5, 3)])), isNot(contains('first_plate_bench')));
      // dumbbell_romanian_deadlift uses 2 dumbbells: 2 x 30 = 60 kg.
      expect(earned(input(sessions: [lift('dumbbell_romanian_deadlift', 30, 8)])), contains('rdl_60'));
      expect(earned(input(sessions: [lift('dumbbell_romanian_deadlift', 30, 7)])), isNot(contains('rdl_60')));
      expect(earned(input(sessions: [lift('one_arm_db_row', 26, 10)])), contains('db_row_25'));
    });

    test('warm-up and ramp sets never count', () {
      final t = DateTime(2026, 12, 20, 17);
      final s = session(t, sets: [setLog('w', 'smith_machine_bench_press', 60, 5, at: t, kind: SetKind.ramp)]);
      expect(earned(input(sessions: [s])), isNot(contains('first_plate_bench')));
    });

    test('body-weight multiples use the latest 7-day average, else the profile weight', () {
      // 95 kg profile: half is 47.5 kg.
      expect(earned(input(sessions: [lift('machine_chest_press', 47.5, 8)])), contains('chest_press_half_bw'));
      expect(earned(input(sessions: [lift('machine_chest_press', 45, 8)])), isNot(contains('chest_press_half_bw')));
      final lighter = [for (var d = 1; d <= 7; d++) BodyEntry(date: '2026-12-${(20 + d).toString()}', weightKg: 88)];
      expect(earned(input(sessions: [lift('machine_chest_press', 45, 8)], body: lighter)), contains('chest_press_half_bw'));
    });

    test('leg press counts the sled only when its weight is known', () {
      expect(earned(input(sessions: [lift('leg_press', 80, 5)])), isNot(contains('leg_press_bw')));
      final known = eq.copyWith(legPressSledKnown: true, legPressSledKg: 20);
      expect(earned(input(sessions: [lift('leg_press', 80, 5)], equipment: known)), contains('leg_press_bw'));
    });

    test('New PR: only an estimated-best-single record beating an earlier best; repeatable', () {
      final first = lift('machine_chest_press', 40, 10, at: DateTime(2026, 12, 1, 17));
      final second = lift('machine_chest_press', 45, 10, at: DateTime(2026, 12, 8, 17));
      final pr = PersonalRecord(
        exerciseId: 'machine_chest_press',
        type: PrType.e1rm,
        value: epley1rm(45, 10),
        setLogId: second.allSets.single.id,
        achievedAt: second.startedAt,
      );
      expect(earned(input(sessions: [first, second], newPrs: [pr]), already: {'pr_any'}), contains('pr_any'));
      final baseline = PersonalRecord(
        exerciseId: 'machine_chest_press',
        type: PrType.e1rm,
        value: epley1rm(40, 10),
        setLogId: first.allSets.single.id,
        achievedAt: first.startedAt,
      );
      expect(earned(input(sessions: [first], newPrs: [baseline])), isNot(contains('pr_any')));
      final volume = PersonalRecord(
        exerciseId: 'machine_chest_press',
        type: PrType.bestVolume,
        value: 1,
        setLogId: second.allSets.single.id,
        achievedAt: second.startedAt,
      );
      expect(earned(input(sessions: [first, second], newPrs: [volume])), isNot(contains('pr_any')));
    });

    test('anchor lifts: mean increase over 3+ anchors, best of the last 14 days vs first', () {
      final early = DateTime(2026, 9, 7, 17), recent = DateTime(2026, 12, 25, 17);
      List<Session> pair(String id, double firstKg, double nowKg) => [
            lift(id, firstKg, 10, at: early),
            lift(id, nowKg, 10, at: recent),
          ];
      final two = [...pair('leg_press', 100, 130), ...pair('machine_chest_press', 40, 52)];
      expect(earned(input(sessions: two)), isNot(contains('strength_25')));
      final three = [...two, ...pair('lat_pulldown_wide', 40, 50)];
      final got = earned(input(sessions: three));
      expect(got, contains('strength_25'));
      expect(got, isNot(contains('strength_50')));
      final stale = [...two, lift('lat_pulldown_wide', 40, 10, at: early), lift('lat_pulldown_wide', 50, 10, at: DateTime(2026, 12, 1, 17))];
      expect(earned(input(sessions: stale)), isNot(contains('strength_25')));
    });
  });

  group('body', () {
    List<BodyEntry> week(DateTime from, double kg, {double? waist}) => [
          for (var d = 0; d < 7; d++)
            BodyEntry(date: dateKey(from.add(Duration(days: d))), weightKg: kg, waistCm: d == 0 ? waist : null),
        ];

    test('7-day average loss in kg and %', () {
      final body = [...week(DateTime(2026, 9, 7), 95), ...week(DateTime(2026, 12, 1), 89.9)];
      final got = earned(input(body: body));
      expect(got, containsAll(['minus_2_5kg', 'minus_5kg', 'minus_5pct']));
      expect(got, isNot(contains('minus_10kg')));
    });

    test('waist milestones', () {
      final body = [...week(DateTime(2026, 9, 7), 95, waist: 104), ...week(DateTime(2026, 12, 1), 94, waist: 98)];
      final got = earned(input(body: body));
      expect(got, containsAll(['waist_minus_5', 'waist_lt_102']));
      expect(got, isNot(contains('waist_lt_94')));
      expect(got, isNot(contains('whtr_lt_0_5')));
      // Started under 102: "Under 102" does not apply.
      final small = [...week(DateTime(2026, 9, 7), 95, waist: 100), ...week(DateTime(2026, 12, 1), 94, waist: 85)];
      final s = earned(input(body: small));
      expect(s, isNot(contains('waist_lt_102')));
      expect(s, contains('whtr_lt_0_5')); // 85 / 172 = 0.49
      // The onboarding waist counts as the first reading.
      final viaProfile = earned(input(body: week(DateTime(2026, 12, 1), 94, waist: 98), profile: u.copyWith(startWaistCm: () => 104)));
      expect(viaProfile, contains('waist_minus_5'));
    });

    test('BMI under 30 from a start of 30+', () {
      final body = [...week(DateTime(2026, 9, 7), 95), ...week(DateTime(2026, 12, 1), 88)];
      expect(earned(input(body: body)), contains('bmi_lt_30')); // 88 / 1.72^2 = 29.7
      expect(earned(input(body: week(DateTime(2026, 9, 7), 95))), isNot(contains('bmi_lt_30')));
    });

    test('recomp detective: weight flat, waist down 2+ cm over 4 weeks', () {
      final body = [
        ...week(DateTime(2026, 11, 23), 94, waist: 100),
        ...week(DateTime(2026, 12, 21), 93.5, waist: 97.5),
      ];
      expect(earned(input(body: body)), contains('recomp_detective'));
      final dropped = [
        ...week(DateTime(2026, 11, 23), 94, waist: 100),
        ...week(DateTime(2026, 12, 21), 92, waist: 97.5),
      ];
      expect(earned(input(body: dropped)), isNot(contains('recomp_detective')));
    });
  });

  group('habits', () {
    List<NutritionDay> days(DateTime from, int n, NutritionDay Function(String date) make) =>
        [for (var d = 0; d < n; d++) make(dateKey(from.add(Duration(days: d))))];

    test('protein 5 of 7 days in a Mon-Sun week; 4 weeks in a row', () {
      final five = days(monday, 5, (d) => NutritionDay(date: d, proteinPoints: 7));
      expect(earned(input(nutrition: five)), contains('protein_pro'));
      final four = days(monday, 4, (d) => NutritionDay(date: d, proteinPoints: 7));
      expect(earned(input(nutrition: four)), isNot(contains('protein_pro')));
      final month = [
        for (var w = 0; w < 4; w++) ...days(monday.add(Duration(days: 7 * w)), 5, (d) => NutritionDay(date: d, proteinPoints: 7)),
      ];
      expect(earned(input(nutrition: month)), contains('protein_pro_month'));
      final broken = [for (final d in month) if (!d.date.startsWith('2026-09-2')) d];
      expect(earned(input(nutrition: broken)), isNot(contains('protein_pro_month')));
    });

    test('water 7 of 7 days: training days need the training target', () {
      final rest = days(monday, 7, (d) => NutritionDay(date: d, waterSachets: 6.5));
      expect(earned(input(nutrition: rest)), contains('hydrated_heat'));
      final trained = sessionsOn(monday, [0]);
      expect(earned(input(nutrition: rest, sessions: trained)), isNot(contains('hydrated_heat')));
    });

    test('steps: a week with 5+ entries averaging the goal; sleep 6 good nights', () {
      final steps = days(monday, 5, (d) => NutritionDay(date: d, steps: 8200));
      final got = earned(input(nutrition: steps));
      expect(got, contains('stepper_8k'));
      expect(got, isNot(contains('stepper_10k')));
      final sleep = days(monday, 6, (d) => NutritionDay(date: d, sleepOk: true));
      expect(earned(input(nutrition: sleep)), contains('sleep_champion'));
      expect(earned(input(nutrition: sleep.take(5).toList())), isNot(contains('sleep_champion')));
    });

    test('continuous cardio from a finisher set or a cardio log', () {
      final t = DateTime(2026, 12, 20, 17);
      final finisher = session(t, sets: [setLog('f', 'bike_steady_state', 0, 0, at: t, durationSec: 20 * 60)], blockType: BlockType.finisher);
      final got = earned(input(sessions: [finisher]));
      expect(got, contains('cardio_20'));
      expect(got, isNot(contains('cardio_30')));
      const log = CardioLog(id: 'c', date: '2026-12-21', exerciseId: 'treadmill_incline_walk', durationSec: 31 * 60);
      expect(earned(input(cardio: [log])), contains('cardio_30'));
    });
  });

  group('progress', () {
    test('counts and loads have a fraction and a plain label', () {
      final i = input(sessions: regular(1));
      final pr = milestoneProgress(i, p);
      expect(pr['sessions_10']!.fraction, closeTo(0.3, 1e-9));
      expect(pr['sessions_10']!.label, '3 of 10 sessions');
      expect(pr['first_plate_bench']!.label, 'Best: 0 of 60 kg');
      expect(pr['stepper_10k']!.label, '0 of 10,000 steps a day');
      expect(pr.containsKey('comeback'), isFalse);
    });

    test('rules that cannot apply are left out', () {
      const body = [BodyEntry(date: '2026-09-07', waistCm: 90)];
      final pr = milestoneProgress(input(body: body), p);
      expect(pr.containsKey('waist_lt_102'), isFalse);
      expect(pr.containsKey('waist_lt_94'), isFalse);
      expect(pr['whtr_lt_0_5']!.label, startsWith('Now 0.52'));
    });
  });
}
