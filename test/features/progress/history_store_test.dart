import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/data/models/models.dart';
import 'package:legon_lift/domain/api.dart';
import 'package:legon_lift/features/progress/activity_heatmap.dart';
import 'package:legon_lift/state/history_store.dart';
import 'package:legon_lift/state/settings_store.dart';

import '../../fakes/fakes.dart';

void main() {
  late FakeApp app;
  late SettingsStore settings;
  late HistoryStore store;

  setUp(() async {
    app = FakeApp.seeded();
    settings = await SettingsStore.load(app.settings);
    store = HistoryStore(catalog: app.catalog, sessions: app.sessions, settings: settings, clock: app.clock);
    await store.load();
  });

  tearDown(() => store.dispose());

  SetLog set(String exerciseId, String sessionId, double kg, int reps, DateTime at, {SetKind kind = SetKind.working}) =>
      SetLog(
        id: '$sessionId-$kg-$reps',
        sessionExerciseId: '$sessionId-e',
        sessionId: sessionId,
        exerciseId: exerciseId,
        setIndex: 0,
        kind: kind,
        weightKg: kg,
        reps: reps,
        completedAt: at,
      );

  test('weekStart is the local Monday midnight', () {
    expect(weekStart(DateTime(2026, 11, 20, 18)), DateTime(2026, 11, 16));
    expect(weekStart(DateTime(2026, 11, 16)), DateTime(2026, 11, 16));
    expect(weekStart(DateTime(2026, 11, 16), weeksBack: 2), DateTime(2026, 11, 2));
  });

  test('loads the window: sessions, month count, heatmap sets', () {
    expect(store.loaded, isTrue);
    expect(store.recent.map((s) => s.id), SampleData.sessionIds);
    expect(store.sessionsThisMonth, 3);
    expect(store.windowStart, DateTime(2026, 11, 16).subtract(const Duration(days: 7 * 19)));

    final push = app.sessions.sessions[SampleData.sessionIds.first]!;
    final pushSets = push.allSets.where((s) => s.kind == SetKind.working).length;
    expect(store.workingSetsByDay['2026-11-09'], pushSets);
    expect(store.sessionsOn('2026-11-09').single.id, push.id);
    expect(store.sessionsOn('2026-11-10'), isEmpty);
  });

  test('weekly volume covers 12 weeks and uses the domain weekly stats', () {
    final weeks = store.weeklyVolume;
    expect(weeks, hasLength(HistoryStore.volumeWeeks));
    expect(weeks.last.weekStart, DateTime(2026, 11, 16));
    expect(weeks.last.sessions, 0);
    expect(weeks.last.volumeKg, 0);
    final lastWeek = weeks[weeks.length - 2];
    expect(lastWeek.weekStart, DateTime(2026, 11, 9));
    expect(lastWeek.sessions, 3);
    final expected = weeklyStats(store.recent, app.catalog, settings.settings.equipment).volumeKg;
    expect(lastWeek.volumeKg, expected);
    expect(store.thisWeek.sessions, 0);
  });

  test('reloads after a session write and lists records', () async {
    final push = app.sessions.sessions[SampleData.sessionIds.first]!;
    final working = push.allSets.firstWhere((s) => s.kind == SetKind.working);
    expect(store.recentPrs, isEmpty);
    await store.updateSet(working.copyWith(isPr: true));
    await pumpEventQueue();
    expect(store.recentPrs.single.set.id, working.id);
    expect(store.recentPrs.single.sessionId, push.id);
  });

  test('deleteSet removes the set from storage', () async {
    final push = app.sessions.sessions[SampleData.sessionIds.first]!;
    final first = push.allSets.first;
    await store.deleteSet(first.id);
    final reloaded = await store.session(push.id);
    expect(reloaded!.allSets.any((s) => s.id == first.id), isFalse);
  });

  group('series', () {
    test('best single uses total load (both dumbbells) and skips sets over 12 reps', () {
      final ex = app.catalog.exercise('dumbbell_bench_press');
      expect(ex.dumbbellCount, 2);
      final eq = settings.settings.equipment;
      final day1 = DateTime(2026, 11, 2, 17);
      final day2 = DateTime(2026, 11, 4, 17);
      final sets = [
        set(ex.id, 's1', 10, 10, day1),
        set(ex.id, 's1', 12, 8, day1.add(const Duration(minutes: 3))),
        set(ex.id, 's2', 8, 15, day2), // too many reps for an estimate
      ];
      final best = seriesFromSets(sets, ex, eq, ExerciseMetric.bestSingle);
      expect(best, hasLength(1));
      expect(best.single.$1, day1);
      expect(best.single.$2, closeTo(epley1rm(24, 8), 1e-9));

      final heaviest = seriesFromSets(sets, ex, eq, ExerciseMetric.heaviest);
      expect([for (final p in heaviest) p.$2], [24, 16]);

      final volume = seriesFromSets(sets, ex, eq, ExerciseMetric.bestSet);
      expect([for (final p in volume) p.$2], [20 * 10, 16 * 15]);
    });

    test('series of a store exercise and the tracked list', () async {
      final tracked = await store.trackedExercises();
      expect(tracked, isNotEmpty);
      expect(tracked.every((e) => e.isLoaded), isTrue);
      final id = tracked.first.id;
      expect(await store.series(id, ExerciseMetric.heaviest), hasLength(1));
      final e1rm = await store.e1rmSeries(id);
      final sets = app.sessions.sessions.values.expand((s) => s.allSets).where((s) => s.exerciseId == id);
      expect(e1rm, hasLength(sets.any((s) => s.kind == SetKind.working && s.reps <= 12) ? 1 : 0));
      expect(await store.series('cat_cow', ExerciseMetric.bestSingle), isEmpty);
    });
  });

  group('exercise history', () {
    test('best set, sessions newest first, at most 5', () {
      final ex = app.catalog.exercise('machine_chest_press');
      final eq = settings.settings.equipment;
      final sets = [
        for (var i = 0; i < 7; i++) set(ex.id, 's$i', 30.0 + i, 10, DateTime(2026, 10, 1 + i * 2, 17)),
      ];
      final h = historyFromSets(sets, ex, eq);
      expect(h.recent, hasLength(5));
      expect(h.recent.first.sessionId, 's6');
      expect(h.bestSet!.weightKg, 36);
      expect(h.bestSingle, hasLength(7));
      expect(historyFromSets(const [], ex, eq).isEmpty, isTrue);
    });

    test('from the store for a sample exercise', () async {
      final push = app.sessions.sessions[SampleData.sessionIds.first]!;
      final id = push.exercises.firstWhere((e) => app.catalog.exercise(e.exerciseId).isLoaded).exerciseId;
      final h = await store.exerciseHistory(id);
      expect(h.isEmpty, isFalse);
      expect(h.recent.single.sessionId, push.id);
      expect(h.bestSet, isNotNull);
    });
  });

  test('heat buckets follow SPEC 6.11', () {
    expect([for (final n in [0, 1, 9, 10, 14, 15, 19, 20, 40]) heatBucket(n)], [0, 1, 1, 2, 2, 3, 3, 4, 4]);
  });
}
