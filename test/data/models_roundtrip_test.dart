import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/data/models/models.dart';
import 'package:legon_lift/domain/api.dart';

import '../fakes/fakes.dart';

void main() {
  final t0 = DateTime.fromMillisecondsSinceEpoch(DateTime(2026, 11, 9, 17, 3, 21).millisecondsSinceEpoch);

  group('enums', () {
    void roundTrip<E extends Enum>(List<E> values, String Function(E) wire, E Function(String) fromWire) {
      for (final v in values) {
        expect(fromWire(wire(v)), v);
      }
      expect(() => fromWire('not_a_value'), throwsFormatException);
    }

    test('every enum round-trips its wire value and rejects unknown values', () {
      roundTrip(ExerciseCategory.values, (v) => v.wire, ExerciseCategory.fromWire);
      roundTrip(Muscle.values, (v) => v.wire, Muscle.fromWire);
      roundTrip(Equipment.values, (v) => v.wire, Equipment.fromWire);
      roundTrip(Mechanic.values, (v) => v.wire, Mechanic.fromWire);
      roundTrip(LoadType.values, (v) => v.wire, LoadType.fromWire);
      roundTrip(MovementPattern.values, (v) => v.wire, MovementPattern.fromWire);
      roundTrip(Tracking.values, (v) => v.wire, Tracking.fromWire);
      roundTrip(BlockType.values, (v) => v.wire, BlockType.fromWire);
      roundTrip(ItemRole.values, (v) => v.wire, ItemRole.fromWire);
      roundTrip(PhaseId.values, (v) => v.wire, PhaseId.fromWire);
      roundTrip(SetKind.values, (v) => v.wire, SetKind.fromWire);
      roundTrip(SessionStatus.values, (v) => v.wire, SessionStatus.fromWire);
      roundTrip(SessionExerciseStatus.values, (v) => v.wire, SessionExerciseStatus.fromWire);
      roundTrip(SkipReason.values, (v) => v.wire, SkipReason.fromWire);
      roundTrip(Trend.values, (v) => v.wire, Trend.fromWire);
      roundTrip(Sex.values, (v) => v.wire, Sex.fromWire);
      roundTrip(Goal.values, (v) => v.wire, Goal.fromWire);
      roundTrip(Experience.values, (v) => v.wire, Experience.fromWire);
      roundTrip(ActivityLevel.values, (v) => v.wire, ActivityLevel.fromWire);
      roundTrip(SplitKey.values, (v) => v.wire, SplitKey.fromWire);
      roundTrip(LegCurlType.values, (v) => v.wire, LegCurlType.fromWire);
      roundTrip(RirPrompt.values, (v) => v.wire, RirPrompt.fromWire);
      roundTrip(ThemeModePref.values, (v) => v.wire, ThemeModePref.fromWire);
      roundTrip(PaletteId.values, (v) => v.wire, PaletteId.fromWire);
      roundTrip(PrType.values, (v) => v.wire, PrType.fromWire);
    });

    test('wire strings match the data files', () {
      expect(Muscle.frontDelts.wire, 'front_delts');
      expect(LoadType.plateLoaded.wire, 'plate_loaded');
      expect(SessionStatus.inProgress.wire, 'in_progress');
      expect(SkipReason.noTime.wire, 'no_time');
      expect(Experience.m3to12.wire, '3_to_12_months');
      expect(SplitKey.chestbackLegsArmsshoulders.wire, 'chestback_legs_armsshoulders');
      expect(PaletteId.legonNight.wire, 'legon_night');
      expect(PrType.maxWeight.wire, 'max_weight');
    });
  });

  group('JSON round trips', () {
    final catalog = loadTestCatalog();

    test('every exercise and template survives toJson/fromJson', () {
      for (final e in catalog.exercises) {
        expect(Exercise.fromJson(e.toJson()), e, reason: e.id);
      }
      for (final t in catalog.templates) {
        expect(ProgramTemplate.fromJson(t.toJson()), t, reason: t.programId);
      }
    });

    test('profile and settings (kv JSON)', () {
      final profile = UserProfile.defaults(t0).copyWith(
        name: () => 'Kofi',
        goalWeightKg: () => 85,
        limitations: ['knee'],
        ghanaAnswers: {'gh_sickle': 'no'},
        emergencyPhone: () => '0240000000',
        useLb: true,
      );
      expect(UserProfile.fromJson(profile.toJson()), profile);
      expect(UserProfile.fromJson(UserProfile.defaults(t0).toJson()), UserProfile.defaults(t0));

      final settings = AppSettings.defaults(catalog.personalization.gym).copyWith(
        rirPrompt: RirPrompt.last,
        palette: PaletteId.voltTeal,
        reminderTime: () => '16:30',
        equipment: AppSettings.defaults(catalog.personalization.gym)
            .equipment
            .copyWith(smithBarKg: 15, smithBarKnown: true, legCurlType: LegCurlType.lying, hasBenchUprights: true),
      );
      expect(AppSettings.fromJson(settings.toJson()), settings);
      expect(settings.copyWith(reminderTime: () => null).reminderTime, isNull);
    });

    test('default equipment comes from personalization.gym', () {
      final eq = EquipmentProfile.fromDefaults(catalog.personalization.gym);
      expect(eq.has(Equipment.smithMachine), isTrue);
      expect(eq.has(Equipment.ankleStrap), isFalse);
      expect(eq.smithBarKg, 10);
      expect(eq.smithBarKnown, isFalse);
      expect(eq.dumbbellsKg.first, 2);
      expect(eq.dumbbellsKg.last, 40);
      expect(eq.dumbbellsKg, hasLength(20));
      expect(catalog.personalization.gym, GymProfileDefaults.legon.copyWith(
        equipmentLabels: catalog.personalization.gym.equipmentLabels,
        equipmentNotes: catalog.personalization.gym.equipmentNotes,
      ));
    });

    test('session plan with every step type', () {
      final plan = SampleData.plan(catalog, 'legs');
      final ex = plan.exerciseSteps.first;
      final full = plan.copyWith(steps: [
        ...plan.steps,
        ExtrasStep(index: plan.steps.length, extras: [ex.withIndex(plan.steps.length)]),
        FinisherStep(index: plan.steps.length + 1, item: ex.item, durationSec: 480),
      ]);
      expect({for (final s in full.steps) s.runtimeType}, containsAll([
        WarmupCardioStep, MobilityStep, ExerciseStep, ExtrasStep, FinisherStep, CooldownStep,
      ]));
      expect(SessionPlan.fromJson(full.toJson()), full);
      final ppl = SampleData.plan(catalog, 'push');
      expect(SessionPlan.fromJson(ppl.toJson()), ppl);
    });

    test('superset plans (Arms + Shoulders day) round-trip', () {
      final t = catalog.template('chest_back_legs_arms_3day');
      final day = t.phases.first.days.firstWhere((d) => d.blocks.any((b) => b.blockType == BlockType.superset));
      final members = [
        for (final item in day.blocks.firstWhere((b) => b.blockType == BlockType.superset).items)
          ExerciseStep(
            index: 0,
            item: item,
            slotKey: item.slotKey(),
            rx: Prescription(exerciseId: item.exerciseId, working: const [], restSec: 60),
          ),
      ];
      final step = SupersetStep(index: 0, group: 'A', members: members, roundRestSec: 60);
      expect(SessionStep.fromJson(step.toJson()), step);
    });

    test('cursor with find-weight state and rest deadline', () {
      final cursor = PlayerCursor(
        stepIndex: 3,
        setIndex: 1,
        restEndsAt: t0,
        findWeight: const FindWeightState(currentKg: 25, previousKg: 20, step: 2, targetReps: 10, targetRir: 3),
        visitedSteps: const [0, 1, 2, 3],
      );
      expect(PlayerCursor.fromJson(cursor.toJson()), cursor);
      expect(cursor.copyWith(restEndsAt: () => null, findWeight: () => null).restEndsAt, isNull);
    });

    test('a full sample session (JSON and SQLite rows)', () {
      final sessions = SampleData.sessions(catalog);
      for (final s in sessions) {
        expect(Session.fromJson(s.toJson()), s);
        final rowExercises = [
          for (final e in s.exercises)
            SessionExercise.fromMap(e.toMap(), sets: [for (final x in e.sets) SetLog.fromMap(x.toMap())]),
        ];
        expect(Session.fromMap(s.toMap(), exercises: rowExercises), s);
      }
      final withCursor = sessions.first.copyWith(
        status: SessionStatus.inProgress,
        endedAt: () => null,
        cursor: () => const PlayerCursor(stepIndex: 2),
      );
      expect(Session.fromMap(withCursor.toMap(), exercises: withCursor.exercises), withCursor);
    });
  });

  group('SQLite row round trips', () {
    final catalog = loadTestCatalog();

    test('programs and overrides', () {
      final p = SampleData.program(catalog).copyWith(nextDayIndex: 2, reactiveDeloadRemaining: 3);
      expect(ActiveProgram.fromMap(p.toMap()), p);
      expect(ActiveProgram.fromJson(p.toJson()), p);
      final custom = p.copyWith(
        templateId: () => null,
        customTemplate: () => catalog.template('ppl_3day').copyWith(programId: 'custom-1', totalWeeks: () => null),
      );
      expect(ActiveProgram.fromMap(custom.toMap()), custom);

      const o = ProgramOverride(
          programId: 'p', dayId: 'push', slotKey: 'primary:machine_chest_press', exerciseId: 'dumbbell_bench_press');
      expect(ProgramOverride.fromMap(o.toMap()), o);
      expect(ProgramOverride.fromJson(o.toJson()), o);
      const toggle = ProgramOverride(
          programId: 'p', dayId: 'legs', slotKey: 'accessory:machine_calf_raise', exerciseId: 'machine_calf_raise', optionalEnabled: false);
      expect(ProgramOverride.fromMap(toggle.toMap()), toggle);
      expect(ProgramOverride.fromMap({...toggle.toMap(), 'exercise_id': null}).exerciseId, 'machine_calf_raise');
    });

    test('exercise state, records and prefs', () {
      final s = ExerciseState(
        exerciseId: 'machine_chest_press',
        workingKg: 30,
        repTargets: const [11, 10, 10],
        stallCount: 1,
        resetCount: 0,
        lastTrend: Trend.up,
        lastReason: 'You hit 12, 12, 12 last time: +5 kg',
        lastSessionId: 's1',
        lastRepRange: (8, 12),
        firstE1rm: 36,
        bestE1rm: 40,
        lastJumpPct: 0.2,
        updatedAt: t0,
      );
      expect(ExerciseState.fromMap(s.toMap()), s);
      expect(ExerciseState.fromJson(s.toJson()), s);
      final fresh = ExerciseState(exerciseId: 'x', updatedAt: t0);
      expect(ExerciseState.fromMap(fresh.toMap()), fresh);

      final r = PersonalRecord(exerciseId: 'x', type: PrType.bestVolume, value: 900, setLogId: 'set1', achievedAt: t0);
      expect(PersonalRecord.fromMap(r.toMap()), r);
      expect(PersonalRecord.fromJson(r.toJson()), r);

      final prefs = const ExercisePrefs.empty('x').copyWith(favorite: true, machineNote: () => 'seat 4', lastPainAt: () => t0);
      expect(ExercisePrefs.fromMap(prefs.toMap()), prefs);
      expect(ExercisePrefs.fromJson(prefs.toJson()), prefs);
    });

    test('body, nutrition, cardio, milestones, pauses, adjustments', () {
      const body = BodyEntry(date: '2026-11-09', weightKg: 95.2, waistCm: 104, note: 'after toilet');
      expect(BodyEntry.fromMap(body.toMap()), body);
      expect(BodyEntry.fromJson(body.toJson()), body);

      const day = NutritionDay(date: '2026-11-09', proteinPoints: 6.5, waterSachets: 7, sleepOk: true, steps: 8200);
      expect(NutritionDay.fromMap(day.toMap()), day);
      expect(NutritionDay.fromJson(day.toJson()), day);

      const cardio = CardioLog(id: 'c1', date: '2026-11-10', exerciseId: 'treadmill_brisk_walk', durationSec: 1800);
      expect(CardioLog.fromMap(cardio.toMap()), cardio);
      expect(CardioLog.fromJson(cardio.toJson()), cardio);

      final award = MilestoneAward(milestoneId: 'akwaaba', awardedAt: t0, context: const {'sessionId': 's1'});
      expect(MilestoneAward.fromMap(award.toMap()), award);
      expect(MilestoneAward.fromJson(award.toJson()), award);

      const pause = Pause(id: 'p1', kind: Pause.kindPause, reason: 'exams', startDate: '2026-12-01');
      expect(Pause.fromMap(pause.toMap()), pause);
      expect(Pause.fromJson(pause.toJson()), pause);

      const adj = CalorieAdjustment(id: 'a1', date: '2026-12-07', ruleId: 'too_slow', deltaKcal: -100, deltaSteps: 1000);
      expect(CalorieAdjustment.fromMap(adj.toMap()), adj);
      expect(CalorieAdjustment.fromJson(adj.toJson()), adj);
    });
  });

  group('derived getters', () {
    final catalog = loadTestCatalog();

    test('exercise unlock keys and bar math', () {
      final smith = catalog.exercises.firstWhere((e) => e.loadType == LoadType.smith);
      expect(smith.unlockKey, 'smith_machine');
      expect(smith.needsBarMath, isTrue);
      final machine = catalog.exercise('machine_chest_press');
      expect(machine.unlockKey, 'always');
      expect(machine.isLoaded, isTrue);
    });

    test('slot keys and warm-up set counts', () {
      final push = catalog.template('ppl_3day').phases.first.day('push')!;
      final primary = push.items.firstWhere((i) => i.role == ItemRole.primary);
      expect(primary.slotKey(), 'primary:machine_chest_press');
      expect(primary.warmupAuto, isTrue);
      expect(primary.warmupSetCount, 2);
    });

    test('program selection table', () {
      final p = catalog.personalization;
      expect(p.programIdFor(SplitKey.pushPullLegs, 3), 'ppl_3day');
      expect(p.programIdFor(SplitKey.pushPullLegs, 2), 'upper_lower_2day');
      expect(p.programIdFor(SplitKey.upperLower, 4), 'upper_lower_4day');
      expect(p.programIdFor(SplitKey.custom, 3), 'ppl_3day');
    });
  });
}
