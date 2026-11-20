// Owner: WS5. Completed sessions and the stats behind the Progress tab (SPEC 4.7, 6.11).
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/clock.dart';
import '../core/format.dart';
import '../data/assets/asset_catalog.dart';
import '../data/models/models.dart';
import '../data/repositories/session_repository.dart';
import '../domain/api.dart';
import 'settings_store.dart';

/// What the Exercises chart plots per session (SPEC 4.7). All values are total external load
/// (SPEC 0.4: both dumbbells, the whole bar ...).
enum ExerciseMetric {
  /// Estimated best single (Epley, sets of 12 reps or fewer).
  bestSingle,

  /// Heaviest load lifted for at least one rep.
  heaviest,

  /// Best single-set volume (load x reps, x2 for one-side-at-a-time exercises).
  bestSet,
}

/// Working-set volume of one ISO week (Monday start).
@immutable
class WeekVolume {
  const WeekVolume({required this.weekStart, required this.volumeKg, required this.sessions});

  final DateTime weekStart;
  final double volumeKg;
  final int sessions;
}

/// A set flagged as a personal record (SPEC 6.11), for the "Recent records" list.
@immutable
class PrHighlight {
  const PrHighlight({required this.set, required this.exercise, required this.sessionId});

  final SetLog set;
  final Exercise exercise;
  final String sessionId;
}

/// One past session of an exercise: its working sets in order.
@immutable
class ExerciseSessionSummary {
  const ExerciseSessionSummary({required this.sessionId, required this.date, required this.sets});

  final String sessionId;
  final DateTime date;
  final List<SetLog> sets;
}

/// "My history" of an exercise on its detail page (SPEC 4.6).
@immutable
class ExerciseHistory {
  const ExerciseHistory({required this.bestSet, required this.bestSingle, required this.recent});

  static const ExerciseHistory empty = ExerciseHistory(bestSet: null, bestSingle: [], recent: []);

  /// The best working set ever: highest estimated best single for loaded exercises, most reps
  /// for bodyweight ones, longest for timed ones.
  final SetLog? bestSet;

  /// Estimated best single per session, oldest first (loaded exercises only).
  final List<(DateTime, double)> bestSingle;

  /// The last sessions (at most 5), newest first.
  final List<ExerciseSessionSummary> recent;

  bool get isEmpty => recent.isEmpty;
}

/// Completed sessions and derived stats (SPEC 4.7).
///
/// [load] keeps the last [windowWeeks] weeks of completed sessions in memory (heatmap, weekly
/// volume, records); older data is queried on demand. It reloads after every session write;
/// overlapping reloads are coalesced into one follow-up reload.
class HistoryStore extends ChangeNotifier {
  HistoryStore({
    required this._catalog,
    required this._sessions,
    required this._settings,
    required this._clock,
  }) {
    _sub = _sessions.changes.listen((_) => unawaited(load()));
  }

  /// Weeks shown by the calendar heatmap (SPEC 4.7).
  static const int windowWeeks = 20;

  /// Weeks shown by the weekly volume chart (SPEC 4.7).
  static const int volumeWeeks = 12;

  final AssetCatalog _catalog;
  final SessionRepository _sessions;
  final SettingsStore _settings;
  final Clock _clock;
  late final StreamSubscription<void> _sub;
  WeeklyStats _thisWeek = WeeklyStats.empty;
  List<Session> _recent = const [];
  List<WeekVolume> _weeklyVolume = const [];
  Map<String, int> _setsByDay = const {};
  List<PrHighlight> _recentPrs = const [];
  bool _loaded = false;
  bool _disposed = false;
  Future<void>? _loading;
  bool _reloadQueued = false;

  /// Completed sessions in [from, to), oldest first.
  Future<List<Session>> sessions({DateTime? from, DateTime? to}) => _sessions.listCompleted(from: from, to: to);

  /// Stats of the current ISO week (Monday start).
  WeeklyStats get thisWeek => _thisWeek;

  /// True after the first [load] finished.
  bool get loaded => _loaded;

  /// Completed sessions of the last [windowWeeks] weeks (this week included), oldest first.
  List<Session> get recent => _recent;

  /// Monday of the first week of the heatmap window.
  DateTime get windowStart => weekStart(_clock.now(), weeksBack: windowWeeks - 1);

  /// Completed workouts since the 1st of this month.
  int get sessionsThisMonth {
    final now = _clock.now();
    final first = DateTime(now.year, now.month);
    return _recent.where((s) => !s.startedAt.isBefore(first)).length;
  }

  /// Working-set volume of the last [volumeWeeks] ISO weeks, oldest first (this week last).
  List<WeekVolume> get weeklyVolume => _weeklyVolume;

  /// Working sets per day (`yyyy-MM-dd`) in the window (heatmap intensity, SPEC 4.7).
  Map<String, int> get workingSetsByDay => _setsByDay;

  /// Sets flagged as records in the window, newest first (at most 5).
  List<PrHighlight> get recentPrs => _recentPrs;

  /// Completed sessions in the window that started on [dateKey].
  List<Session> sessionsOn(String dateKey) =>
      [for (final s in _recent) if (Fmt.dateKey(s.startedAt) == dateKey) s];

  Future<void> load() {
    if (_loading != null) {
      _reloadQueued = true;
      return _loading!;
    }
    return _loading = _loadLoop();
  }

  Future<void> _loadLoop() async {
    try {
      do {
        _reloadQueued = false;
        await _reload();
      } while (_reloadQueued && !_disposed);
    } finally {
      _loading = null;
    }
  }

  Future<void> _reload() async {
    final now = _clock.now();
    final eq = _settings.settings.equipment;
    final recent = await sessions(from: weekStart(now, weeksBack: windowWeeks - 1));
    if (_disposed) return;

    final thisMonday = weekStart(now);
    final volume = <WeekVolume>[];
    for (var i = volumeWeeks - 1; i >= 0; i--) {
      final from = weekStart(now, weeksBack: i);
      final to = DateTime(from.year, from.month, from.day + 7);
      final inWeek = [for (final s in recent) if (!s.startedAt.isBefore(from) && s.startedAt.isBefore(to)) s];
      volume.add(WeekVolume(
        weekStart: from,
        volumeKg: inWeek.isEmpty ? 0 : weeklyStats(inWeek, _catalog, eq).volumeKg,
        sessions: inWeek.length,
      ));
    }

    final byDay = <String, int>{};
    final prs = <PrHighlight>[];
    for (final s in recent) {
      final key = Fmt.dateKey(s.startedAt);
      byDay[key] = (byDay[key] ?? 0) + s.allSets.where((x) => x.kind == SetKind.working).length;
      for (final set in s.allSets) {
        final ex = _catalog.tryExercise(set.exerciseId);
        if (set.isPr && ex != null) prs.add(PrHighlight(set: set, exercise: ex, sessionId: s.id));
      }
    }
    prs.sort((a, b) => b.set.completedAt.compareTo(a.set.completedAt));

    _recent = List.unmodifiable(recent);
    _thisWeek = weeklyStats([for (final s in recent) if (!s.startedAt.isBefore(thisMonday)) s], _catalog, eq);
    _weeklyVolume = List.unmodifiable(volume);
    _setsByDay = Map.unmodifiable(byDay);
    _recentPrs = List.unmodifiable(prs.take(5));
    _loaded = true;
    notifyListeners();
  }

  /// Estimated best single per session for [exerciseId] (reps <= 12), oldest first.
  Future<List<(DateTime, double)>> e1rmSeries(String exerciseId) => series(exerciseId, ExerciseMetric.bestSingle);

  /// One point per session for [exerciseId] and [metric], oldest first. Empty for exercises
  /// that are not loaded with weight.
  Future<List<(DateTime, double)>> series(String exerciseId, ExerciseMetric metric) async {
    final ex = _catalog.tryExercise(exerciseId);
    if (ex == null || !ex.isLoaded) return const [];
    final sets = await _sessions.setsFor(exerciseId, limitSessions: 1000, kinds: _workKinds);
    return seriesFromSets(sets, ex, _settings.settings.equipment, metric);
  }

  /// Loaded exercises with at least one logged working set, most-trained first.
  Future<List<Exercise>> trackedExercises() async {
    final all = await sessions();
    final counts = <String, int>{};
    for (final s in all) {
      for (final id in {for (final x in s.allSets) if (x.kind == SetKind.working) x.exerciseId}) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    final out = [
      for (final id in counts.keys)
        if (_catalog.tryExercise(id) case final ex? when ex.isLoaded) ex,
    ];
    out.sort((a, b) {
      final byCount = counts[b.id]!.compareTo(counts[a.id]!);
      return byCount != 0 ? byCount : a.name.compareTo(b.name);
    });
    return out;
  }

  /// Best set, estimated-best trend and the last 5 sessions of [exerciseId] (SPEC 4.6).
  Future<ExerciseHistory> exerciseHistory(String exerciseId) async {
    final ex = _catalog.tryExercise(exerciseId);
    if (ex == null) return ExerciseHistory.empty;
    final sets = await _sessions.setsFor(exerciseId, limitSessions: 1000, kinds: _workKinds);
    return historyFromSets(sets, ex, _settings.settings.equipment);
  }

  /// A session with its exercises and sets (any status).
  Future<Session?> session(String id) => _sessions.byId(id);

  /// Edits a logged set after the fact (the repository recomputes the session volume).
  Future<void> updateSet(SetLog set) => _sessions.updateSet(set);

  /// Deletes a logged set.
  Future<void> deleteSet(String setId) => _sessions.deleteSet(setId);

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sub.cancel());
    super.dispose();
  }
}

const Set<SetKind> _workKinds = {SetKind.working, SetKind.test};

/// Local midnight of the Monday of [t]'s ISO week, [weeksBack] weeks earlier.
DateTime weekStart(DateTime t, {int weeksBack = 0}) => DateTime(t.year, t.month, t.day - (t.weekday - 1) - 7 * weeksBack);

/// Volume of one set (SPEC 0.4): total load x reps, x2 for one-side-at-a-time exercises.
double setVolumeKg(SetLog s, Exercise ex, EquipmentProfile eq) =>
    totalLoadKg(s, ex, eq) * s.reps * (ex.unilateral ? 2 : 1);

/// One point per session (the session's best value, dated by its first set), oldest first.
List<(DateTime, double)> seriesFromSets(List<SetLog> sets, Exercise ex, EquipmentProfile eq, ExerciseMetric metric) {
  final bySession = <String, (DateTime, double)>{};
  for (final s in sets) {
    if (s.reps < 1) continue;
    final double value;
    switch (metric) {
      case ExerciseMetric.bestSingle:
        if (s.reps > 12) continue;
        value = epley1rm(totalLoadKg(s, ex, eq), s.reps);
      case ExerciseMetric.heaviest:
        value = totalLoadKg(s, ex, eq);
      case ExerciseMetric.bestSet:
        value = setVolumeKg(s, ex, eq);
    }
    if (value <= 0) continue;
    final prev = bySession[s.sessionId];
    if (prev == null) {
      bySession[s.sessionId] = (s.completedAt, value);
    } else {
      final date = s.completedAt.isBefore(prev.$1) ? s.completedAt : prev.$1;
      bySession[s.sessionId] = (date, value > prev.$2 ? value : prev.$2);
    }
  }
  return bySession.values.toList()..sort((a, b) => a.$1.compareTo(b.$1));
}

/// Builds [ExerciseHistory] from an exercise's working/test sets (any order).
ExerciseHistory historyFromSets(List<SetLog> sets, Exercise ex, EquipmentProfile eq) {
  if (sets.isEmpty) return ExerciseHistory.empty;
  double rank(SetLog s) => switch (ex.tracking) {
        Tracking.weightReps => s.reps >= 1 && s.reps <= 12
            ? epley1rm(totalLoadKg(s, ex, eq), s.reps)
            // Sets above 12 reps rank below any set that has an estimate.
            : totalLoadKg(s, ex, eq) * 0.5,
        Tracking.reps => s.reps.toDouble(),
        Tracking.time => (s.durationSec ?? 0).toDouble(),
      };
  SetLog? best;
  for (final s in sets) {
    if (best == null || rank(s) > rank(best)) best = s;
  }

  final bySession = <String, List<SetLog>>{};
  for (final s in sets) {
    (bySession[s.sessionId] ??= []).add(s);
  }
  final summaries = [
    for (final e in bySession.entries)
      ExerciseSessionSummary(
        sessionId: e.key,
        date: e.value.map((s) => s.completedAt).reduce((a, b) => a.isBefore(b) ? a : b),
        sets: List.unmodifiable(e.value..sort((a, b) => a.setIndex.compareTo(b.setIndex))),
      ),
  ]..sort((a, b) => b.date.compareTo(a.date));

  return ExerciseHistory(
    bestSet: best,
    bestSingle: ex.isLoaded ? seriesFromSets(sets, ex, eq, ExerciseMetric.bestSingle) : const [],
    recent: List.unmodifiable(summaries.take(5)),
  );
}
