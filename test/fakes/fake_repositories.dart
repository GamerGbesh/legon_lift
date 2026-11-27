import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:legon_lift/core/clock.dart';
import 'package:legon_lift/core/ids.dart';
import 'package:legon_lift/data/models/models.dart';
import 'package:legon_lift/data/repositories/repositories.dart';
import 'package:legon_lift/domain/api.dart';

/// In-memory [SettingsRepository].
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository({this.settings, this.profile, AppSettings? defaults})
      : _defaults = defaults ?? AppSettings.defaults(GymProfileDefaults.legon);

  final AppSettings _defaults;

  /// Saved settings (null = never saved).
  AppSettings? settings;
  UserProfile? profile;
  final Map<String, String> flags = {};

  @override
  Future<AppSettings> loadSettings() async => settings ?? _defaults;

  @override
  Future<void> saveSettings(AppSettings s) async => settings = s;

  @override
  Future<UserProfile?> loadProfile() async => profile;

  @override
  Future<void> saveProfile(UserProfile p) async => profile = p;

  @override
  Future<String?> getFlag(String key) async => flags[key];

  @override
  Future<void> setFlag(String key, String? value) async => value == null ? flags.remove(key) : flags[key] = value;
}

/// In-memory [ProgramRepository].
class FakeProgramRepository implements ProgramRepository {
  FakeProgramRepository(this._catalog, {this._clock = const SystemClock()});

  final AssetCatalog _catalog;
  final Clock _clock;
  final List<ActiveProgram> programs = [];
  final List<ProgramOverride> overrideRows = [];

  @override
  Future<ActiveProgram?> active() async => programs.where((p) => p.isActive).lastOrNull;

  @override
  Future<List<ActiveProgram>> all() async => List.of(programs);

  ActiveProgram _activate(ActiveProgram p) {
    for (var i = 0; i < programs.length; i++) {
      if (programs[i].isActive) programs[i] = programs[i].copyWith(isActive: false);
    }
    programs.add(p);
    return p;
  }

  @override
  Future<ActiveProgram> activateTemplate(String templateId, {int startWeek = 1}) async {
    final t = _catalog.template(templateId);
    return _activate(ActiveProgram(
      id: newId(),
      templateId: t.programId,
      name: t.name,
      dayOrder: List.of(t.dayOrder),
      startedAt: _clock.now(),
      startWeek: startWeek,
    ));
  }

  @override
  Future<ActiveProgram> createCustom(ProgramTemplate custom) async => _activate(ActiveProgram(
        id: newId(),
        customTemplate: custom,
        name: custom.name,
        dayOrder: List.of(custom.dayOrder),
        startedAt: _clock.now(),
      ));

  @override
  Future<void> save(ActiveProgram p) async {
    if (p.isActive) {
      for (var i = 0; i < programs.length; i++) {
        if (programs[i].isActive && programs[i].id != p.id) programs[i] = programs[i].copyWith(isActive: false);
      }
    }
    final i = programs.indexWhere((x) => x.id == p.id);
    i < 0 ? programs.add(p) : programs[i] = p;
  }

  @override
  Future<void> advanceAfter(String programId, String completedDayId) async {
    final i = programs.indexWhere((x) => x.id == programId);
    if (i < 0) return;
    final p = programs[i];
    final d = p.dayOrder.indexOf(completedDayId);
    if (d < 0) return;
    programs[i] = p.copyWith(nextDayIndex: (d + 1) % p.dayOrder.length);
  }

  @override
  Future<List<ProgramOverride>> overrides(String programId) async =>
      overrideRows.where((o) => o.programId == programId).toList();

  @override
  Future<void> setOverride(ProgramOverride o) async {
    overrideRows.removeWhere((x) => x.programId == o.programId && x.dayId == o.dayId && x.slotKey == o.slotKey);
    overrideRows.add(o);
  }

  @override
  Future<void> clearOverrides(String programId, {String? dayId}) async =>
      overrideRows.removeWhere((o) => o.programId == programId && (dayId == null || o.dayId == dayId));
}

/// In-memory [SessionRepository] with the same semantics as the sqflite one.
///
/// Volume uses `totalLoadKg` when a [catalog] is given (with [equipment]), else weight x reps.
class FakeSessionRepository implements SessionRepository {
  FakeSessionRepository({this._clock = const SystemClock(), this.catalog, EquipmentProfile? equipment})
      : _equipment = equipment ?? EquipmentProfile.fromDefaults(GymProfileDefaults.legon);

  final Clock _clock;
  final AssetCatalog? catalog;
  final EquipmentProfile _equipment;

  /// All sessions by id, in insertion order.
  final Map<String, Session> sessions = {};
  final StreamController<void> _changes = StreamController<void>.broadcast(sync: true);

  /// Number of writes (for asserting write-through).
  int writes = 0;

  void _changed() {
    writes++;
    _changes.add(null);
  }

  /// Adds a ready-made session (sample history).
  void seed(Session s) {
    sessions[s.id] = s.copyWith(totalVolumeKg: _volume(s.exercises));
  }

  @override
  Stream<void> get changes => _changes.stream;

  double _setVolume(SetLog s) {
    if (!s.countsAsWork) return 0;
    final ex = catalog?.tryExercise(s.exerciseId);
    if (ex == null) return s.weightKg * s.reps;
    return totalLoadKg(s, ex, _equipment) * s.reps * (ex.unilateral ? 2 : 1);
  }

  double _volume(List<SessionExercise> exercises) =>
      exercises.expand((e) => e.sets).fold(0.0, (sum, s) => sum + _setVolume(s));

  Session _require(String id) => sessions[id] ?? (throw StateError('Unknown session $id'));

  /// Applies [f] to the session exercise [seId]; returns the updated exercise.
  SessionExercise _updateExercise(String seId, SessionExercise Function(SessionExercise) f, {PlayerCursor? cursor}) {
    for (final s in sessions.values) {
      final i = s.exercises.indexWhere((e) => e.id == seId);
      if (i < 0) continue;
      final updated = f(s.exercises[i]);
      final exercises = [...s.exercises]..[i] = updated;
      sessions[s.id] = s.copyWith(
        exercises: exercises,
        totalVolumeKg: _volume(exercises),
        cursor: cursor == null ? null : () => cursor,
      );
      return updated;
    }
    throw StateError('Unknown session exercise $seId');
  }

  SetLog? _findSet(String setId) {
    for (final s in sessions.values) {
      for (final set in s.allSets) {
        if (set.id == setId) return set;
      }
    }
    return null;
  }

  @override
  Future<Session> start(SessionPlan plan, {required ReadinessCheck readiness}) async {
    final s = buildSessionFromPlan(plan, readiness: readiness, now: _clock.now());
    sessions[s.id] = s;
    _changed();
    return s;
  }

  @override
  Future<Session?> findInProgress() async =>
      sessions.values.where((s) => s.status == SessionStatus.inProgress).lastOrNull;

  @override
  Future<Session?> byId(String id) async => sessions[id];

  @override
  Future<void> logSet(SetLog set, PlayerCursor cursor) async {
    _updateExercise(
      set.sessionExerciseId,
      (e) => e.copyWith(sets: [...e.sets.where((x) => x.id != set.id), set]),
      cursor: cursor,
    );
    _changed();
  }

  @override
  Future<void> updateSet(SetLog set) async {
    _updateExercise(set.sessionExerciseId, (e) => e.copyWith(sets: [for (final x in e.sets) x.id == set.id ? set : x]));
    _changed();
  }

  @override
  Future<void> deleteSet(String setId) async {
    final set = _findSet(setId);
    if (set == null) return;
    _updateExercise(set.sessionExerciseId, (e) => e.copyWith(sets: e.sets.where((x) => x.id != setId).toList()));
    _changed();
  }

  @override
  Future<void> saveCursor(String sessionId, PlayerCursor cursor) async {
    sessions[sessionId] = _require(sessionId).copyWith(cursor: () => cursor);
    _changed();
  }

  @override
  Future<void> setExerciseStatus(String sessionExerciseId, SessionExerciseStatus s, {SkipReason? reason}) async {
    _updateExercise(sessionExerciseId, (e) => e.copyWith(status: s, skipReason: () => reason));
    _changed();
  }

  @override
  Future<SessionExercise> replaceExercise(String sessionExerciseId, String newExerciseId, Prescription rx) async {
    final updated = _updateExercise(
      sessionExerciseId,
      (e) => e.copyWith(
        exerciseId: newExerciseId,
        originalExerciseId: () => e.originalExerciseId ?? e.exerciseId,
        target: rx,
      ),
    );
    _changed();
    return updated;
  }

  @override
  Future<void> reorder(String sessionId, List<String> sessionExerciseIdsInOrder) async {
    final s = _require(sessionId);
    final order = {for (final (i, id) in sessionExerciseIdsInOrder.indexed) id: i};
    final exercises = [
      for (final e in s.exercises) e.copyWith(position: order[e.id] ?? (sessionExerciseIdsInOrder.length + e.position)),
    ]..sort((a, b) => a.position.compareTo(b.position));
    sessions[sessionId] = s.copyWith(exercises: [for (final (i, e) in exercises.indexed) e.copyWith(position: i)]);
    _changed();
  }

  @override
  Future<SessionExercise> addExtra(String sessionId, ExerciseStep step) async {
    final s = _require(sessionId);
    final last = s.exercises.fold(-1, (m, e) => e.position > m ? e.position : m);
    final added = sessionExerciseFromStep(sessionId, step, position: last + 1, blockType: BlockType.main);
    sessions[sessionId] = s.copyWith(exercises: [...s.exercises, added]);
    _changed();
    return added;
  }

  @override
  Future<void> removeExercise(String sessionExerciseId) async {
    for (final s in sessions.values.toList()) {
      if (!s.exercises.any((e) => e.id == sessionExerciseId)) continue;
      sessions[s.id] = s.copyWith(exercises: s.exercises.where((e) => e.id != sessionExerciseId).toList());
      _changed();
      return;
    }
  }

  @override
  Future<Session> complete(String sessionId, {int? feeling, String? note, double? bodyweightKg}) async {
    final done = _require(sessionId).copyWith(
      status: SessionStatus.completed,
      endedAt: () => _clock.now(),
      feeling: () => feeling,
      note: () => note,
      bodyweightKg: () => bodyweightKg,
      cursor: () => null,
    );
    sessions[sessionId] = done;
    _changed();
    return done;
  }

  /// Snapshots taken (the fake does not roll other fakes back).
  final List<String> undoSnapshots = [];

  @override
  Future<void> saveUndoSnapshot(String sessionId) async => undoSnapshots.add(sessionId);

  @override
  Future<bool> canDelete(String sessionId) async {
    final s = sessions[sessionId];
    if (s == null || s.status != SessionStatus.completed) return false;
    final ended = (s.endedAt ?? s.startedAt).toLocal();
    final now = _clock.now().toLocal();
    if (ended.year != now.year || ended.month != now.month || ended.day != now.day) return false;
    return !sessions.values.any((o) =>
        o.id != sessionId &&
        o.status == SessionStatus.completed &&
        (o.endedAt ?? o.startedAt).isAfter(s.endedAt ?? s.startedAt));
  }

  @override
  Future<void> deleteCompleted(String sessionId) async {
    sessions.remove(sessionId);
    _changed();
  }

  @override
  Future<void> saveReflection(String sessionId, {int? feeling, String? note, double? bodyweightKg}) async {
    sessions[sessionId] = _require(sessionId).copyWith(
      feeling: () => feeling,
      note: () => note,
      bodyweightKg: () => bodyweightKg,
    );
    _changed();
  }

  @override
  Future<void> discard(String sessionId) async {
    sessions[sessionId] = _require(sessionId).copyWith(status: SessionStatus.discarded, endedAt: () => _clock.now(), cursor: () => null);
    _changed();
  }

  List<Session> get _completedNewestFirst =>
      sessions.values.where((s) => s.status == SessionStatus.completed).toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  @override
  Future<List<SetLog>> setsFor(String exerciseId, {int limitSessions = 10, Set<SetKind>? kinds}) async {
    final withExercise =
        _completedNewestFirst.where((s) => s.allSets.any((x) => x.exerciseId == exerciseId)).take(limitSessions);
    final out = [
      for (final s in withExercise)
        ...s.allSets.where((x) => x.exerciseId == exerciseId && (kinds == null || kinds.contains(x.kind))),
    ]..sort((a, b) => a.completedAt.compareTo(b.completedAt));
    return out;
  }

  @override
  Future<List<SetLog>> lastExposure(String exerciseId, {String? excludingSessionId}) async {
    for (final s in _completedNewestFirst) {
      if (s.id == excludingSessionId) continue;
      final sets = s.allSets.where((x) => x.exerciseId == exerciseId && x.kind == SetKind.working).toList();
      if (sets.isNotEmpty) return sets..sort((a, b) => a.setIndex.compareTo(b.setIndex));
    }
    return const [];
  }

  @override
  Future<List<Session>> listCompleted({DateTime? from, DateTime? to, String? programId}) async =>
      _completedNewestFirst.reversed
          .where((s) =>
              (from == null || !s.startedAt.isBefore(from)) &&
              (to == null || s.startedAt.isBefore(to)) &&
              (programId == null || s.programId == programId))
          .toList();

  @override
  Future<int> countCompleted({required String programId, bool excludeDeload = true}) async => sessions.values
      .where((s) => s.status == SessionStatus.completed && s.programId == programId && !(excludeDeload && s.isDeload))
      .length;

  @override
  Future<DateTime?> lastCompletedAt() async {
    DateTime? last;
    for (final s in sessions.values.where((s) => s.status == SessionStatus.completed)) {
      final t = s.endedAt ?? s.startedAt;
      if (last == null || t.isAfter(last)) last = t;
    }
    return last;
  }
}

/// In-memory [ExerciseStateRepository].
class FakeExerciseStateRepository implements ExerciseStateRepository {
  final Map<String, ExerciseState> states = {};
  final Map<String, Map<PrType, PersonalRecord>> recordRows = {};
  final Map<String, ExercisePrefs> prefRows = {};

  @override
  Future<ExerciseState?> get(String exerciseId) async => states[exerciseId];

  @override
  Future<Map<String, ExerciseState>> getAll(Iterable<String> ids) async =>
      {for (final id in ids) if (states[id] != null) id: states[id]!};

  @override
  Future<void> put(ExerciseState s) async => states[s.exerciseId] = s;

  @override
  Future<List<PersonalRecord>> records(String exerciseId) async => (recordRows[exerciseId] ?? const {}).values.toList();

  @override
  Future<void> putRecord(PersonalRecord r) async => (recordRows[r.exerciseId] ??= {})[r.type] = r;

  @override
  Future<ExercisePrefs> prefs(String exerciseId) async => prefRows[exerciseId] ?? ExercisePrefs.empty(exerciseId);

  @override
  Future<void> putPrefs(ExercisePrefs p) async => prefRows[p.exerciseId] = p;

  @override
  Future<Map<String, ExercisePrefs>> allPrefs() async => Map.of(prefRows);
}

/// In-memory [BodyRepository] (one entry per date).
class FakeBodyRepository implements BodyRepository {
  final Map<String, BodyEntry> entries = {};

  List<BodyEntry> get _sorted => entries.values.toList()..sort((a, b) => a.date.compareTo(b.date));

  @override
  Future<void> upsert(BodyEntry e) async => entries[e.date] = e;

  @override
  Future<void> delete(String date) async => entries.remove(date);

  @override
  Future<List<BodyEntry>> range(String from, String to) async =>
      _sorted.where((e) => e.date.compareTo(from) >= 0 && e.date.compareTo(to) <= 0).toList();

  @override
  Future<BodyEntry?> latest() async => _sorted.lastOrNull;

  @override
  Future<BodyEntry?> first() async => _sorted.firstOrNull;
}

/// In-memory [NutritionRepository].
class FakeNutritionRepository implements NutritionRepository {
  final Map<String, NutritionDay> days = {};
  final List<CalorieAdjustment> adjustmentRows = [];

  @override
  Future<NutritionDay> day(String date) async => days[date] ?? NutritionDay.empty(date);

  @override
  Future<void> save(NutritionDay d) async => days[d.date] = d;

  @override
  Future<List<NutritionDay>> range(String from, String to) async => (days.values
          .where((d) => d.date.compareTo(from) >= 0 && d.date.compareTo(to) <= 0)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date)));

  @override
  Future<void> addCalorieAdjustment(CalorieAdjustment a) async {
    adjustmentRows.removeWhere((x) => x.id == a.id);
    adjustmentRows.add(a);
  }

  @override
  Future<List<CalorieAdjustment>> adjustments() async =>
      List.of(adjustmentRows)..sort((a, b) => a.date.compareTo(b.date));
}

/// In-memory [ActivityRepository].
class FakeActivityRepository implements ActivityRepository {
  final List<CardioLog> cardioLogs = [];
  final Map<String, Pause> pauseRows = {};

  @override
  Future<void> addCardio(CardioLog c) async {
    cardioLogs.removeWhere((x) => x.id == c.id);
    cardioLogs.add(c);
  }

  @override
  Future<List<CardioLog>> cardio(String from, String to) async => (cardioLogs
          .where((c) => c.date.compareTo(from) >= 0 && c.date.compareTo(to) <= 0)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date)));

  @override
  Future<List<Pause>> pauses() async => pauseRows.values.toList()..sort((a, b) => a.startDate.compareTo(b.startDate));

  @override
  Future<void> savePause(Pause p) async => pauseRows[p.id] = p;
}

/// In-memory [MilestoneRepository] (first award wins).
class FakeMilestoneRepository implements MilestoneRepository {
  final Map<String, MilestoneAward> awardRows = {};

  @override
  Future<List<MilestoneAward>> awards() async =>
      awardRows.values.toList()..sort((a, b) => a.awardedAt.compareTo(b.awardedAt));

  @override
  Future<void> award(MilestoneAward a) async => awardRows.putIfAbsent(a.milestoneId, () => a);
}

/// [BackupService] over the in-memory fakes: a real export / preview / import round trip.
///
/// The document has the real envelope (format, dbVersion, exportedAt, tables) but its rows are
/// model JSON, not SQLite rows. Replace clears every fake it was given (so importing
/// `BackupFormat.empty` is "Reset all data"); Merge keeps existing keys, except body entries and
/// nutrition days which the backup overwrites (the fakes keep no `updated_at`).
class FakeBackupService implements BackupService {
  FakeBackupService({
    required this.sessions,
    required this.body,
    required this.nutrition,
    this.settings,
    this.programs,
    this.exerciseStates,
    this.activity,
    this.milestones,
    this._clock = const SystemClock(),
  });

  final FakeSessionRepository sessions;
  final FakeBodyRepository body;
  final FakeNutritionRepository nutrition;
  final FakeSettingsRepository? settings;
  final FakeProgramRepository? programs;
  final FakeExerciseStateRepository? exerciseStates;
  final FakeActivityRepository? activity;
  final FakeMilestoneRepository? milestones;
  final Clock _clock;

  /// File names of the automatic backups written so far (oldest first).
  final List<String> autoBackups = [];

  /// Number of imports (assert that an action did or did not touch the data).
  int imports = 0;

  @override
  Future<Uint8List> exportJson() async {
    final st = settings;
    final pr = programs;
    final es = exerciseStates;
    final ac = activity;
    final ms = milestones;
    return Uint8List.fromList(utf8.encode(jsonEncode({
      'format': BackupFormat.format,
      'version': BackupFormat.version,
      'dbVersion': 1,
      'exportedAt': _clock.now().millisecondsSinceEpoch,
      'appVersion': '1.0.0+1',
      'tables': {
        if (st != null) ...{
          'fake_settings': [if (st.settings != null) st.settings!.toJson()],
          'fake_profile': [if (st.profile != null) st.profile!.toJson()],
          'fake_flags': [
            for (final MapEntry(:key, :value) in st.flags.entries) {'key': key, 'value': value},
          ],
        },
        if (pr != null) ...{
          'programs': [for (final p in pr.programs) p.toJson()],
          'program_overrides': [for (final o in pr.overrideRows) o.toJson()],
        },
        'sessions': [for (final s in sessions.sessions.values) s.toJson()],
        if (es != null) ...{
          'exercise_state': [for (final s in es.states.values) s.toJson()],
          'personal_records': [for (final m in es.recordRows.values) for (final r in m.values) r.toJson()],
          'exercise_prefs': [for (final p in es.prefRows.values) p.toJson()],
        },
        'body_entries': [for (final e in body.entries.values) e.toJson()],
        'nutrition_days': [for (final d in nutrition.days.values) d.toJson()],
        'calorie_adjustments': [for (final a in nutrition.adjustmentRows) a.toJson()],
        if (ac != null) ...{
          'cardio_logs': [for (final c in ac.cardioLogs) c.toJson()],
          'pauses': [for (final p in ac.pauseRows.values) p.toJson()],
        },
        if (ms != null) 'milestone_awards': [for (final a in ms.awardRows.values) a.toJson()],
      },
    })));
  }

  ({Map<String, dynamic> tables, DateTime exportedAt}) _decode(Uint8List bytes) {
    final Object? doc;
    try {
      doc = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const BackupFormatException('This file is not a Legon Lift backup.');
    }
    if (doc is! Map || doc['format'] != BackupFormat.format) {
      throw const BackupFormatException('This file is not a Legon Lift backup.');
    }
    final tables = doc['tables'];
    if (tables is! Map) throw const BackupFormatException('This backup has no data tables.');
    final exported = doc['exportedAt'];
    return (
      tables: tables.cast<String, dynamic>(),
      exportedAt: DateTime.fromMillisecondsSinceEpoch(exported is int ? exported : 0),
    );
  }

  List<Map<String, dynamic>> _rows(Map<String, dynamic> tables, String key) =>
      [for (final r in (tables[key] as List? ?? const [])) (r as Map).cast<String, dynamic>()];

  @override
  Future<ImportPreview> preview(Uint8List bytes) async {
    final (:tables, :exportedAt) = _decode(bytes);
    final s = [for (final r in _rows(tables, 'sessions')) Session.fromJson(r)];
    return ImportPreview(
      sessions: s.where((x) => x.status == SessionStatus.completed).length,
      sets: s.fold(0, (n, x) => n + x.allSets.length),
      bodyEntries: _rows(tables, 'body_entries').length,
      nutritionDays: _rows(tables, 'nutrition_days').length,
      exportedAt: exportedAt,
      dbVersion: 1,
    );
  }

  @override
  Future<void> import(Uint8List bytes, {required bool replace}) async {
    final tables = _decode(bytes).tables;
    imports++;
    List<Map<String, dynamic>> rows(String key) => _rows(tables, key);
    final st = settings;
    final pr = programs;
    final es = exerciseStates;
    final ac = activity;
    final ms = milestones;

    if (replace) {
      sessions.sessions.clear();
      body.entries.clear();
      nutrition.days.clear();
      nutrition.adjustmentRows.clear();
      if (st != null) {
        st.settings = null;
        st.profile = null;
        st.flags.clear();
      }
      pr?.programs.clear();
      pr?.overrideRows.clear();
      es?.states.clear();
      es?.recordRows.clear();
      es?.prefRows.clear();
      ac?.cardioLogs.clear();
      ac?.pauseRows.clear();
      ms?.awardRows.clear();
    }

    if (st != null) {
      for (final r in rows('fake_settings')) {
        if (st.settings == null || replace) st.settings = AppSettings.fromJson(r);
      }
      for (final r in rows('fake_profile')) {
        if (st.profile == null || replace) st.profile = UserProfile.fromJson(r);
      }
      for (final r in rows('fake_flags')) {
        st.flags.putIfAbsent('${r['key']}', () => '${r['value']}');
      }
    }
    if (pr != null) {
      final hasActive = pr.programs.any((p) => p.isActive);
      for (final r in rows('programs')) {
        final p = ActiveProgram.fromJson(r);
        if (pr.programs.any((x) => x.id == p.id)) continue;
        pr.programs.add(hasActive ? p.copyWith(isActive: false) : p);
      }
      for (final r in rows('program_overrides')) {
        final o = ProgramOverride.fromJson(r);
        final exists = pr.overrideRows
            .any((x) => x.programId == o.programId && x.dayId == o.dayId && x.slotKey == o.slotKey);
        if (!exists) pr.overrideRows.add(o);
      }
    }
    for (final r in rows('sessions')) {
      final s = Session.fromJson(r);
      if (!sessions.sessions.containsKey(s.id)) sessions.seed(s);
    }
    if (es != null) {
      for (final r in rows('exercise_state')) {
        final s = ExerciseState.fromJson(r);
        es.states.putIfAbsent(s.exerciseId, () => s);
      }
      for (final r in rows('personal_records')) {
        final rec = PersonalRecord.fromJson(r);
        (es.recordRows[rec.exerciseId] ??= {}).putIfAbsent(rec.type, () => rec);
      }
      for (final r in rows('exercise_prefs')) {
        final p = ExercisePrefs.fromJson(r);
        es.prefRows.putIfAbsent(p.exerciseId, () => p);
      }
    }
    for (final r in rows('body_entries')) {
      final e = BodyEntry.fromJson(r);
      body.entries[e.date] = e;
    }
    for (final r in rows('nutrition_days')) {
      final d = NutritionDay.fromJson(r);
      nutrition.days[d.date] = d;
    }
    for (final r in rows('calorie_adjustments')) {
      final a = CalorieAdjustment.fromJson(r);
      if (!nutrition.adjustmentRows.any((x) => x.id == a.id)) nutrition.adjustmentRows.add(a);
    }
    if (ac != null) {
      for (final r in rows('cardio_logs')) {
        final c = CardioLog.fromJson(r);
        if (!ac.cardioLogs.any((x) => x.id == c.id)) ac.cardioLogs.add(c);
      }
      for (final r in rows('pauses')) {
        final p = Pause.fromJson(r);
        ac.pauseRows.putIfAbsent(p.id, () => p);
      }
    }
    if (ms != null) {
      for (final r in rows('milestone_awards')) {
        final a = MilestoneAward.fromJson(r);
        ms.awardRows.putIfAbsent(a.milestoneId, () => a);
      }
    }
  }

  @override
  Future<String> autoBackup() async {
    final name = BackupFormat.fileNameFor(_clock.now());
    autoBackups.add(name);
    return '/fake/${BackupFormat.autoBackupDir}/$name';
  }
}
