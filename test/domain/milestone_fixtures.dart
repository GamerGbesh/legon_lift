// Test builders for WS6 domain tests (adherence, milestones, check-in).
import 'package:legon_lift/data/models/models.dart';
import 'package:legon_lift/domain/api.dart';

/// `yyyy-MM-dd` of [d].
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The default user created at [createdAt].
UserProfile profileAt(DateTime createdAt) => UserProfile.defaults(createdAt);

/// One logged set.
SetLog setLog(
  String sessionId,
  String exerciseId,
  double kg,
  int reps, {
  required DateTime at,
  SetKind kind = SetKind.working,
  int index = 0,
  int? durationSec,
}) =>
    SetLog(
      id: '$sessionId-$exerciseId-${kind.wire}$index',
      sessionExerciseId: '$sessionId-$exerciseId',
      sessionId: sessionId,
      exerciseId: exerciseId,
      setIndex: index,
      kind: kind,
      weightKg: kg,
      reps: reps,
      durationSec: durationSec,
      completedAt: at,
    );

/// A completed one-hour session starting at [start] with [sets] grouped per exercise.
Session session(
  DateTime start, {
  String? id,
  List<SetLog> sets = const [],
  BlockType blockType = BlockType.main,
  SessionStatus status = SessionStatus.completed,
}) {
  final sid = id ?? 's-${start.millisecondsSinceEpoch}';
  final byExercise = <String, List<SetLog>>{};
  for (final s in sets) {
    (byExercise[s.exerciseId] ??= []).add(s);
  }
  return Session(
    id: sid,
    programId: 'p',
    phaseId: PhaseId.foundation,
    trainingWeek: 1,
    dayId: 'push',
    dayName: 'Push',
    status: status,
    startedAt: start,
    endedAt: start.add(const Duration(hours: 1)),
    plan: const SessionPlan(
      programId: 'p',
      phaseId: PhaseId.foundation,
      trainingWeek: 1,
      dayId: 'push',
      dayName: 'Push',
      estimatedMinutes: 60,
      steps: [],
    ),
    exercises: [
      for (final (i, MapEntry(key: exId, value: list)) in byExercise.entries.indexed)
        SessionExercise(
          id: '$sid-$exId',
          sessionId: sid,
          exerciseId: exId,
          slotKey: 'primary:$exId',
          position: i,
          blockIndex: i,
          blockType: blockType,
          role: ItemRole.primary,
          status: SessionExerciseStatus.done,
          target: Prescription(exerciseId: exId, working: const [], restSec: 90),
          sets: list,
        ),
    ],
  );
}

/// Sessions at 17:00 on each of [days] (offsets from [monday]).
List<Session> sessionsOn(DateTime monday, List<int> days) => [
      for (final d in days) session(DateTime(monday.year, monday.month, monday.day + d, 17)),
    ];
