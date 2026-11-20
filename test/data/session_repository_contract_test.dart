import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/data/db/app_database.dart';
import 'package:legon_lift/data/models/models.dart';
import 'package:legon_lift/data/repositories/repositories.dart';
import 'package:legon_lift/domain/api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../fakes/fakes.dart';

/// The same behaviour is required from the sqflite repository and the in-memory fake, so widget
/// tests on the fake mean something on the device.
void main() {
  sqfliteFfiInit();
  final catalog = loadTestCatalog();

  final impls = <String, Future<(SessionRepository, FakeClock, Future<void> Function())> Function()>{
    'FakeSessionRepository': () async {
      final clock = FakeClock();
      return (FakeSessionRepository(clock: clock, catalog: catalog), clock, () async {});
    },
    'SqfliteSessionRepository': () async {
      final clock = FakeClock();
      final db = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
      return (SqfliteSessionRepository(db, catalog, clock: clock), clock, db.close);
    },
  };

  for (final MapEntry(key: name, value: create) in impls.entries) {
    group(name, () {
      late SessionRepository repo;
      late FakeClock clock;
      late Future<void> Function() close;

      setUp(() async {
        (repo, clock, close) = await create();
      });
      tearDown(() => close());

      SetLog setFor(SessionExercise e, int index, double kg, int reps,
              {SetKind kind = SetKind.working, int? rir}) =>
          SetLog(
            id: '${e.id}-$index-${kind.wire}',
            sessionExerciseId: e.id,
            sessionId: e.sessionId,
            exerciseId: e.exerciseId,
            setIndex: index,
            kind: kind,
            weightKg: kg,
            reps: reps,
            rir: rir,
            completedAt: clock.now(),
          );

      test('start creates an in-progress session with stored exercises', () async {
        final plan = SampleData.plan(catalog, 'push');
        var changes = 0;
        final sub = repo.changes.listen((_) => changes++);
        final s = await repo.start(plan, readiness: const ReadinessCheck(sleep: 3));
        await pumpEventQueue();
        await sub.cancel();

        expect(changes, greaterThan(0));
        expect(s.status, SessionStatus.inProgress);
        expect(s.cursor, PlayerCursor.start);
        // warm-up cardio + every exercise step (superset members included).
        expect(s.exercises.length, plan.exerciseSteps.length + 1);
        expect(s.exercises.first.blockType, BlockType.warmup);
        final loaded = await repo.findInProgress();
        expect(loaded, s);
        expect(await repo.byId(s.id), s);
      });

      test('logSet writes the set, the cursor and the volume together', () async {
        final s = await repo.start(SampleData.plan(catalog, 'push'), readiness: ReadinessCheck.none);
        final press = s.exercises.firstWhere((e) => e.exerciseId == 'machine_chest_press');
        const cursor = PlayerCursor(stepIndex: 2, setIndex: 1);
        await repo.logSet(setFor(press, 0, 20, 10, kind: SetKind.ramp), cursor);
        await repo.logSet(setFor(press, 1, 30, 10, rir: 3), cursor.copyWith(setIndex: 2));

        final loaded = (await repo.byId(s.id))!;
        expect(loaded.cursor, cursor.copyWith(setIndex: 2));
        final sets = loaded.exercises.firstWhere((e) => e.id == press.id).sets;
        expect(sets.map((x) => x.kind), [SetKind.ramp, SetKind.working]);
        expect(loaded.totalVolumeKg, 300); // ramp sets do not count

        await repo.updateSet(sets.last.copyWith(reps: 12));
        expect((await repo.byId(s.id))!.totalVolumeKg, 360);
        await repo.deleteSet(sets.last.id);
        final after = (await repo.byId(s.id))!;
        expect(after.totalVolumeKg, 0);
        expect(after.exercises.firstWhere((e) => e.id == press.id).sets, hasLength(1));
      });

      test('dumbbell and unilateral volume follow SPEC 0.4', () async {
        final s = await repo.start(SampleData.plan(catalog, 'push'), readiness: ReadinessCheck.none);
        final incline = s.exercises.firstWhere((e) => e.exerciseId == 'incline_dumbbell_press');
        await repo.logSet(setFor(incline, 0, 10, 10), PlayerCursor.start);
        final ex = catalog.exercise('incline_dumbbell_press');
        expect((await repo.byId(s.id))!.totalVolumeKg, 10 * (ex.dumbbellCount ?? 1) * 10 * (ex.unilateral ? 2 : 1));
      });

      test('status, swap, reorder, extras', () async {
        final s = await repo.start(SampleData.plan(catalog, 'push'), readiness: ReadinessCheck.none);
        final main = s.exercises.where((e) => e.blockType != BlockType.warmup).toList();

        await repo.setExerciseStatus(main[0].id, SessionExerciseStatus.skipped, reason: SkipReason.busy);
        const rx = Prescription(exerciseId: 'dumbbell_bench_press', working: [], restSec: 90);
        final swapped = await repo.replaceExercise(main[1].id, 'dumbbell_bench_press', rx);
        expect(swapped.exerciseId, 'dumbbell_bench_press');
        expect(swapped.originalExerciseId, main[1].exerciseId);
        final again = await repo.replaceExercise(main[1].id, 'smith_machine_bench_press', rx);
        expect(again.originalExerciseId, main[1].exerciseId, reason: 'keeps the first planned id');

        await repo.reorder(s.id, [main[2].id, main[1].id]);
        final extra = SampleData.plan(catalog, 'push').exerciseSteps.last;
        final added = await repo.addExtra(s.id, extra);

        final loaded = (await repo.byId(s.id))!;
        expect(loaded.exercises.first.id, main[2].id);
        expect(loaded.exercises[1].id, main[1].id);
        expect(loaded.exercises.last.id, added.id);
        expect(loaded.exercises.map((e) => e.position), List.generate(loaded.exercises.length, (i) => i));
        final skipped = loaded.exercises.firstWhere((e) => e.id == main[0].id);
        expect(skipped.status, SessionExerciseStatus.skipped);
        expect(skipped.skipReason, SkipReason.busy);
      });

      test('complete, history queries and last exposure', () async {
        final first = await repo.start(SampleData.plan(catalog, 'push'), readiness: ReadinessCheck.none);
        final press1 = first.exercises.firstWhere((e) => e.exerciseId == 'machine_chest_press');
        await repo.logSet(setFor(press1, 0, 30, 12), PlayerCursor.start);
        await repo.logSet(setFor(press1, 1, 30, 11), PlayerCursor.start);
        clock.advance(const Duration(hours: 1));
        final done = await repo.complete(first.id, feeling: 4, note: 'good', bodyweightKg: 94.5);
        expect(done.status, SessionStatus.completed);
        expect(done.endedAt, clock.now());
        expect(done.cursor, isNull);
        expect(done.feeling, 4);
        expect(await repo.findInProgress(), isNull);
        expect(await repo.lastCompletedAt(), clock.now());

        clock.advance(const Duration(days: 2));
        final second = await repo.start(SampleData.plan(catalog, 'push'), readiness: ReadinessCheck.none);
        final press2 = second.exercises.firstWhere((e) => e.exerciseId == 'machine_chest_press');
        await repo.logSet(setFor(press2, 0, 35, 8), PlayerCursor.start);
        await repo.complete(second.id);

        final last = await repo.lastExposure('machine_chest_press');
        expect(last.map((x) => x.weightKg), [35]);
        final before = await repo.lastExposure('machine_chest_press', excludingSessionId: second.id);
        expect(before.map((x) => x.reps), [12, 11]);

        expect((await repo.setsFor('machine_chest_press')).map((x) => x.weightKg), [30, 30, 35]);
        expect(await repo.setsFor('machine_chest_press', limitSessions: 1), hasLength(1));
        expect(await repo.setsFor('machine_chest_press', kinds: {SetKind.ramp}), isEmpty);

        expect((await repo.listCompleted()).map((x) => x.id), [first.id, second.id]);
        expect(await repo.listCompleted(from: second.startedAt), hasLength(1));
        expect(await repo.listCompleted(to: second.startedAt), hasLength(1));
        expect(await repo.countCompleted(programId: SampleData.programId), 2);
        expect(await repo.countCompleted(programId: 'other'), 0);
      });

      test('discarded sessions leave history', () async {
        final s = await repo.start(SampleData.plan(catalog, 'legs'), readiness: ReadinessCheck.none);
        await repo.discard(s.id);
        expect(await repo.findInProgress(), isNull);
        expect(await repo.listCompleted(), isEmpty);
        expect((await repo.byId(s.id))!.status, SessionStatus.discarded);
        expect(await repo.lastCompletedAt(), isNull);
      });
    });
  }
}
