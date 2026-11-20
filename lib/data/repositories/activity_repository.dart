import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models/models.dart';

/// Rest-day cardio logs and pause/tag periods (SPEC 7.1, 10.4).
abstract class ActivityRepository {
  Future<void> addCardio(CardioLog c);

  /// Cardio logs with from <= date <= to, ascending.
  Future<List<CardioLog>> cardio(String from, String to);

  /// All pauses and tags, oldest first.
  Future<List<Pause>> pauses();

  /// Inserts or replaces by id (ending a pause = saving it with an endDate).
  Future<void> savePause(Pause p);
}

/// [ActivityRepository] on `cardio_logs` and `pauses`.
class SqfliteActivityRepository implements ActivityRepository {
  SqfliteActivityRepository(this._db);

  final AppDatabase _db;

  Database get _d => _db.db;

  @override
  Future<void> addCardio(CardioLog c) => _d.insert('cardio_logs', c.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<List<CardioLog>> cardio(String from, String to) async {
    final rows = await _d.query('cardio_logs', where: 'date >= ? AND date <= ?', whereArgs: [from, to], orderBy: 'date ASC');
    return [for (final r in rows) CardioLog.fromMap(r)];
  }

  @override
  Future<List<Pause>> pauses() async {
    final rows = await _d.query('pauses', orderBy: 'start_date ASC');
    return [for (final r in rows) Pause.fromMap(r)];
  }

  @override
  Future<void> savePause(Pause p) => _d.insert('pauses', p.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
}
