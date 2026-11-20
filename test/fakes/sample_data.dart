import 'package:legon_lift/data/assets/asset_catalog.dart';
import 'package:legon_lift/data/models/models.dart';
import 'package:legon_lift/domain/api.dart';

import 'fake_app.dart';

/// A scripted, deterministic 3-session history for widget tests (SPEC 13 Phase 0 item 9):
/// the default user on `ppl_3day`, week 1 (Foundation) Push on Mon 9 Nov 2026, Pull on Wed 11,
/// Legs on Fri 13, each completed at 18:00 after starting at 17:00. Primary lifts did the
/// "find your weight" ramp (2 ramp sets, then sets - 1 working sets); everything else did its
/// working sets at the exercise's beginner starting weight. The rotation points at Push again.
/// Seven daily weigh-ins (95.0 -> 94.4 kg) and two nutrition days are included.
///
/// Use with the default `FakeClock()` (Mon 16 Nov 2026, 17:00).
abstract final class SampleData {
  static const String programId = 'sample-program';
  static const String templateId = 'ppl_3day';
  static const List<String> sessionIds = ['sample-push', 'sample-pull', 'sample-legs'];

  static final DateTime createdAt = DateTime(2026, 11, 8, 20);
  static final List<DateTime> sessionStarts = [
    DateTime(2026, 11, 9, 17),
    DateTime(2026, 11, 11, 17),
    DateTime(2026, 11, 13, 17),
  ];

  static UserProfile profile() => UserProfile.defaults(createdAt).copyWith(name: () => 'Kofi');

  static AppSettings settings() => AppSettings.defaults(GymProfileDefaults.legon).copyWith(reminderTime: () => '16:00');

  static ActiveProgram program(AssetCatalog catalog) {
    final t = catalog.template(templateId);
    return ActiveProgram(
      id: programId,
      templateId: templateId,
      name: t.name,
      dayOrder: List.of(t.dayOrder),
      nextDayIndex: 0,
      startedAt: createdAt,
    );
  }

  /// The plan the player would have run (week 1: no finisher, optional items left out).
  static SessionPlan plan(AssetCatalog catalog, String dayId) {
    final t = catalog.template(templateId);
    final phase = t.phases.first;
    final day = phase.day(dayId)!;
    final steps = <SessionStep>[];
    ExerciseStep exStep(int index, ProgramItem item) {
      final ex = catalog.exercise(item.exerciseId);
      final w = startKg(ex);
      final reps = item.repRange?.$1 ?? 0;
      return ExerciseStep(
        index: index,
        item: item,
        slotKey: item.slotKey(),
        rx: Prescription(
          exerciseId: ex.id,
          working: [
            for (var i = 0; i < item.sets; i++)
              PlannedSet(
                kind: SetKind.working,
                weightKg: ex.isLoaded ? w : 0,
                reps: ex.tracking == Tracking.time ? 0 : reps,
                durationSec: item.durationSeconds,
                targetRir: item.rir,
              ),
          ],
          restSec: item.restSeconds,
          targetRir: item.rir,
          trend: Trend.calibrate,
          reason: "First time: we'll find your weight",
          findWeight: ex.isLoaded && item.role == ItemRole.primary,
          incrementKg: item.weightIncrementKg ?? ex.weightIncrementKg ?? 2.5,
        ),
      );
    }

    for (final block in day.blocks) {
      final items = block.items.where((i) => !i.optional).toList();
      if (items.isEmpty) continue;
      switch (block.blockType) {
        case BlockType.warmup:
          steps.add(WarmupCardioStep(index: steps.length, item: items.first));
          if (items.length > 1) steps.add(MobilityStep(index: steps.length, items: items.sublist(1)));
        case BlockType.main:
          for (final item in items) {
            steps.add(exStep(steps.length, item));
          }
        case BlockType.superset:
          final index = steps.length;
          steps.add(SupersetStep(
            index: index,
            group: block.supersetGroup ?? 'A',
            members: [for (final item in items) exStep(index, item)],
            roundRestSec: block.restBetweenRoundsSeconds ?? 60,
          ));
        case BlockType.finisher:
          break;
        case BlockType.cooldown:
          steps.add(CooldownStep(index: steps.length, items: items));
      }
    }
    return SessionPlan(
      programId: programId,
      templateId: templateId,
      phaseId: phase.phaseId,
      trainingWeek: 1,
      dayId: day.dayId,
      dayName: day.name,
      estimatedMinutes: day.estimatedMinutes.core,
      steps: steps,
      notices: const ["This week's sessions take ~5 min longer while we find your weights."],
    );
  }

  /// The beginner start weight used throughout the sample (per dumbbell / total bar / pin).
  static double startKg(Exercise ex) => ex.isLoaded ? (ex.startingWeightKg?.low ?? 10) : 0;

  /// The three completed sessions, oldest first.
  static List<Session> sessions(AssetCatalog catalog) => [
        for (final (i, dayId) in catalog.template(templateId).dayOrder.indexed) _session(catalog, i, dayId),
      ];

  static Session _session(AssetCatalog catalog, int n, String dayId) {
    final id = sessionIds[n];
    final start = sessionStarts[n];
    final p = plan(catalog, dayId);
    var clock = start.add(const Duration(minutes: 8));
    DateTime tick() => clock = clock.add(const Duration(minutes: 2));

    final exercises = <SessionExercise>[];
    for (final step in p.exerciseSteps) {
      final item = step.item;
      final ex = catalog.exercise(item.exerciseId);
      final seId = '$id-e${exercises.length}';
      final sets = <SetLog>[];
      SetLog set(SetKind kind, int index, double kg, int reps, {int? rir, int? duration}) => SetLog(
            id: '$seId-${kind.wire}$index',
            sessionExerciseId: seId,
            sessionId: id,
            exerciseId: ex.id,
            setIndex: index,
            kind: kind,
            targetKg: ex.isLoaded ? kg : null,
            targetReps: reps,
            weightKg: kg,
            reps: reps,
            durationSec: duration,
            rir: rir,
            completedAt: tick(),
          );
      final lo = item.repRange?.$1 ?? 10;
      final hi = item.repRange?.$2 ?? lo;
      switch (ex.tracking) {
        case Tracking.weightReps:
          final w = startKg(ex);
          var working = item.sets;
          if (step.rx.findWeight) {
            sets.add(set(SetKind.ramp, 0, w * 0.6, lo + 2, rir: 4));
            sets.add(set(SetKind.ramp, 1, w * 0.8, lo + 2, rir: 4));
            working = item.sets > 1 ? item.sets - 1 : 1;
          }
          for (var s = 0; s < working; s++) {
            sets.add(set(SetKind.working, sets.length, w, (lo + 2).clamp(lo, hi), rir: s == working - 1 ? 2 : 3));
          }
        case Tracking.reps:
          for (var s = 0; s < item.sets; s++) {
            sets.add(set(SetKind.working, s, 0, hi, rir: 3));
          }
        case Tracking.time:
          for (var s = 0; s < item.sets; s++) {
            sets.add(set(SetKind.working, s, 0, 0, duration: item.durationSeconds ?? ex.durationSeconds));
          }
      }
      exercises.add(SessionExercise(
        id: seId,
        sessionId: id,
        exerciseId: ex.id,
        slotKey: step.slotKey,
        position: exercises.length,
        blockIndex: step.index,
        blockType: item.role == ItemRole.core ? BlockType.superset : BlockType.main,
        role: item.role,
        status: SessionExerciseStatus.done,
        target: step.rx,
        sets: sets,
      ));
    }
    return Session(
      id: id,
      programId: programId,
      templateId: templateId,
      phaseId: PhaseId.foundation,
      trainingWeek: 1,
      dayId: p.dayId,
      dayName: p.dayName,
      status: SessionStatus.completed,
      startedAt: start,
      endedAt: start.add(const Duration(hours: 1)),
      readiness: const ReadinessCheck(sleep: 4, soreness: 2, energy: 4),
      bodyweightKg: 95,
      feeling: 4,
      plan: p,
      exercises: exercises,
    );
  }

  /// Progression state after the three sessions (same weight, one more rep next time).
  static Map<String, ExerciseState> states(AssetCatalog catalog, List<Session> sessions) {
    final out = <String, ExerciseState>{};
    for (final s in sessions) {
      for (final e in s.exercises) {
        final ex = catalog.exercise(e.exerciseId);
        final working = e.workingSets.toList();
        if (!ex.isLoaded || working.isEmpty) continue;
        final w = working.first.weightKg;
        final reps = working.first.reps;
        final total = ex.loadType == LoadType.dumbbell ? w * (ex.dumbbellCount ?? 1) : w;
        final e1rm = epley1rm(total, reps);
        final range = s.plan.exerciseSteps.where((x) => x.slotKey == e.slotKey).firstOrNull?.item.repRange;
        out[ex.id] = ExerciseState(
          exerciseId: ex.id,
          workingKg: w,
          repTargets: [for (final x in working) x.reps + 1],
          lastTrend: Trend.same,
          lastReason: 'Same weight, aim for one more rep',
          lastSessionId: s.id,
          lastRepRange: range,
          firstE1rm: e1rm,
          bestE1rm: e1rm,
          updatedAt: s.endedAt!,
        );
      }
    }
    return out;
  }

  /// Daily weigh-ins Mon 9 - Sun 15 Nov (7-day average 94.7 kg), waist on the first day.
  static List<BodyEntry> bodyEntries() {
    const weights = [95.0, 94.8, 95.1, 94.6, 94.7, 94.3, 94.4];
    return [
      for (final (i, w) in weights.indexed)
        BodyEntry(date: '2026-11-${(9 + i).toString().padLeft(2, '0')}', weightKg: w, waistCm: i == 0 ? 104 : null),
    ];
  }

  static List<NutritionDay> nutritionDays() => const [
        NutritionDay(date: '2026-11-14', proteinPoints: 6.5, waterSachets: 7, vegFruit: true, sleepOk: true),
        NutritionDay(date: '2026-11-15', proteinPoints: 7, waterSachets: 8, vegFruit: true, noSugaryDrinks: true),
      ];

  /// Loads everything above into [app]'s fakes.
  static void seed(FakeApp app) {
    app.settings
      ..profile = profile()
      ..settings = settings();
    app.programs.programs.add(program(app.catalog));
    final s = sessions(app.catalog);
    for (final x in s) {
      app.sessions.seed(x);
    }
    app.exerciseStates.states.addAll(states(app.catalog, s));
    for (final e in bodyEntries()) {
      app.body.entries[e.date] = e;
    }
    for (final d in nutritionDays()) {
      app.nutrition.days[d.date] = d;
    }
  }
}
