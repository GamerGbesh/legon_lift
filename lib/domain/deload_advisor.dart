// Owner: WS2. Reactive deload ("easy week") advisor (SPEC 6.12).
import '../data/assets/asset_catalog.dart';
import '../data/models/models.dart';
import 'api.dart';

/// A dismissed suggestion stays hidden this long (SPEC 6.12).
const Duration deloadDismissQuiet = Duration(days: 7);

/// Pain flags count when they happened this recently (SPEC 6.12 rule 4).
const Duration deloadPainWindow = Duration(days: 14);

/// Weeks of hard training after which an easy week is suggested in the later phases.
const Duration deloadMaxGap = Duration(days: 6 * 7);

// Plain-language reasons for the Today card.
const String deloadReasonStalls = 'Two or more of your main lifts have stopped improving.';
const String deloadReasonReps = 'Your total reps dropped two sessions in a row.';
const String deloadReasonReadiness = 'You felt worn out (sleep, soreness, energy) the last two sessions.';
const String deloadReasonPain = 'The same muscles hurt in two sessions within two weeks.';
const String deloadReasonLongBlock = "It's been 6+ weeks of hard training without an easy week.";

/// After a completed session: suggest a reactive easy week when any rule of SPEC 6.12 fires.
///
/// 1. At least 2 primary/secondary lifts have `stallCount >= 2` at the same time.
/// 2. Total reps fell by more than 10% against the previous session of the same day, in each of
///    the two most recent sessions (deload sessions are not compared).
/// 3. Readiness (sleep, soreness inverted, energy; 1..5) averaged 2 or less in each of the last
///    2 sessions.
/// 4. Pain flags on exercises sharing a primary muscle in 2 different sessions within 14 days
///    (needs [catalog] for the muscles; without it, the same exercise).
/// 5. Training week 9 or later and at least 6 weeks since the last deload (none yet counts).
///
/// Nothing is suggested within 7 days of a dismissal, or right after a deload session.
/// [DeloadInput.recentSessions] are completed sessions (any order; sorted here newest first).
DeloadAdvice adviseDeload(DeloadInput input, {AssetCatalog? catalog}) {
  final now = input.now;
  final dismissed = input.lastDismissedAt;
  if (dismissed != null && now.difference(dismissed) < deloadDismissQuiet) return DeloadAdvice.none;

  final sessions = [for (final s in input.recentSessions) if (s.status == SessionStatus.completed) s]
    ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  if (sessions.isNotEmpty && sessions.first.isDeload) return DeloadAdvice.none;

  final reasons = <String>[
    if (_stalledMainLifts(sessions, input.states) >= 2) deloadReasonStalls,
    if (_repsFellTwice(sessions)) deloadReasonReps,
    if (_lowReadinessTwice(sessions)) deloadReasonReadiness,
    if (_repeatedPain(sessions, now, catalog)) deloadReasonPain,
    if (input.trainingWeek >= 9 &&
        (input.lastDeloadAt == null || now.difference(input.lastDeloadAt!) >= deloadMaxGap))
      deloadReasonLongBlock,
  ];
  return reasons.isEmpty ? DeloadAdvice.none : DeloadAdvice(suggest: true, reasons: reasons);
}

/// Rule 1: primary/secondary lifts (roles from the recent sessions) with `stallCount >= 2`.
int _stalledMainLifts(List<Session> sessions, Map<String, ExerciseState> states) {
  final main = <String>{
    for (final s in sessions)
      for (final e in s.exercises)
        if (e.role == ItemRole.primary || e.role == ItemRole.secondary) e.exerciseId,
  };
  return main.where((id) => (states[id]?.stallCount ?? 0) >= 2).length;
}

/// Rule 2.
bool _repsFellTwice(List<Session> newestFirst) {
  final training = [for (final s in newestFirst) if (!s.isDeload) s];
  if (training.length < 2) return false;
  bool fell(int i) {
    final s = training[i];
    for (var j = i + 1; j < training.length; j++) {
      if (training[j].dayId != s.dayId) continue;
      final before = _totalReps(training[j]);
      return before > 0 && _totalReps(s) < 0.9 * before;
    }
    return false;
  }

  return fell(0) && fell(1);
}

int _totalReps(Session s) => s.allSets.where((x) => x.kind == SetKind.working).fold(0, (a, x) => a + x.reps);

/// Rule 3.
bool _lowReadinessTwice(List<Session> newestFirst) {
  if (newestFirst.length < 2) return false;
  for (final s in newestFirst.take(2)) {
    final mean = readinessMean(s.readiness);
    if (mean == null || mean > 2) return false;
  }
  return true;
}

/// Mean of sleep, inverted soreness (5 = no soreness) and energy, over the answered items;
/// null when none was answered.
double? readinessMean(ReadinessCheck r) {
  final values = <int>[
    if (r.sleep != null) r.sleep!,
    if (r.soreness != null) 6 - r.soreness!,
    if (r.energy != null) r.energy!,
  ];
  if (values.isEmpty) return null;
  return values.reduce((a, b) => a + b) / values.length;
}

/// Rule 4.
bool _repeatedPain(List<Session> sessions, DateTime now, AssetCatalog? catalog) {
  final sessionsPerKey = <String, Set<String>>{};
  for (final s in sessions) {
    if (now.difference(s.startedAt) > deloadPainWindow) continue;
    for (final e in s.exercises) {
      if (!e.sets.any((x) => x.painFlag)) continue;
      final ex = catalog?.tryExercise(e.exerciseId);
      final keys = ex == null ? ['exercise:${e.exerciseId}'] : [for (final m in ex.primaryMuscles) 'muscle:${m.wire}'];
      for (final k in keys) {
        sessionsPerKey.putIfAbsent(k, () => {}).add(s.id);
      }
    }
  }
  return sessionsPerKey.values.any((ids) => ids.length >= 2);
}
