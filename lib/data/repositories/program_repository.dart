import 'package:sqflite/sqflite.dart';

import '../../core/clock.dart';
import '../../core/ids.dart';
import '../assets/asset_catalog.dart';
import '../db/app_database.dart';
import '../models/models.dart';

/// The user's programs and per-slot overrides (SPEC 7.1).
abstract class ProgramRepository {
  /// The active program, or null before onboarding.
  Future<ActiveProgram?> active();
  Future<List<ActiveProgram>> all();

  /// Creates a program from a shipped template and makes it the only active one. History is kept.
  Future<ActiveProgram> activateTemplate(String templateId, {int startWeek = 1});

  /// Creates a custom program (one `custom` phase) and makes it the only active one.
  Future<ActiveProgram> createCustom(ProgramTemplate custom);
  Future<void> save(ActiveProgram p);

  /// Moves the rotation pointer to the day after [completedDayId] (SPEC 6.7).
  Future<void> advanceAfter(String programId, String completedDayId);
  Future<List<ProgramOverride>> overrides(String programId);

  /// Inserts or replaces the override of (programId, dayId, slotKey).
  Future<void> setOverride(ProgramOverride o);

  /// Removes overrides of a program, or of one of its days.
  Future<void> clearOverrides(String programId, {String? dayId});
}

/// [ProgramRepository] on the `programs` and `program_overrides` tables.
class SqfliteProgramRepository implements ProgramRepository {
  SqfliteProgramRepository(this._db, this._catalog, {this._clock = const SystemClock()});

  final AppDatabase _db;
  final AssetCatalog _catalog;
  final Clock _clock;

  Database get _d => _db.db;

  Map<String, Object?> _row(ActiveProgram p) => {...p.toMap(), 'updated_at': _clock.now().millisecondsSinceEpoch};

  @override
  Future<ActiveProgram?> active() async {
    final rows = await _d.query('programs', where: 'is_active = 1', orderBy: 'updated_at DESC', limit: 1);
    return rows.isEmpty ? null : ActiveProgram.fromMap(rows.first);
  }

  @override
  Future<List<ActiveProgram>> all() async {
    final rows = await _d.query('programs', orderBy: 'started_at ASC');
    return [for (final r in rows) ActiveProgram.fromMap(r)];
  }

  Future<ActiveProgram> _insertActive(ActiveProgram p) async {
    await _d.transaction((txn) async {
      await txn.update('programs', {'is_active': 0, 'updated_at': _clock.now().millisecondsSinceEpoch},
          where: 'is_active = 1');
      await txn.insert('programs', _row(p));
    });
    return p;
  }

  @override
  Future<ActiveProgram> activateTemplate(String templateId, {int startWeek = 1}) {
    final t = _catalog.template(templateId);
    return _insertActive(ActiveProgram(
      id: newId(),
      templateId: t.programId,
      name: t.name,
      dayOrder: List.of(t.dayOrder),
      startedAt: _clock.now(),
      startWeek: startWeek,
    ));
  }

  @override
  Future<ActiveProgram> createCustom(ProgramTemplate custom) => _insertActive(ActiveProgram(
        id: newId(),
        customTemplate: custom,
        name: custom.name,
        dayOrder: List.of(custom.dayOrder),
        startedAt: _clock.now(),
      ));

  @override
  Future<void> save(ActiveProgram p) async {
    await _d.transaction((txn) async {
      if (p.isActive) {
        await txn.update('programs', {'is_active': 0}, where: 'is_active = 1 AND id != ?', whereArgs: [p.id]);
      }
      await txn.insert('programs', _row(p), conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  @override
  Future<void> advanceAfter(String programId, String completedDayId) async {
    final rows = await _d.query('programs', where: 'id = ?', whereArgs: [programId], limit: 1);
    if (rows.isEmpty) return;
    final p = ActiveProgram.fromMap(rows.first);
    final i = p.dayOrder.indexOf(completedDayId);
    if (i < 0 || p.dayOrder.isEmpty) return;
    await _d.update(
      'programs',
      {'next_day_index': (i + 1) % p.dayOrder.length, 'updated_at': _clock.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [programId],
    );
  }

  @override
  Future<List<ProgramOverride>> overrides(String programId) async {
    final rows = await _d.query('program_overrides', where: 'program_id = ?', whereArgs: [programId]);
    return [for (final r in rows) ProgramOverride.fromMap(r)];
  }

  @override
  Future<void> setOverride(ProgramOverride o) =>
      _d.insert('program_overrides', o.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<void> clearOverrides(String programId, {String? dayId}) => dayId == null
      ? _d.delete('program_overrides', where: 'program_id = ?', whereArgs: [programId])
      : _d.delete('program_overrides', where: 'program_id = ? AND day_id = ?', whereArgs: [programId, dayId]);
}
