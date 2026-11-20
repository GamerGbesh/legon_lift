import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/data/db/app_database.dart';
import 'package:legon_lift/data/db/schema.dart';
import 'package:legon_lift/data/models/models.dart';
import 'package:legon_lift/data/repositories/repositories.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../fakes/fakes.dart';

void main() {
  sqfliteFfiInit();
  final catalog = loadTestCatalog();
  late AppDatabase db;
  late FakeClock clock;

  setUp(() async {
    clock = FakeClock();
    db = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
  });

  tearDown(() => db.close());

  test('schema v1 creates every table with foreign keys on', () async {
    final rows = await db.db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
    expect(rows.map((r) => r['name']), containsAll(kTables));
    final fk = await db.db.rawQuery('PRAGMA foreign_keys');
    expect(fk.first.values.first, 1);
    expect(await db.db.getVersion(), kDbVersion);
  });

  test('settings, profile and flags', () async {
    final defaults = AppSettings.defaults(catalog.personalization.gym);
    final repo = SqfliteSettingsRepository(db, defaults: defaults);
    expect(await repo.loadSettings(), defaults);
    expect(await repo.loadProfile(), isNull);

    final s = defaults.copyWith(palette: PaletteId.kenteEnergy, weighInTime: () => '06:30');
    await repo.saveSettings(s);
    expect(await repo.loadSettings(), s);

    final p = SampleData.profile();
    await repo.saveProfile(p);
    expect(await repo.loadProfile(), p);

    await repo.setFlag('explainer.rir', 'seen');
    expect(await repo.getFlag('explainer.rir'), 'seen');
    await repo.setFlag('explainer.rir', null);
    expect(await repo.getFlag('explainer.rir'), isNull);
  });

  test('programs: activate, advance, overrides', () async {
    final repo = SqfliteProgramRepository(db, catalog, clock: clock);
    expect(await repo.active(), isNull);
    final first = await repo.activateTemplate('ppl_3day');
    expect((await repo.active())?.id, first.id);
    expect(first.dayOrder, ['push', 'pull', 'legs']);

    await repo.advanceAfter(first.id, 'legs');
    expect((await repo.active())!.nextDayIndex, 0);
    await repo.advanceAfter(first.id, 'push');
    expect((await repo.active())!.nextDayIndex, 1);

    const o = ProgramOverride(programId: '', dayId: 'push', slotKey: 'primary:machine_chest_press', exerciseId: 'x');
    await repo.setOverride(o.copyWith(programId: first.id));
    await repo.setOverride(o.copyWith(programId: first.id, exerciseId: 'dumbbell_bench_press'));
    final overrides = await repo.overrides(first.id);
    expect(overrides.single.exerciseId, 'dumbbell_bench_press');
    await repo.clearOverrides(first.id, dayId: 'pull');
    expect(await repo.overrides(first.id), hasLength(1));
    await repo.clearOverrides(first.id);
    expect(await repo.overrides(first.id), isEmpty);

    final second = await repo.activateTemplate('upper_lower_4day', startWeek: 5);
    expect((await repo.active())!.id, second.id);
    expect((await repo.all()).where((p) => p.isActive), hasLength(1));
    expect((await repo.active())!.startWeek, 5);
  });

  test('exercise state, records and prefs', () async {
    final repo = SqfliteExerciseStateRepository(db);
    final states = SampleData.states(catalog, SampleData.sessions(catalog));
    for (final s in states.values) {
      await repo.put(s);
    }
    final some = states.keys.take(3).toList();
    expect(await repo.getAll([...some, 'unknown']), {for (final k in some) k: states[k]});
    expect(await repo.get(some.first), states[some.first]);

    final r = PersonalRecord(
        exerciseId: some.first, type: PrType.e1rm, value: 50, setLogId: 'set', achievedAt: clock.now());
    await repo.putRecord(r);
    await repo.putRecord(r.copyWith(value: 55));
    expect((await repo.records(some.first)).single.value, 55);

    expect(await repo.prefs('leg_press'), const ExercisePrefs.empty('leg_press'));
    await repo.putPrefs(const ExercisePrefs(exerciseId: 'leg_press', favorite: true, machineNote: 'seat 4'));
    expect((await repo.allPrefs())['leg_press']?.machineNote, 'seat 4');
  });

  test('body, nutrition, activity and milestones', () async {
    final body = SqfliteBodyRepository(db, clock: clock);
    for (final e in SampleData.bodyEntries()) {
      await body.upsert(e);
    }
    await body.upsert(const BodyEntry(date: '2026-11-15', weightKg: 94.2));
    expect((await body.latest())!.weightKg, 94.2);
    expect((await body.first())!.date, '2026-11-09');
    expect(await body.range('2026-11-10', '2026-11-12'), hasLength(3));
    await body.delete('2026-11-15');
    expect((await body.latest())!.date, '2026-11-14');

    final nutrition = SqfliteNutritionRepository(db, clock: clock);
    expect(await nutrition.day('2026-11-16'), const NutritionDay.empty('2026-11-16'));
    for (final d in SampleData.nutritionDays()) {
      await nutrition.save(d);
    }
    expect(await nutrition.range('2026-11-01', '2026-11-30'), SampleData.nutritionDays());
    await nutrition.addCalorieAdjustment(
        const CalorieAdjustment(id: 'a', date: '2026-11-30', ruleId: 'r', deltaKcal: -100));
    expect(await nutrition.adjustments(), hasLength(1));

    final activity = SqfliteActivityRepository(db);
    await activity.addCardio(
        const CardioLog(id: 'c', date: '2026-11-10', exerciseId: 'treadmill_brisk_walk', durationSec: 1200));
    expect(await activity.cardio('2026-11-10', '2026-11-10'), hasLength(1));
    const pause = Pause(id: 'p', kind: Pause.kindPause, reason: 'exams', startDate: '2026-12-01');
    await activity.savePause(pause);
    await activity.savePause(pause.copyWith(endDate: () => '2026-12-14'));
    expect((await activity.pauses()).single.endDate, '2026-12-14');

    final milestones = SqfliteMilestoneRepository(db);
    final first = MilestoneAward(milestoneId: 'akwaaba', awardedAt: clock.now());
    await milestones.award(first);
    await milestones.award(MilestoneAward(milestoneId: 'akwaaba', awardedAt: clock.now().add(const Duration(days: 1))));
    expect(await milestones.awards(), [first]);
  });

  test('backup: export, preview, replace and merge', () async {
    final docs = await Directory.systemTemp.createTemp('legon_lift_backup_test');
    addTearDown(() => docs.delete(recursive: true));
    final backup = SqfliteBackupService(db, documentsDir: () async => docs, idMigrations: catalog.idMigrations, clock: clock);
    final body = SqfliteBodyRepository(db, clock: clock);
    final settings = SqfliteSettingsRepository(db, defaults: AppSettings.defaults(catalog.personalization.gym));
    final states = SqfliteExerciseStateRepository(db);
    for (final e in SampleData.bodyEntries()) {
      await body.upsert(e);
    }
    await settings.saveProfile(SampleData.profile());
    await states.putPrefs(const ExercisePrefs(exerciseId: 'db_bench_press', favorite: true));

    final bytes = await backup.exportJson();
    final doc = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    expect(doc['format'], 'legon_lift_backup');
    expect(doc['dbVersion'], kDbVersion);

    final preview = await backup.preview(bytes);
    expect(preview.bodyEntries, 7);
    expect(preview.warnings, hasLength(1)); // db_bench_press is an old id

    await body.delete('2026-11-09');
    await settings.saveProfile(SampleData.profile().copyWith(name: () => 'Changed'));
    await backup.import(bytes, replace: true);
    expect(await body.range('0000', '9999'), hasLength(7));
    expect((await settings.loadProfile())!.name, 'Kofi');
    expect((await states.allPrefs()).keys, contains('dumbbell_bench_press'));

    // Merge keeps the newer body entry.
    clock.advance(const Duration(days: 1));
    await body.upsert(const BodyEntry(date: '2026-11-09', weightKg: 93));
    await backup.import(bytes, replace: false);
    expect((await body.range('2026-11-09', '2026-11-09')).single.weightKg, 93);

    expect(() => backup.preview(Uint8List.fromList(utf8.encode('{"format":"other"}'))),
        throwsA(isA<BackupFormatException>()));

    for (var i = 0; i < 6; i++) {
      clock.advance(const Duration(days: 7));
      await backup.autoBackup();
    }
    expect(Directory('${docs.path}/backups').listSync(), hasLength(SqfliteBackupService.keepAutoBackups));
  });

  group('migrations', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('legon_lift_migrate'));
    tearDown(() => dir.delete(recursive: true));

    const v2 = {
      2: ['ALTER TABLE body_entries ADD COLUMN hip_cm REAL'],
    };

    test('onUpgrade runs each step and keeps the data', () async {
      final path = '${dir.path}/legon_lift.db';
      final v1 = await AppDatabase.open(path: path, factory: databaseFactoryFfi);
      await SqfliteBodyRepository(v1, clock: clock).upsert(const BodyEntry(date: '2026-11-16', weightKg: 95));
      await v1.close();

      final upgraded = await AppDatabase.open(path: path, factory: databaseFactoryFfi, version: 2, migrations: v2);
      addTearDown(upgraded.close);
      expect(await upgraded.db.getVersion(), 2);
      expect(await upgraded.columns('body_entries'), contains('hip_cm'));
      expect((await SqfliteBodyRepository(upgraded).latest())!.weightKg, 95);
      final fk = await upgraded.db.rawQuery('PRAGMA foreign_keys');
      expect(fk.first.values.first, 1);
    });

    test('a fresh install at a later version gets the same schema as an upgrade', () async {
      final fresh = await AppDatabase.open(
          path: '${dir.path}/fresh.db', factory: databaseFactoryFfi, version: 2, migrations: v2);
      addTearDown(fresh.close);
      expect(await fresh.columns('body_entries'), contains('hip_cm'));
    });
  });
}
