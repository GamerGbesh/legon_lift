import 'package:sqflite/sqflite.dart';

import '../../core/clock.dart';
import '../db/app_database.dart';
import '../models/models.dart';

/// Body weight / waist log, one entry per `yyyy-MM-dd` date (SPEC 7.1, 4.8).
abstract class BodyRepository {
  /// Inserts or replaces the entry of `e.date`.
  Future<void> upsert(BodyEntry e);
  Future<void> delete(String date);

  /// Entries with from <= date <= to, ascending by date.
  Future<List<BodyEntry>> range(String from, String to);
  Future<BodyEntry?> latest();
  Future<BodyEntry?> first();
}

/// [BodyRepository] on `body_entries`.
class SqfliteBodyRepository implements BodyRepository {
  SqfliteBodyRepository(this._db, {this._clock = const SystemClock()});

  final AppDatabase _db;
  final Clock _clock;

  Database get _d => _db.db;

  @override
  Future<void> upsert(BodyEntry e) => _d.insert(
        'body_entries',
        {...e.toMap(), 'updated_at': _clock.now().millisecondsSinceEpoch},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  @override
  Future<void> delete(String date) => _d.delete('body_entries', where: 'date = ?', whereArgs: [date]);

  @override
  Future<List<BodyEntry>> range(String from, String to) async {
    final rows = await _d.query('body_entries', where: 'date >= ? AND date <= ?', whereArgs: [from, to], orderBy: 'date ASC');
    return [for (final r in rows) BodyEntry.fromMap(r)];
  }

  @override
  Future<BodyEntry?> latest() async {
    final rows = await _d.query('body_entries', orderBy: 'date DESC', limit: 1);
    return rows.isEmpty ? null : BodyEntry.fromMap(rows.first);
  }

  @override
  Future<BodyEntry?> first() async {
    final rows = await _d.query('body_entries', orderBy: 'date ASC', limit: 1);
    return rows.isEmpty ? null : BodyEntry.fromMap(rows.first);
  }
}
