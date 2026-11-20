import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/clock.dart';
import '../../core/ids.dart';
import '../../domain/api.dart';
import '../assets/asset_catalog.dart';
import '../db/app_database.dart';
import '../db/schema.dart';
import '../models/models.dart';

/// Workouts, their exercises and logged sets (SPEC 7.1, 8, 9.1).
///
/// Session exercises are created by [start] for every [ExerciseStep] of the plan (superset
/// members and extras included, extras last) plus the warm-up cardio and finisher items, so
/// timed cardio can be logged as a set. Mobility drills and the cool-down are not stored.
abstract class SessionRepository {
  /// Creates an `in_progress` session from [plan] with cursor [PlayerCursor.start].
  Future<Session> start(SessionPlan plan, {required ReadinessCheck readiness});

  /// The unfinished session, if any (Today's "Resume workout").
  Future<Session?> findInProgress();

  /// A session with its exercises and sets.
  Future<Session?> byId(String id);

  /// Inserts the set and saves the cursor (plus volume and `updated_at`) in ONE transaction.
  Future<void> logSet(SetLog set, PlayerCursor cursor);

  /// Edits a logged set after the fact.
  Future<void> updateSet(SetLog set);
  Future<void> deleteSet(String setId);
  Future<void> saveCursor(String sessionId, PlayerCursor cursor);
  Future<void> setExerciseStatus(String sessionExerciseId, SessionExerciseStatus s, {SkipReason? reason});

  /// Swaps the exercise of a slot; keeps the first planned id in `originalExerciseId`.
  Future<SessionExercise> replaceExercise(String sessionExerciseId, String newExerciseId, Prescription rx);

  /// Rewrites the positions of the session's exercises in the given order.
  Future<void> reorder(String sessionId, List<String> sessionExerciseIdsInOrder);

  /// Adds an exercise at the end of the session (extras, "add exercise").
  Future<SessionExercise> addExtra(String sessionId, ExerciseStep step);

  /// Marks the session completed (ended now) and clears the cursor.
  Future<Session> complete(String sessionId, {int? feeling, String? note, double? bodyweightKg});

  /// Saves the summary screen's optional reflection on a completed session (keeps `ended_at`).
  Future<void> saveReflection(String sessionId, {int? feeling, String? note, double? bodyweightKg});

  /// Marks the session discarded (kept out of history and progression).
  Future<void> discard(String sessionId);

  /// Sets of [exerciseId] from its last [limitSessions] completed sessions, oldest first,
  /// optionally filtered by [kinds].
  Future<List<SetLog>> setsFor(String exerciseId, {int limitSessions = 10, Set<SetKind>? kinds});

  /// Working sets of [exerciseId] in its most recent completed session (set order), or empty.
  Future<List<SetLog>> lastExposure(String exerciseId, {String? excludingSessionId});

  /// Completed sessions (with exercises and sets) started in [from, to), oldest first.
  Future<List<Session>> listCompleted({DateTime? from, DateTime? to, String? programId});
  Future<int> countCompleted({required String programId, bool excludeDeload = true});

  /// End time of the most recent completed session (any program).
  Future<DateTime?> lastCompletedAt();

  /// Fires after any write.
  Stream<void> get changes;
}

/// [SessionRepository] on `sessions`, `session_exercises` and `set_logs`.
///
/// `total_volume_kg` is recomputed inside every set write (SPEC 0.4 volume: totalLoadKg x reps,
/// x2 for unilateral exercises; working, test and calibration sets only), using the equipment
/// from the saved settings so a known leg-press sled weight counts.
class SqfliteSessionRepository implements SessionRepository {
  SqfliteSessionRepository(this._db, this._catalog, {this._clock = const SystemClock()});

  final AppDatabase _db;
  final AssetCatalog _catalog;
  final Clock _clock;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  Database get _d => _db.db;

  int get _nowMs => _clock.now().millisecondsSinceEpoch;

  void _changed() => _changes.add(null);

  @override
  Stream<void> get changes => _changes.stream;

  // -- reading ---------------------------------------------------------------------------------

  /// Sessions for [rows] with their exercises and sets (3 queries in total).
  Future<List<Session>> _hydrate(DatabaseExecutor ex, List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return const [];
    final ids = [for (final r in rows) r['id']! as String];
    final marks = List.filled(ids.length, '?').join(',');
    final exRows = await ex.query('session_exercises',
        where: 'session_id IN ($marks)', whereArgs: ids, orderBy: 'position ASC');
    final setRows = await ex.query('set_logs',
        where: 'session_id IN ($marks)', whereArgs: ids, orderBy: 'set_index ASC, completed_at ASC');
    final setsByExercise = <String, List<SetLog>>{};
    for (final r in setRows) {
      final set = SetLog.fromMap(r);
      (setsByExercise[set.sessionExerciseId] ??= []).add(set);
    }
    final exercisesBySession = <String, List<SessionExercise>>{};
    for (final r in exRows) {
      final e = SessionExercise.fromMap(r, sets: setsByExercise[r['id']] ?? const []);
      (exercisesBySession[e.sessionId] ??= []).add(e);
    }
    return [for (final r in rows) Session.fromMap(r, exercises: exercisesBySession[r['id']] ?? const [])];
  }

  Future<Session?> _one(DatabaseExecutor ex, String id) async {
    final rows = await ex.query('sessions', where: 'id = ?', whereArgs: [id], limit: 1);
    return (await _hydrate(ex, rows)).firstOrNull;
  }

  Future<SessionExercise> _exercise(DatabaseExecutor ex, String sessionExerciseId) async {
    final rows = await ex.query('session_exercises', where: 'id = ?', whereArgs: [sessionExerciseId], limit: 1);
    if (rows.isEmpty) throw StateError('Unknown session exercise $sessionExerciseId');
    final sets = await ex.query('set_logs',
        where: 'session_exercise_id = ?', whereArgs: [sessionExerciseId], orderBy: 'set_index ASC, completed_at ASC');
    return SessionExercise.fromMap(rows.first, sets: [for (final r in sets) SetLog.fromMap(r)]);
  }

  Future<EquipmentProfile> _equipment(DatabaseExecutor ex) async {
    final rows = await ex.query('kv', columns: ['value'], where: 'key = ?', whereArgs: [KvKeys.settings], limit: 1);
    if (rows.isEmpty) return EquipmentProfile.fromDefaults(_catalog.personalization.gym);
    final json = (jsonDecode(rows.first['value']! as String) as Map).cast<String, dynamic>();
    return AppSettings.fromJson(json).equipment;
  }

  /// Recomputes `total_volume_kg` and stamps `updated_at` for [sessionId].
  Future<void> _touch(DatabaseExecutor ex, String sessionId, {PlayerCursor? cursor}) async {
    final eq = await _equipment(ex);
    final rows = await ex.query('set_logs', where: 'session_id = ?', whereArgs: [sessionId]);
    var volume = 0.0;
    for (final r in rows) {
      final set = SetLog.fromMap(r);
      final exercise = _catalog.tryExercise(set.exerciseId);
      if (!set.countsAsWork) continue;
      volume += exercise == null
          ? set.weightKg * set.reps
          : totalLoadKg(set, exercise, eq) * set.reps * (exercise.unilateral ? 2 : 1);
    }
    await ex.update(
      'sessions',
      {
        'total_volume_kg': volume,
        'updated_at': _nowMs,
        if (cursor != null) 'cursor_json': jsonEncode(cursor.toJson()),
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  // -- writes ----------------------------------------------------------------------------------

  @override
  Future<Session> start(SessionPlan plan, {required ReadinessCheck readiness}) async {
    final s = buildSessionFromPlan(plan, readiness: readiness, now: _clock.now());
    await _d.transaction((txn) async {
      await txn.insert('sessions', {...s.toMap(), 'updated_at': _nowMs});
      for (final e in s.exercises) {
        await txn.insert('session_exercises', e.toMap());
      }
    });
    _changed();
    return s;
  }

  @override
  Future<void> logSet(SetLog set, PlayerCursor cursor) async {
    await _d.transaction((txn) async {
      await txn.insert('set_logs', set.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      await _touch(txn, set.sessionId, cursor: cursor);
    });
    _changed();
  }

  @override
  Future<void> updateSet(SetLog set) async {
    await _d.transaction((txn) async {
      await txn.update('set_logs', set.toMap(), where: 'id = ?', whereArgs: [set.id]);
      await _touch(txn, set.sessionId);
    });
    _changed();
  }

  @override
  Future<void> deleteSet(String setId) async {
    await _d.transaction((txn) async {
      final rows = await txn.query('set_logs', columns: ['session_id'], where: 'id = ?', whereArgs: [setId], limit: 1);
      if (rows.isEmpty) return;
      await txn.delete('set_logs', where: 'id = ?', whereArgs: [setId]);
      await _touch(txn, rows.first['session_id']! as String);
    });
    _changed();
  }

  @override
  Future<void> saveCursor(String sessionId, PlayerCursor cursor) async {
    await _d.update('sessions', {'cursor_json': jsonEncode(cursor.toJson()), 'updated_at': _nowMs},
        where: 'id = ?', whereArgs: [sessionId]);
    _changed();
  }

  @override
  Future<void> setExerciseStatus(String sessionExerciseId, SessionExerciseStatus s, {SkipReason? reason}) async {
    await _d.update('session_exercises', {'status': s.wire, 'skip_reason': reason?.wire},
        where: 'id = ?', whereArgs: [sessionExerciseId]);
    _changed();
  }

  @override
  Future<SessionExercise> replaceExercise(String sessionExerciseId, String newExerciseId, Prescription rx) async {
    final updated = await _d.transaction((txn) async {
      final e = await _exercise(txn, sessionExerciseId);
      await txn.update(
        'session_exercises',
        {
          'exercise_id': newExerciseId,
          'original_exercise_id': e.originalExerciseId ?? e.exerciseId,
          'target_json': jsonEncode(rx.toJson()),
        },
        where: 'id = ?',
        whereArgs: [sessionExerciseId],
      );
      return _exercise(txn, sessionExerciseId);
    });
    _changed();
    return updated;
  }

  @override
  Future<void> reorder(String sessionId, List<String> sessionExerciseIdsInOrder) async {
    await _d.transaction((txn) async {
      final rows = await txn.query('session_exercises',
          columns: ['id'], where: 'session_id = ?', whereArgs: [sessionId], orderBy: 'position ASC');
      final rest = [for (final r in rows) r['id']! as String]..removeWhere(sessionExerciseIdsInOrder.contains);
      final order = [...sessionExerciseIdsInOrder, ...rest];
      for (final (i, id) in order.indexed) {
        await txn.update('session_exercises', {'position': i},
            where: 'id = ? AND session_id = ?', whereArgs: [id, sessionId]);
      }
    });
    _changed();
  }

  @override
  Future<SessionExercise> addExtra(String sessionId, ExerciseStep step) async {
    final added = await _d.transaction((txn) async {
      final count = Sqflite.firstIntValue(
              await txn.rawQuery('SELECT COUNT(*) FROM session_exercises WHERE session_id = ?', [sessionId])) ??
          0;
      final e = sessionExerciseFromStep(sessionId, step, position: count, blockType: BlockType.main);
      await txn.insert('session_exercises', e.toMap());
      return e;
    });
    _changed();
    return added;
  }

  @override
  Future<Session> complete(String sessionId, {int? feeling, String? note, double? bodyweightKg}) async {
    final done = await _d.transaction((txn) async {
      await txn.update(
        'sessions',
        {
          'status': SessionStatus.completed.wire,
          'ended_at': _nowMs,
          'feeling': feeling,
          'note': note,
          'bodyweight_kg': bodyweightKg,
          'cursor_json': null,
          'updated_at': _nowMs,
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      return _one(txn, sessionId);
    });
    if (done == null) throw StateError('Unknown session $sessionId');
    _changed();
    return done;
  }

  @override
  Future<void> saveReflection(String sessionId, {int? feeling, String? note, double? bodyweightKg}) async {
    await _d.update(
      'sessions',
      {'feeling': feeling, 'note': note, 'bodyweight_kg': bodyweightKg, 'updated_at': _nowMs},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
    _changed();
  }

  @override
  Future<void> discard(String sessionId) async {
    await _d.update(
      'sessions',
      {'status': SessionStatus.discarded.wire, 'ended_at': _nowMs, 'cursor_json': null, 'updated_at': _nowMs},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
    _changed();
  }

  // -- queries ---------------------------------------------------------------------------------

  @override
  Future<Session?> findInProgress() async {
    final rows = await _d.query('sessions',
        where: 'status = ?', whereArgs: [SessionStatus.inProgress.wire], orderBy: 'started_at DESC', limit: 1);
    return (await _hydrate(_d, rows)).firstOrNull;
  }

  @override
  Future<Session?> byId(String id) => _one(_d, id);

  @override
  Future<List<SetLog>> setsFor(String exerciseId, {int limitSessions = 10, Set<SetKind>? kinds}) async {
    final sessionRows = await _d.rawQuery(
      'SELECT s.id FROM sessions s WHERE s.status = ? AND EXISTS '
      '(SELECT 1 FROM set_logs l WHERE l.session_id = s.id AND l.exercise_id = ?) '
      'ORDER BY s.started_at DESC LIMIT ?',
      [SessionStatus.completed.wire, exerciseId, limitSessions],
    );
    if (sessionRows.isEmpty) return const [];
    final ids = [for (final r in sessionRows) r['id']! as String];
    final kindList = kinds?.map((k) => k.wire).toList();
    final rows = await _d.query(
      'set_logs',
      where: 'exercise_id = ? AND session_id IN (${List.filled(ids.length, '?').join(',')})'
          '${kindList == null ? '' : ' AND kind IN (${List.filled(kindList.length, '?').join(',')})'}',
      whereArgs: [exerciseId, ...ids, ...?kindList],
      orderBy: 'completed_at ASC',
    );
    return [for (final r in rows) SetLog.fromMap(r)];
  }

  @override
  Future<List<SetLog>> lastExposure(String exerciseId, {String? excludingSessionId}) async {
    final sessionRows = await _d.rawQuery(
      'SELECT s.id FROM sessions s WHERE s.status = ? AND s.id != ? AND EXISTS '
      '(SELECT 1 FROM set_logs l WHERE l.session_id = s.id AND l.exercise_id = ? AND l.kind = ?) '
      'ORDER BY s.started_at DESC LIMIT 1',
      [SessionStatus.completed.wire, excludingSessionId ?? '', exerciseId, SetKind.working.wire],
    );
    if (sessionRows.isEmpty) return const [];
    final rows = await _d.query(
      'set_logs',
      where: 'session_id = ? AND exercise_id = ? AND kind = ?',
      whereArgs: [sessionRows.first['id'], exerciseId, SetKind.working.wire],
      orderBy: 'set_index ASC',
    );
    return [for (final r in rows) SetLog.fromMap(r)];
  }

  @override
  Future<List<Session>> listCompleted({DateTime? from, DateTime? to, String? programId}) async {
    final where = ['status = ?'];
    final args = <Object?>[SessionStatus.completed.wire];
    if (from != null) {
      where.add('started_at >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('started_at < ?');
      args.add(to.millisecondsSinceEpoch);
    }
    if (programId != null) {
      where.add('program_id = ?');
      args.add(programId);
    }
    final rows = await _d.query('sessions', where: where.join(' AND '), whereArgs: args, orderBy: 'started_at ASC');
    return _hydrate(_d, rows);
  }

  @override
  Future<int> countCompleted({required String programId, bool excludeDeload = true}) async =>
      Sqflite.firstIntValue(await _d.rawQuery(
        'SELECT COUNT(*) FROM sessions WHERE status = ? AND program_id = ?${excludeDeload ? ' AND is_deload = 0' : ''}',
        [SessionStatus.completed.wire, programId],
      )) ??
      0;

  @override
  Future<DateTime?> lastCompletedAt() async {
    final ms = Sqflite.firstIntValue(await _d.rawQuery(
      'SELECT MAX(COALESCE(ended_at, started_at)) FROM sessions WHERE status = ?',
      [SessionStatus.completed.wire],
    ));
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  }
}

/// Builds the new `in_progress` session for [plan] (shared by the sqflite repository and the
/// in-memory fake so both create identical rows).
Session buildSessionFromPlan(SessionPlan plan, {required ReadinessCheck readiness, required DateTime now, String? id}) {
  final sessionId = id ?? _newSessionId();
  final exercises = <SessionExercise>[];
  final extras = <ExerciseStep>[];
  for (final step in plan.steps) {
    switch (step) {
      case WarmupCardioStep(:final item):
        exercises.add(_timedExercise(sessionId, step.index, item, BlockType.warmup, exercises.length));
      case ExerciseStep():
        exercises.add(sessionExerciseFromStep(sessionId, step, position: exercises.length, blockType: BlockType.main));
      case SupersetStep(:final members, :final group):
        for (final m in members) {
          exercises.add(sessionExerciseFromStep(sessionId, m,
              position: exercises.length, blockType: BlockType.superset, supersetGroup: group, blockIndex: step.index));
        }
      case ExtrasStep(extras: final list):
        extras.addAll(list);
      case FinisherStep(:final item, :final durationSec):
        exercises.add(_timedExercise(sessionId, step.index, item, BlockType.finisher, exercises.length,
            durationSec: durationSec));
      case MobilityStep() || CooldownStep():
        break;
    }
  }
  for (final e in extras) {
    exercises.add(sessionExerciseFromStep(sessionId, e, position: exercises.length, blockType: BlockType.main));
  }
  return Session(
    id: sessionId,
    programId: plan.programId,
    templateId: plan.templateId,
    phaseId: plan.phaseId,
    trainingWeek: plan.trainingWeek,
    dayId: plan.dayId,
    dayName: plan.dayName,
    status: SessionStatus.inProgress,
    startedAt: now,
    isDeload: plan.isDeload,
    hotDay: plan.hotDay,
    readiness: readiness,
    cursor: PlayerCursor.start,
    plan: plan,
    exercises: exercises,
  );
}

/// A pending [SessionExercise] for [step].
SessionExercise sessionExerciseFromStep(
  String sessionId,
  ExerciseStep step, {
  required int position,
  required BlockType blockType,
  String? supersetGroup,
  int? blockIndex,
}) =>
    SessionExercise(
      id: _newSessionId(),
      sessionId: sessionId,
      exerciseId: step.item.exerciseId,
      slotKey: step.slotKey,
      position: position,
      blockIndex: blockIndex ?? step.index,
      blockType: blockType,
      supersetGroup: supersetGroup,
      role: step.item.role,
      target: step.rx,
    );

SessionExercise _timedExercise(String sessionId, int stepIndex, ProgramItem item, BlockType type, int position,
        {int? durationSec}) =>
    SessionExercise(
      id: _newSessionId(),
      sessionId: sessionId,
      exerciseId: item.exerciseId,
      slotKey: item.slotKey(),
      position: position,
      blockIndex: stepIndex,
      blockType: type,
      role: item.role,
      target: Prescription(
        exerciseId: item.exerciseId,
        working: [
          PlannedSet(kind: SetKind.working, weightKg: 0, reps: 0, durationSec: durationSec ?? item.durationSeconds),
        ],
        restSec: 0,
      ),
    );

String _newSessionId() => newId();
