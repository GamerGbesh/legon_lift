import 'package:sqflite/sqflite.dart';

import '../../core/clock.dart';
import '../db/app_database.dart';
import '../models/models.dart';

/// Daily nutrition checklist and calorie adjustments (SPEC 7.1, 4.9, 10.2).
abstract class NutritionRepository {
  /// The day's checklist, or [NutritionDay.empty] when untouched.
  Future<NutritionDay> day(String date);
  Future<void> save(NutritionDay d);

  /// Saved days with from <= date <= to, ascending.
  Future<List<NutritionDay>> range(String from, String to);
  Future<void> addCalorieAdjustment(CalorieAdjustment a);

  /// All adjustments, oldest first.
  Future<List<CalorieAdjustment>> adjustments();
}

/// [NutritionRepository] on `nutrition_days` and `calorie_adjustments`.
class SqfliteNutritionRepository implements NutritionRepository {
  SqfliteNutritionRepository(this._db, {this._clock = const SystemClock()});

  final AppDatabase _db;
  final Clock _clock;

  Database get _d => _db.db;

  @override
  Future<NutritionDay> day(String date) async {
    final rows = await _d.query('nutrition_days', where: 'date = ?', whereArgs: [date], limit: 1);
    return rows.isEmpty ? NutritionDay.empty(date) : NutritionDay.fromMap(rows.first);
  }

  @override
  Future<void> save(NutritionDay d) => _d.insert(
        'nutrition_days',
        {...d.toMap(), 'updated_at': _clock.now().millisecondsSinceEpoch},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  @override
  Future<List<NutritionDay>> range(String from, String to) async {
    final rows =
        await _d.query('nutrition_days', where: 'date >= ? AND date <= ?', whereArgs: [from, to], orderBy: 'date ASC');
    return [for (final r in rows) NutritionDay.fromMap(r)];
  }

  @override
  Future<void> addCalorieAdjustment(CalorieAdjustment a) =>
      _d.insert('calorie_adjustments', a.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<List<CalorieAdjustment>> adjustments() async {
    final rows = await _d.query('calorie_adjustments', orderBy: 'date ASC');
    return [for (final r in rows) CalorieAdjustment.fromMap(r)];
  }
}
