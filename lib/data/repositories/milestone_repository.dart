import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models/models.dart';

/// Earned badges (SPEC 7.1, 10.3).
abstract class MilestoneRepository {
  /// All awards, oldest first.
  Future<List<MilestoneAward>> awards();

  /// Records an award; awarding the same milestone again keeps the first award.
  Future<void> award(MilestoneAward a);
}

/// [MilestoneRepository] on `milestone_awards`.
class SqfliteMilestoneRepository implements MilestoneRepository {
  SqfliteMilestoneRepository(this._db);

  final AppDatabase _db;

  Database get _d => _db.db;

  @override
  Future<List<MilestoneAward>> awards() async {
    final rows = await _d.query('milestone_awards', orderBy: 'awarded_at ASC');
    return [for (final r in rows) MilestoneAward.fromMap(r)];
  }

  @override
  Future<void> award(MilestoneAward a) =>
      _d.insert('milestone_awards', a.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
}
