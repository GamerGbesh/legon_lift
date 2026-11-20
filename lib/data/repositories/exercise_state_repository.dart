import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models/models.dart';

/// Progression state, personal records and per-exercise preferences (SPEC 7.1).
abstract class ExerciseStateRepository {
  Future<ExerciseState?> get(String exerciseId);

  /// States of [ids] that exist (missing ids are absent from the map).
  Future<Map<String, ExerciseState>> getAll(Iterable<String> ids);
  Future<void> put(ExerciseState s);

  Future<List<PersonalRecord>> records(String exerciseId);

  /// Inserts or replaces the record of (exerciseId, type).
  Future<void> putRecord(PersonalRecord r);

  /// Preferences, or [ExercisePrefs.empty] when none are saved.
  Future<ExercisePrefs> prefs(String exerciseId);
  Future<void> putPrefs(ExercisePrefs p);

  /// Every saved preference row, by exercise id.
  Future<Map<String, ExercisePrefs>> allPrefs();
}

/// [ExerciseStateRepository] on `exercise_state`, `personal_records`, `exercise_prefs`.
class SqfliteExerciseStateRepository implements ExerciseStateRepository {
  SqfliteExerciseStateRepository(this._db);

  final AppDatabase _db;

  Database get _d => _db.db;

  @override
  Future<ExerciseState?> get(String exerciseId) async {
    final rows = await _d.query('exercise_state', where: 'exercise_id = ?', whereArgs: [exerciseId], limit: 1);
    return rows.isEmpty ? null : ExerciseState.fromMap(rows.first);
  }

  @override
  Future<Map<String, ExerciseState>> getAll(Iterable<String> ids) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return {};
    final out = <String, ExerciseState>{};
    // SQLite limits bound variables; chunk to stay well under it.
    for (var i = 0; i < list.length; i += 200) {
      final chunk = list.sublist(i, i + 200 > list.length ? list.length : i + 200);
      final rows = await _d.query('exercise_state',
          where: 'exercise_id IN (${List.filled(chunk.length, '?').join(',')})', whereArgs: chunk);
      for (final r in rows) {
        final s = ExerciseState.fromMap(r);
        out[s.exerciseId] = s;
      }
    }
    return out;
  }

  @override
  Future<void> put(ExerciseState s) => _d.insert('exercise_state', s.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<List<PersonalRecord>> records(String exerciseId) async {
    final rows = await _d.query('personal_records', where: 'exercise_id = ?', whereArgs: [exerciseId]);
    return [for (final r in rows) PersonalRecord.fromMap(r)];
  }

  @override
  Future<void> putRecord(PersonalRecord r) =>
      _d.insert('personal_records', r.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<ExercisePrefs> prefs(String exerciseId) async {
    final rows = await _d.query('exercise_prefs', where: 'exercise_id = ?', whereArgs: [exerciseId], limit: 1);
    return rows.isEmpty ? ExercisePrefs.empty(exerciseId) : ExercisePrefs.fromMap(rows.first);
  }

  @override
  Future<void> putPrefs(ExercisePrefs p) =>
      _d.insert('exercise_prefs', p.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<Map<String, ExercisePrefs>> allPrefs() async {
    final rows = await _d.query('exercise_prefs');
    return {for (final r in rows) r['exercise_id']! as String: ExercisePrefs.fromMap(r)};
  }
}
