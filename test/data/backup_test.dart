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

/// SPEC 9.2 against the real sqflite database (FFI).
void main() {
  sqfliteFfiInit();
  final catalog = loadTestCatalog();
  late AppDatabase db;
  late FakeClock clock;
  late Directory docs;
  late SqfliteBackupService backup;
  late SqfliteSettingsRepository settings;
  late SqfliteProgramRepository programs;
  late SqfliteSessionRepository sessions;
  late SqfliteBodyRepository body;
  late SqfliteNutritionRepository nutrition;
  late SqfliteExerciseStateRepository states;

  Map<String, dynamic> decode(Uint8List bytes) => jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  Uint8List encode(Map<String, dynamic> doc) => Uint8List.fromList(utf8.encode(jsonEncode(doc)));

  Future<int> count(String table) async =>
      (await db.db.rawQuery('SELECT COUNT(*) AS n FROM $table')).first['n']! as int;

  /// A completed push session with two working sets.
  Future<Session> completedSession() async {
    final s = await sessions.start(SampleData.plan(catalog, 'push'), readiness: ReadinessCheck.none);
    final press = s.exercises.firstWhere((e) => e.exerciseId == 'machine_chest_press');
    for (var i = 0; i < 2; i++) {
      await sessions.logSet(
        SetLog(
          id: 'set-${s.id}-$i',
          sessionExerciseId: press.id,
          sessionId: s.id,
          exerciseId: press.exerciseId,
          setIndex: i,
          kind: SetKind.working,
          weightKg: 30,
          reps: 10,
          completedAt: clock.now(),
        ),
        PlayerCursor(stepIndex: 1, setIndex: i + 1),
      );
    }
    return sessions.complete(s.id, feeling: 4);
  }

  setUp(() async {
    clock = FakeClock();
    db = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    docs = await Directory.systemTemp.createTemp('legon_lift_backup_test');
    backup = SqfliteBackupService(
      db,
      documentsDir: () async => docs,
      idMigrations: catalog.idMigrations,
      knownExerciseIds: {for (final e in catalog.exercises) e.id},
      clock: clock,
    );
    settings = SqfliteSettingsRepository(db, defaults: AppSettings.defaults(catalog.personalization.gym));
    programs = SqfliteProgramRepository(db, catalog, clock: clock);
    sessions = SqfliteSessionRepository(db, catalog, clock: clock);
    body = SqfliteBodyRepository(db, clock: clock);
    nutrition = SqfliteNutritionRepository(db, clock: clock);
    states = SqfliteExerciseStateRepository(db);
  });

  tearDown(() async {
    await db.close();
    await docs.delete(recursive: true);
  });

  test('export has the SPEC envelope and every table', () async {
    await settings.saveProfile(SampleData.profile());
    final doc = decode(await backup.exportJson());
    expect(doc['format'], 'legon_lift_backup');
    expect(doc['version'], 1);
    expect(doc['dbVersion'], kDbVersion);
    expect(doc['exportedAt'], clock.now().millisecondsSinceEpoch);
    expect(doc['appVersion'], '1.0.0+1');
    expect((doc['tables'] as Map).keys, containsAll(kTables));
  });

  test('replace restores a full workout history exactly', () async {
    await settings.saveProfile(SampleData.profile());
    final program = await programs.activateTemplate('ppl_3day');
    final done = await completedSession();
    await programs.advanceAfter(program.id, 'push');
    await body.upsert(const BodyEntry(date: '2026-11-16', weightKg: 94.6));
    final bytes = await backup.exportJson();

    // Change everything, then restore.
    await completedSession();
    await settings.saveProfile(SampleData.profile().copyWith(name: () => 'Changed'));
    await body.delete('2026-11-16');
    await backup.import(bytes, replace: true);

    expect((await settings.loadProfile())!.name, 'Kofi');
    final completed = await sessions.listCompleted();
    expect(completed, hasLength(1));
    expect(completed.single, done);
    expect(completed.single.totalVolumeKg, 600);
    expect((await programs.active())!.nextDayIndex, 1);
    expect((await body.latest())!.weightKg, 94.6);
  });

  test('merge keeps local rows, adds missing ones and keeps one active program', () async {
    await settings.saveProfile(SampleData.profile());
    await programs.activateTemplate('ppl_3day');
    await completedSession();
    await nutrition.save(const NutritionDay(date: '2026-11-16', proteinPoints: 3));
    final bytes = await backup.exportJson();

    // A fresh phone with its own program and a newer nutrition day.
    await backup.import(BackupFormat.empty(clock.now()), replace: true);
    await settings.saveProfile(SampleData.profile().copyWith(name: () => 'New phone'));
    final local = await programs.activateTemplate('upper_lower_4day');
    clock.advance(const Duration(hours: 1));
    await nutrition.save(const NutritionDay(date: '2026-11-16', proteinPoints: 6));

    await backup.import(bytes, replace: false);

    expect((await settings.loadProfile())!.name, 'New phone', reason: 'kv conflicts keep the local row');
    expect(await sessions.listCompleted(), hasLength(1));
    final all = await programs.all();
    expect(all, hasLength(2));
    expect(all.where((p) => p.isActive).map((p) => p.id), [local.id]);
    expect((await nutrition.day('2026-11-16')).proteinPoints, 6, reason: 'local row is newer');
  });

  test('merge: the newer body entry wins in both directions', () async {
    await body.upsert(const BodyEntry(date: '2026-11-10', weightKg: 95));
    clock.advance(const Duration(days: 1));
    await body.upsert(const BodyEntry(date: '2026-11-11', weightKg: 94.8));
    final bytes = await backup.exportJson(); // 10th stamped day 0, 11th stamped day 1

    await body.delete('2026-11-10');
    await body.delete('2026-11-11');
    clock.set(FakeClock.defaultStart.subtract(const Duration(days: 1)));
    await body.upsert(const BodyEntry(date: '2026-11-10', weightKg: 99)); // older than the backup's row
    clock.set(FakeClock.defaultStart.add(const Duration(days: 5)));
    await body.upsert(const BodyEntry(date: '2026-11-11', weightKg: 90)); // newer than the backup's row

    await backup.import(bytes, replace: false);
    final entries = await body.range('2026-11-10', '2026-11-11');
    expect(entries.map((e) => e.weightKg), [95, 90]);
  });

  test('old exercise ids are mapped on import and counted in the preview', () async {
    final oldId = catalog.idMigrations.keys.first;
    final newId = catalog.idMigrations[oldId]!;
    await states.putPrefs(ExercisePrefs(exerciseId: oldId, favorite: true));
    final bytes = await backup.exportJson();

    final preview = await backup.preview(bytes);
    expect(preview.warnings.where((w) => w.contains('old exercise name')), hasLength(1));

    await backup.import(bytes, replace: true);
    final prefs = await states.allPrefs();
    expect(prefs.keys, [newId]);
    expect(prefs[newId]!.favorite, isTrue);
  });

  test('preview counts rows and warns about unknown exercises and a missing profile', () async {
    await completedSession();
    await body.upsert(const BodyEntry(date: '2026-11-16', weightKg: 95));
    await nutrition.save(const NutritionDay(date: '2026-11-16', proteinPoints: 2));
    await states.putPrefs(const ExercisePrefs(exerciseId: 'not_a_real_exercise', favorite: true));

    final p = await backup.preview(await backup.exportJson());
    expect(p.sessions, 1);
    expect(p.sets, 2);
    expect(p.bodyEntries, 1);
    expect(p.nutritionDays, 1);
    expect(p.dbVersion, kDbVersion);
    expect(p.exportedAt, clock.now());
    expect(p.warnings.any((w) => w.contains('1 exercise is not in this version')), isTrue);
    expect(p.warnings.any((w) => w.contains('no profile')), isTrue);
  });

  test('rejects files that are not backups or come from a newer app', () async {
    Future<void> rejects(Uint8List bytes, String message) async {
      await expectLater(
        backup.preview(bytes),
        throwsA(isA<BackupFormatException>().having((e) => e.message, 'message', contains(message))),
      );
      await expectLater(backup.import(bytes, replace: true), throwsA(isA<BackupFormatException>()));
    }

    await rejects(Uint8List.fromList(utf8.encode('hello')), 'not a Legon Lift backup');
    await rejects(encode({'format': 'other', 'dbVersion': 1, 'tables': <String, Object?>{}}), 'not a Legon Lift backup');
    await rejects(encode({'format': 'legon_lift_backup', 'dbVersion': kDbVersion + 1, 'tables': <String, Object?>{}}),
        'newer version');
    await rejects(encode({'format': 'legon_lift_backup', 'dbVersion': 1, 'tables': 'x'}), 'no data tables');
    await rejects(encode({'format': 'legon_lift_backup', 'dbVersion': 1, 'tables': {'sessions': 'x'}}), 'damaged');
  });

  test('a damaged backup changes nothing', () async {
    await settings.saveProfile(SampleData.profile());
    await body.upsert(const BodyEntry(date: '2026-11-16', weightKg: 95));
    final doc = decode(await backup.exportJson());
    // A set log pointing at an exercise row that does not exist breaks the foreign key.
    (doc['tables'] as Map)['set_logs'] = [
      {
        'id': 'orphan',
        'session_exercise_id': 'missing',
        'session_id': 'missing',
        'exercise_id': 'leg_press',
        'set_index': 0,
        'kind': 'working',
        'weight_kg': 50,
        'reps': 10,
        'completed_at': 0,
      },
    ];
    await expectLater(backup.import(encode(doc), replace: true), throwsA(isA<BackupFormatException>()));
    expect(await settings.loadProfile(), SampleData.profile());
    expect(await count('body_entries'), 1);
  });

  test('unknown columns in a row are ignored', () async {
    await body.upsert(const BodyEntry(date: '2026-11-16', weightKg: 95));
    final doc = decode(await backup.exportJson());
    final rows = (doc['tables'] as Map)['body_entries'] as List;
    (rows.single as Map)['mood'] = 'great';
    await backup.import(encode(doc), replace: true);
    expect((await body.latest())!.weightKg, 95);
  });

  test('importing the empty document erases every table (Reset all data)', () async {
    await settings.saveProfile(SampleData.profile());
    await programs.activateTemplate('ppl_3day');
    await completedSession();
    await body.upsert(const BodyEntry(date: '2026-11-16', weightKg: 95));
    await settings.setFlag('x', 'y');

    await backup.import(BackupFormat.empty(clock.now()), replace: true);
    for (final t in kTables) {
      expect(await count(t), 0, reason: t);
    }
    expect(await settings.loadProfile(), isNull);
  });

  test('auto backups are named by time, written whole, and only the newest 4 are kept', () async {
    final paths = <String>[];
    for (var i = 0; i < 6; i++) {
      paths.add(await backup.autoBackup());
      clock.advance(const Duration(days: 7));
    }
    expect(paths.first.endsWith('legon_lift_backup_20261116_1700.json'), isTrue);
    final files = await BackupFormat.autoBackupFiles(docs);
    expect(files.map((f) => f.path), paths.reversed.take(SqfliteBackupService.keepAutoBackups));
    expect(Directory('${docs.path}/backups').listSync().where((e) => e.path.endsWith('.tmp')), isEmpty);
    // Each file is a valid backup.
    expect((await backup.preview(await files.first.readAsBytes())).dbVersion, kDbVersion);
  });

  test('autoBackupFiles is empty when nothing was saved yet', () async {
    expect(await BackupFormat.autoBackupFiles(docs), isEmpty);
  });
}
