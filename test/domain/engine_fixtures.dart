// Shared fixtures for the WS2 training-engine tests (test/domain/**).
import 'package:legon_lift/data/assets/asset_catalog.dart';
import 'package:legon_lift/data/models/models.dart';
import 'package:legon_lift/domain/api.dart';

import '../fakes/test_catalog.dart';

/// The real bundled data.
AssetCatalog get catalog => loadTestCatalog();

/// The gym's default equipment (personalization.gym): plates 25..1.25, bar 20, Smith bar 10,
/// dumbbells 2..40 in 2 kg steps.
EquipmentProfile get gymEq => EquipmentProfile.fromDefaults(catalog.personalization.gym);

Exercise ex(String id) => catalog.exercise(id);

final DateTime t0 = DateTime(2026, 11, 16, 17);

/// A plain program item for unit tests.
ProgramItem item(
  String exerciseId, {
  int sets = 3,
  (int, int)? reps = (8, 12),
  int? rir = 2,
  int rest = 90,
  ItemRole role = ItemRole.primary,
  Object warmupSets = 'auto',
  double? inc,
  int? durationSeconds,
  String? test,
  List<String> substitutions = const [],
}) =>
    ProgramItem(
      exerciseId: exerciseId,
      sets: sets,
      repRange: reps,
      durationSeconds: durationSeconds,
      rir: rir,
      restSeconds: rest,
      role: role,
      warmupSets: warmupSets,
      weightIncrementKg: inc,
      test: test,
      substitutions: substitutions,
    );

var _setCounter = 0;

/// A logged set.
SetLog setLog(
  String exerciseId,
  double kg,
  int reps, {
  int? rir,
  SetKind kind = SetKind.working,
  bool pain = false,
  String sessionId = 'session-1',
  int setIndex = 0,
  DateTime? at,
}) =>
    SetLog(
      id: 'set-${_setCounter++}',
      sessionExerciseId: '$sessionId-$exerciseId',
      sessionId: sessionId,
      exerciseId: exerciseId,
      setIndex: setIndex,
      kind: kind,
      weightKg: kg,
      reps: reps,
      rir: rir,
      painFlag: pain,
      completedAt: at ?? t0,
    );

/// Working sets at one weight with the given reps (and optional RIR answers).
List<SetLog> sets(String exerciseId, double kg, List<int> reps, {List<int?>? rirs, String sessionId = 'session-1'}) => [
      for (var i = 0; i < reps.length; i++)
        setLog(exerciseId, kg, reps[i], rir: rirs?[i], sessionId: sessionId, setIndex: i),
    ];

ExerciseState state(
  String exerciseId, {
  double? workingKg,
  List<int> repTargets = const [],
  int stallCount = 0,
  int resetCount = 0,
  Trend lastTrend = Trend.same,
  (int, int)? lastRepRange = (8, 12),
  double? bestE1rm,
  double? firstE1rm,
  double? lastJumpPct,
}) =>
    ExerciseState(
      exerciseId: exerciseId,
      workingKg: workingKg,
      repTargets: repTargets,
      stallCount: stallCount,
      resetCount: resetCount,
      lastTrend: lastTrend,
      lastRepRange: lastRepRange,
      bestE1rm: bestE1rm,
      firstE1rm: firstE1rm,
      lastJumpPct: lastJumpPct,
      updatedAt: t0,
    );

/// A phase for prescribe tests.
Phase phase({
  PhaseId id = PhaseId.foundation,
  List<int> weeks = const [1, 2, 3, 4],
  Map<int, int> offsets = const {},
  Map<ItemRole, int>? floors,
  double loadMultiplier = 1.0,
}) =>
    Phase(
      phaseId: id,
      name: id.wire,
      weeks: weeks,
      rirWeekOffsets: offsets,
      rirFloorByRole: floors,
      loadMultiplier: loadMultiplier,
      unlocks: const {'machines', 'dumbbells', 'cables'},
      days: const [],
    );

ActiveProgram activeFor(ProgramTemplate t, {int nextDayIndex = 0, int startWeek = 1, int reactiveDeload = 0}) =>
    ActiveProgram(
      id: 'active-${t.programId}',
      templateId: t.programId,
      name: t.name,
      dayOrder: List.of(t.dayOrder),
      nextDayIndex: nextDayIndex,
      startedAt: DateTime(2026, 1, 1),
      startWeek: startWeek,
      reactiveDeloadRemaining: reactiveDeload,
    );

UserProfile profile({int minutes = 60, List<String> limitations = const [], Goal goal = Goal.recomp}) =>
    UserProfile.defaults(DateTime(2026, 1, 1)).copyWith(sessionMinutes: minutes, limitations: limitations, goal: goal);

AppSettings settings({EquipmentProfile? eq, bool warmupSets = true, bool warmupBlock = true, bool cooldownBlock = true}) =>
    AppSettings(
      equipment: eq ?? gymEq,
      warmupSets: warmupSets,
      warmupBlock: warmupBlock,
      cooldownBlock: cooldownBlock,
    );

/// A working weight for every loaded exercise of [t] (its starting weight), as after week 1.
Map<String, ExerciseState> establishedStates(ProgramTemplate t, {EquipmentProfile? eq}) {
  final e = eq ?? gymEq;
  final out = <String, ExerciseState>{};
  for (final exercise in catalog.exercises) {
    if (exercise.tracking != Tracking.weightReps) continue;
    final w = seedWeight(exercise, e);
    out[exercise.id] = ExerciseState(
      exerciseId: exercise.id,
      workingKg: w,
      lastRepRange: null,
      updatedAt: t0,
    );
  }
  return out;
}

BuildSessionInput buildInput(
  ProgramTemplate t, {
  String? dayId,
  int completedNonDeload = 0,
  int minutes = 60,
  bool hotDay = false,
  bool cardioOff = false,
  bool recentIllness = false,
  Map<String, ExerciseState> states = const {},
  Map<String, ExercisePrefs> prefs = const {},
  List<ProgramOverride> overrides = const [],
  List<String> limitations = const [],
  Goal goal = Goal.recomp,
  AppSettings? appSettings,
  DateTime? lastCompletedAt,
  DateTime? now,
  int startWeek = 1,
  int reactiveDeload = 0,
}) =>
    BuildSessionInput(
      template: t,
      active: activeFor(t, startWeek: startWeek, reactiveDeload: reactiveDeload),
      overrides: overrides,
      dayId: dayId,
      catalog: catalog,
      states: states,
      prefs: prefs,
      completedNonDeload: completedNonDeload,
      lastCompletedAt: lastCompletedAt ?? (now ?? t0).subtract(const Duration(days: 2)),
      settings: appSettings ?? settings(),
      profile: profile(minutes: minutes, limitations: limitations, goal: goal),
      now: now ?? t0,
      hotDay: hotDay,
      recentIllness: recentIllness,
      cardioOff: cardioOff,
      limitationRules: catalog.personalization.limitationRules,
    );

/// Completed non-deload sessions that put [t] in [week] (first session of that week).
int completedForWeek(ProgramTemplate t, int week) => (week - 1) * t.daysPerWeek;

/// Python's round() (banker's rounding), used by tool/build_data.py for estimatedMinutes.
int pyRound(double x) {
  final f = x.floorToDouble();
  final diff = x - f;
  if ((diff - 0.5).abs() < 1e-9) return f.toInt().isEven ? f.toInt() : f.toInt() + 1;
  return x.round();
}
