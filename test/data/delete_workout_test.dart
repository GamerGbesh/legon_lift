import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/data/db/app_database.dart';
import 'package:legon_lift/data/models/models.dart';
import 'package:legon_lift/data/repositories/repositories.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../fakes/fakes.dart';

/// "Delete today's workout": only the latest workout, only on its day, and everything finishing
/// it changed is put back.
void main() {
  sqfliteFfiInit();
  final catalog = loadTestCatalog();

  late AppDatabase db;
  late FakeClock clock;
  late SqfliteSessionRepository sessions;
  late SqfliteProgramRepository programs;
  late SqfliteExerciseStateRepository states;
  late SqfliteMilestoneRepository milestones;

  setUp(() async {
    clock = FakeClock();
    db = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    sessions = SqfliteSessionRepository(db, catalog, clock: clock);
    programs = SqfliteProgramRepository(db, catalog, clock: clock);
    states = SqfliteExerciseStateRepository(db);
    milestones = SqfliteMilestoneRepository(db);
  });
  tearDown(() => db.close());

  /// Starts, logs one set, snapshots and completes a push workout the way the player does, and
  /// applies the same kinds of side effects (progression, record, rotation, milestone).
  Future<Session> finishWorkout(String exerciseKgLabel) async {
    final program = await programs.activateTemplate('ppl_3day');
    final s = await sessions.start(SampleData.plan(catalog, 'push'), readiness: ReadinessCheck.none);
    final se = s.exercises.firstWhere((e) => catalog.exercise(e.exerciseId).isLoaded);
    final set = SetLog(
      id: 'set-$exerciseKgLabel',
      sessionExerciseId: se.id,
      sessionId: s.id,
      exerciseId: se.exerciseId,
      setIndex: 0,
      kind: SetKind.working,
      weightKg: 30,
      reps: 10,
      completedAt: clock.now(),
    );
    await sessions.logSet(set, PlayerCursor.start);
    await sessions.saveUndoSnapshot(s.id);
    final done = await sessions.complete(s.id);
    await states.put(ExerciseState(exerciseId: se.exerciseId, workingKg: 32.5, updatedAt: clock.now()));
    await states.putRecord(PersonalRecord(
        exerciseId: se.exerciseId, type: PrType.e1rm, value: 40, setLogId: set.id, achievedAt: clock.now()));
    await programs.advanceAfter(program.id, s.dayId);
    await milestones.award(MilestoneAward(milestoneId: 'first_session', awardedAt: clock.now()));
    return done;
  }

  test('restores progress, records, rotation and milestones, and removes the workout', () async {
    final before = await programs.activateTemplate('ppl_3day');
    final s = await finishWorkout('a');
    final exId = s.exercises.firstWhere((e) => catalog.exercise(e.exerciseId).isLoaded).exerciseId;
    final rotated = await programs.active();
    expect(rotated!.nextDayIndex, isNot(before.nextDayIndex));

    expect(await sessions.canDelete(s.id), isTrue);
    await sessions.deleteCompleted(s.id);

    expect(await sessions.byId(s.id), isNull);
    expect(await sessions.setsFor(exId), isEmpty);
    expect(await states.get(exId), isNull);
    expect(await states.records(exId), isEmpty);
    expect((await programs.active())!.nextDayIndex, before.nextDayIndex);
    expect(await milestones.awards(), isEmpty);
  });

  test('only on the day it was logged', () async {
    final s = await finishWorkout('a');
    clock.advance(const Duration(days: 1));
    expect(await sessions.canDelete(s.id), isFalse);
  });

  test('only the most recent workout', () async {
    final first = await finishWorkout('a');
    clock.advance(const Duration(hours: 1));
    final second = await finishWorkout('b');
    expect(await sessions.canDelete(first.id), isFalse);
    expect(await sessions.canDelete(second.id), isTrue);
  });

  test('a workout in progress cannot be deleted this way', () async {
    final s = await sessions.start(SampleData.plan(catalog, 'push'), readiness: ReadinessCheck.none);
    expect(await sessions.canDelete(s.id), isFalse);
  });
}
