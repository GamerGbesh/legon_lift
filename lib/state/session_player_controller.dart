// Owner: WS3. The session player state machine (SPEC 4.4, 8).
//
// The database is the source of truth: every event writes first, then the controller reloads the
// session and re-derives what to show. The only persisted player state is the [PlayerCursor]
// (`sessions.cursor_json`): the current stop, a set pointer inside it, the rest/timer deadline,
// the live find-your-weight state and the finished warm-up/cool-down stops. Everything else
// (rows, ramp progress, prefills, skipped sets) is derived from the plan snapshot, the
// session's exercises (`target` = the prescription) and the logged sets, so killing the app at
// any moment loses nothing.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/clock.dart';
import '../core/format.dart';
import '../core/ids.dart';
import '../data/assets/asset_catalog.dart';
import '../data/models/models.dart';
import '../data/repositories/exercise_state_repository.dart';
import '../data/repositories/program_repository.dart';
import '../data/repositories/session_repository.dart';
import '../domain/api.dart';
import '../services/api.dart';
import 'milestone_store.dart';
import 'settings_store.dart';

/// Fixed player timings (SPEC 6 constants, 4.4).
abstract final class PlayerTiming {
  /// Rest after a warm-up set (SPEC 6.3).
  static const int warmupRestSec = 45;

  /// Rest after a find-your-weight ramp set (SPEC 6.2).
  static const int rampRestSec = 75;

  /// "Wait 2 min / ask to work in".
  static const int waitSec = 120;

  /// Light haptic when this many seconds of rest are left.
  static const int warnAtSec = 10;

  /// Rest change of the -15 / +15 buttons.
  static const int adjustSec = 15;

  /// Timers at least this long also schedule the background notification.
  static const int notifyTimerAtSec = 60;
}

enum PlayerStatus { loading, missing, playing, finishing, completed, discarded }

/// Slot key prefix of exercises the user added during the session ("Add an exercise"):
/// `added:1`, `added:2`, ... in the order they were added. They are not in the plan snapshot and
/// can be removed again; the plan's own exercises can only be swapped or skipped.
const String addedSlotPrefix = 'added:';

bool isAddedSlot(String slotKey) => slotKey.startsWith(addedSlotPrefix);

int _addedNumber(String slotKey) => int.tryParse(slotKey.substring(addedSlotPrefix.length)) ?? 0;

/// What a stop of the player is. A stop is one screen of the flow; extras are one stop each.
enum StopKind {
  warmupCardio,
  mobility,
  exercise,
  superset,
  extra,
  finisher,
  cooldown;

  /// Has set rows (as opposed to a timer or checklist).
  bool get hasSets => this == exercise || this == superset || this == extra;

  /// Main work that can be reordered ("Do the next exercise first").
  bool get isMain => this == exercise || this == superset;
}

enum StopState { pending, done, skipped }

enum RowState { logged, skipped, active, pending }

/// Scope of a swap: today only, the program slot, or "not at this gym" (hidden + program).
enum SwapScope { today, program, notAtGym }

enum RestKind { rest, wait }

/// One screen of the player flow.
@immutable
class PlayerStop {
  const PlayerStop({
    required this.id,
    required this.kind,
    required this.step,
    this.members = const [],
    this.exercises = const [],
    this.items = const [],
    this.extraNumber,
    this.extraCount,
    this.mainRank,
    required this.state,
  });

  /// Stable id: position in the plan-order stop list (stored in [PlayerCursor.stepIndex]).
  final int id;
  final StopKind kind;

  /// The plan step this stop comes from.
  final SessionStep step;

  /// Exercise steps of a set-based stop (1, or the superset members), aligned with [exercises].
  final List<ExerciseStep> members;

  /// Session rows: the members' rows, or the timed cardio row of a warm-up/finisher stop.
  final List<SessionExercise> exercises;

  /// Program items of a timed or checklist stop.
  final List<ProgramItem> items;

  /// 1-based number and count for extras ("Extra 1 of 2").
  final int? extraNumber, extraCount;

  /// Original order among the main stops (for the "a primary moves at most 1 slot" rule).
  final int? mainRank;
  final StopState state;

  bool get isPending => state == StopState.pending;

  /// The main session exercise of a single-exercise stop or timed cardio stop.
  SessionExercise? get exercise => exercises.isEmpty ? null : exercises.first;

  /// An exercise the user added during the session (removable).
  bool get isAdded => kind == StopKind.exercise && (exercise != null && isAddedSlot(exercise!.slotKey));

  /// Lowest session position (display order of set-based stops).
  int? get position => exercises.isEmpty ? null : exercises.map((e) => e.position).reduce(math.min);
}

/// One row of the set table.
@immutable
class SetRow {
  const SetRow({
    required this.se,
    required this.exercise,
    required this.member,
    required this.slot,
    required this.setIndex,
    required this.kind,
    required this.label,
    required this.weightKg,
    required this.reps,
    this.durationSec,
    this.targetRir,
    this.log,
    required this.state,
    this.previous,
    this.workingNumber,
  });

  final SessionExercise se;
  final Exercise exercise;

  /// Member index inside a superset (0 otherwise).
  final int member;

  /// Position in the stop's set sequence (the cursor's set pointer).
  final int slot;

  /// Value stored as [SetLog.setIndex].
  final int setIndex;
  final SetKind kind;

  /// "W1", "F2", "3", "A2".
  final String label;

  /// Target / prefill (one dumbbell, total bar, added plates, pin). 0 when not loaded.
  final double weightKg;
  final int reps;
  final int? durationSec;
  final int? targetRir;
  final SetLog? log;
  final RowState state;

  /// The same working set last time ("20 × 12").
  final SetLog? previous;

  /// 1-based number among the working sets (null for warm-up and ramp rows).
  final int? workingNumber;

  bool get isWarmup => kind == SetKind.warmup;
  bool get isRamp => kind == SetKind.ramp;
  bool get isTimed => exercise.tracking == Tracking.time;
}

/// The rest sheet (also used for the 2-minute "machine busy" wait).
@immutable
class RestInfo {
  const RestInfo({required this.kind, this.endsAt, required this.totalSec, this.questions = const [], this.calibration});

  final RestKind kind;

  /// Null when the automatic rest timer is off (the sheet then only asks its questions).
  final DateTime? endsAt;
  final int totalSec;

  /// Logged sets waiting for "How many more could you have done?" (optional answers).
  final List<SetLog> questions;

  /// A calibration set waiting for its extra reps (SPEC 6.6).
  final SetLog? calibration;

  int remainingSec(DateTime now) {
    final end = endsAt;
    if (end == null) return 0;
    final ms = end.difference(now).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  bool isOver(DateTime now) => endsAt != null && remainingSec(now) == 0;
}

/// The timer of a timed stop item (warm-up cardio, drills, finisher, cool-down).
@immutable
class StopTimer {
  const StopTimer({
    required this.item,
    required this.exercise,
    required this.itemIndex,
    required this.itemCount,
    required this.round,
    required this.rounds,
    this.totalSec,
    this.endsAt,
    this.pausedRemainingSec,
  });

  final ProgramItem item;
  final Exercise exercise;

  /// Position inside the (repeated) item list and its length.
  final int itemIndex, itemCount;

  /// 1-based round for drills done twice ("No machine free").
  final int round, rounds;

  /// Null for rep-based checklist items.
  final int? totalSec;
  final DateTime? endsAt;
  final int? pausedRemainingSec;

  bool get isTimed => totalSec != null;
  bool get running => endsAt != null;
  bool get started => endsAt != null || pausedRemainingSec != null;

  int remainingSec(DateTime now) {
    final end = endsAt;
    if (end != null) {
      final ms = end.difference(now).inMilliseconds;
      return ms <= 0 ? 0 : (ms / 1000).ceil();
    }
    return pausedRemainingSec ?? totalSec ?? 0;
  }
}

/// A live hold timer for a timed set inside an exercise (planks).
@immutable
class HoldTimer {
  const HoldTimer({required this.setIndex, required this.totalSec, this.endsAt, this.pausedRemainingSec});

  final int setIndex;
  final int totalSec;
  final DateTime? endsAt;
  final int? pausedRemainingSec;

  bool get running => endsAt != null;

  int remainingSec(DateTime now) {
    final end = endsAt;
    if (end != null) {
      final ms = end.difference(now).inMilliseconds;
      return ms <= 0 ? 0 : (ms / 1000).ceil();
    }
    return pausedRemainingSec ?? totalSec;
  }
}

/// Result of a ramp replay (SPEC 6.2): still ramping at [state], or done at [workingKg].
@immutable
class RampProgress {
  const RampProgress.ongoing(FindWeightState this.state) : workingKg = null;
  const RampProgress.done(double this.workingKg) : state = null;

  final FindWeightState? state;
  final double? workingKg;

  bool get isDone => workingKg != null;
}

/// What "Undo" reverts: the last logged set and the cursor before it.
@immutable
class _Undo {
  const _Undo({required this.set, required this.cursorBefore, required this.statusesBefore, required this.questionsBefore});

  final SetLog set;
  final PlayerCursor cursorBefore;
  final Map<String, SessionExerciseStatus> statusesBefore;
  final List<String> questionsBefore;
}

/// Drives one workout in the player route (created per `PlayerScreen`).
class SessionPlayerController extends ChangeNotifier {
  SessionPlayerController({
    required this.sessionId,
    required this._catalog,
    required this._sessions,
    required this._states,
    required this._programs,
    required this._settings,
    required this._milestones,
    required this._restAlarm,
    required this._sound,
    required this._haptics,
    required this._wakelock,
    required this._clock,
  });

  final String sessionId;
  final AssetCatalog _catalog;
  final SessionRepository _sessions;
  final ExerciseStateRepository _states;
  final ProgramRepository _programs;
  final SettingsStore _settings;
  final MilestoneStore _milestones;
  final RestAlarm _restAlarm;
  final SoundService _sound;
  final HapticsService _haptics;
  final WakelockService _wakelock;
  final Clock _clock;

  PlayerStatus _status = PlayerStatus.loading;
  Session? _session;
  PlayerCursor _cursor = PlayerCursor.start;
  List<PlayerStop> _stops = const [];
  List<PlayerStop> _display = const [];
  Phase? _phase;
  Map<String, ExercisePrefs> _prefs = {};
  Map<String, ExerciseState> _exerciseStates = {};
  final Map<String, List<SetLog>> _previous = {};

  // Transient (in-memory) state. Losing it on a kill is harmless.
  bool _busy = false;
  bool _disposed = false;
  bool _permissionAsked = false;
  final Map<String, (double?, int?)> _drafts = {};
  List<String> _questions = const [];
  RestKind _restKind = RestKind.rest;
  int _restTotalSec = 0;
  bool _restWarned = false, _restSignalled = false;
  bool _questionOnlySheet = false;
  int? _timerPausedRemaining;
  bool _halfBeeped = false;
  HoldTimer? _hold;
  int _drillRounds = 1;
  Timer? _ticker;
  _Undo? _undo;
  String? _message;

  // ------------------------------------------------------------------------------------------
  // Public state
  // ------------------------------------------------------------------------------------------

  PlayerStatus get status => _status;

  /// The session being played (null while loading or when it no longer exists).
  Session? get session => _session;
  bool get loading => _status == PlayerStatus.loading;
  AssetCatalog get catalog => _catalog;
  AppSettings get settings => _settings.settings;
  EquipmentProfile get equipment => _settings.settings.equipment;
  PlayerCursor get cursor => _cursor;
  DateTime get now => _clock.now();

  /// True while an event is being written (buttons ignore taps).
  bool get busy => _busy;

  /// The phase of the session (for swap suggestions); null for unknown programs.
  Phase? get phase => _phase;

  /// Stops in the order they are played.
  List<PlayerStop> get stops => _display;

  PlayerStop? get currentStop => _stopById(_cursor.stepIndex);

  /// Time since the session started.
  Duration get elapsed {
    final s = _session;
    if (s == null) return Duration.zero;
    final d = now.difference(s.startedAt);
    return d.isNegative ? Duration.zero : d;
  }

  /// A one-off message for a snackbar (read with [takeMessage]).
  String? get message => _message;

  String? takeMessage() {
    final m = _message;
    _message = null;
    return m;
  }

  /// True when the last logged set can still be undone.
  bool get canUndo => _undo != null;

  ExercisePrefs prefsFor(String exerciseId) => _prefs[exerciseId] ?? ExercisePrefs.empty(exerciseId);

  ExerciseState? stateFor(String exerciseId) => _exerciseStates[exerciseId];

  /// Working sets of [exerciseId] last time (the "PREVIOUS" column).
  List<SetLog> previousFor(String exerciseId) => _previous[exerciseId] ?? const [];

  Exercise exerciseOf(SessionExercise se) => _catalog.exercise(se.exerciseId);

  /// Plain title of a stop ("Warm-up", "Incline Dumbbell Press", "Pair: Pushdown + Plank").
  String stopTitle(PlayerStop stop) => switch (stop.kind) {
        StopKind.warmupCardio => 'Warm-up: ${_name(stop.items.first.exerciseId)}',
        StopKind.mobility => 'Warm-up drills',
        StopKind.exercise || StopKind.extra => _name(stop.exercise?.exerciseId ?? stop.members.first.item.exerciseId),
        StopKind.superset => 'Pair: ${stop.exercises.map((e) => _name(e.exerciseId)).join(' + ')}',
        StopKind.finisher => 'Finisher: ${_name(stop.items.first.exerciseId)}',
        StopKind.cooldown => 'Cool-down',
      };

  String _name(String exerciseId) => _catalog.tryExercise(exerciseId)?.name ?? exerciseId;

  /// The rows of [stop] (the current stop when null).
  List<SetRow> rowsOf([PlayerStop? stop]) {
    final s = stop ?? currentStop;
    if (s == null || !s.kind.hasSets) return const [];
    return _rows(s);
  }

  /// The row waiting to be logged, if any.
  SetRow? get activeRow => rowsOf().where((r) => r.state == RowState.active).firstOrNull;

  /// The ramp state of the current stop's active exercise while it is finding its weight.
  RampProgress? rampOf(SessionExercise se) {
    final stop = _stopForSe(se.id);
    if (stop == null) return null;
    final m = stop.exercises.indexWhere((e) => e.id == se.id);
    if (m < 0) return null;
    return _ramp(stop, m);
  }

  /// True when the current stop's active exercise is in "find your weight" mode.
  bool get findingWeight => activeRow?.isRamp ?? false;

  /// The draft weight/reps of the active row (what the steppers show).
  double get draftWeight {
    final row = activeRow;
    if (row == null) return 0;
    return _drafts[_draftKey(row)]?.$1 ?? row.weightKg;
  }

  /// Reps of the active row; seconds for a timed set (planks).
  int get draftReps {
    final row = activeRow;
    if (row == null) return 0;
    return _drafts[_draftKey(row)]?.$2 ?? (row.isTimed ? row.durationSec ?? 0 : row.reps);
  }

  /// Stepper step for [row]'s weight (the rounding step of its load type, SPEC 6.1).
  double weightStepFor(SetRow row) {
    final stop = _stopForSe(row.se.id);
    final m = stop?.exercises.indexWhere((e) => e.id == row.se.id) ?? -1;
    return weightStep(row.exercise, item: stop == null || m < 0 ? null : _itemFor(stop, m));
  }

  /// Stepper step for [ex]'s weight (the rounding step of its load type, SPEC 6.1).
  double weightStep(Exercise ex, {ProgramItem? item}) {
    switch (ex.loadType) {
      case LoadType.dumbbell:
        final loads = availableLoads(ex, equipment, prefsFor(ex.id));
        if (loads.length >= 2) {
          var step = double.infinity;
          for (var i = 1; i < loads.length; i++) {
            step = math.min(step, loads[i] - loads[i - 1]);
          }
          if (step.isFinite && step > 0) return step;
        }
        return 2;
      case LoadType.smith || LoadType.barbell || LoadType.plateLoaded:
        final plates = equipment.platesKg;
        return plates.isEmpty ? 2.5 : 2 * plates.reduce(math.min);
      case LoadType.stack || LoadType.cable:
        return increment(ex, item, prefsFor(ex.id));
      case LoadType.bodyweight || LoadType.time:
        return 1;
    }
  }

  /// The rest sheet, when shown.
  RestInfo? get rest {
    final stop = currentStop;
    if (_status != PlayerStatus.playing || stop == null) return null;
    final ends = stop.kind.hasSets || _restKind == RestKind.wait ? _cursor.restEndsAt : null;
    if (ends == null && !_questionOnlySheet) return null;
    final questions = <SetLog>[];
    SetLog? calibration;
    for (final id in _questions) {
      final set = _setById(id);
      if (set == null) continue;
      if (set.kind == SetKind.calibration && set.calibrationExtraReps == null) calibration = set;
      questions.add(set);
    }
    return RestInfo(
      kind: _restKind,
      endsAt: ends,
      totalSec: _restTotalSec > 0 ? _restTotalSec : (ends == null ? 0 : math.max(0, ends.difference(now).inSeconds)),
      questions: questions,
      calibration: calibration,
    );
  }

  /// The in-session suggestion for the next set of the exercise just logged (SPEC 6.4).
  InSessionHint? get hint {
    final r = rest;
    if (r == null) return null;
    final set = r.questions.lastOrNull ?? _undo?.set;
    if (set == null || set.kind != SetKind.working) return null;
    final se = _seById(set.sessionExerciseId);
    if (se == null) return null;
    final h = _hintAfter(se, set);
    if (h == null) return null;
    if (!h.automatic && _hasPain(se)) return null;
    return h;
  }

  /// "Set 3 · 22.5 kg × 10" for the rest sheet and the notification.
  String? get nextLabel {
    final row = activeRow;
    final stop = currentStop;
    if (stop == null) return null;
    if (row == null) return stopTitle(stop);
    final ex = row.exercise;
    final weight = ex.isLoaded ? _weightText(_drafts[_draftKey(row)]?.$1 ?? row.weightKg, ex) : null;
    final amount = row.isTimed ? Fmt.clock(row.durationSec ?? 0) : '${row.reps}';
    final what = switch (row.kind) {
      SetKind.warmup => 'Warm-up ${row.label.substring(1)}',
      SetKind.ramp => 'Find your weight ${row.label.substring(1)}',
      _ => stop.kind == StopKind.superset ? '${ex.name} ${row.label}' : 'Set ${row.label}',
    };
    final sameExercise = _undo?.set.exerciseId == ex.id;
    final prefix = sameExercise || stop.kind == StopKind.superset ? what : '${ex.name}: $what';
    return [prefix, if (weight != null && weight.isNotEmpty) '$weight × $amount' else amount].join(' · ');
  }

  /// The stop after the current one, for "Up next" and the rest sheet's next exercise card.
  PlayerStop? get upNext {
    final c = currentStop;
    return c == null ? null : _nextPendingAfter(c);
  }

  /// The timer of the current timed stop.
  StopTimer? get stopTimer {
    final stop = currentStop;
    if (stop == null || stop.kind.hasSets) return null;
    final list = _timedItems(stop);
    if (list.isEmpty) return null;
    final i = _cursor.setIndex.clamp(0, list.length - 1);
    final item = list[i];
    final ex = _catalog.tryExercise(item.exerciseId);
    if (ex == null) return null;
    return StopTimer(
      item: item,
      exercise: ex,
      itemIndex: i,
      itemCount: list.length,
      round: stop.kind == StopKind.mobility ? (i ~/ stop.items.length) + 1 : 1,
      rounds: stop.kind == StopKind.mobility ? _drillRounds : 1,
      totalSec: _itemSeconds(stop, item),
      endsAt: _cursor.restEndsAt,
      pausedRemainingSec: _timerPausedRemaining,
    );
  }

  /// The hold timer of a timed set (planks) in an exercise stop.
  HoldTimer? get hold => _hold;

  /// Number of finished stops and the total (segmented progress bar).
  (int, int) get progress => (_display.where((s) => !s.isPending).length, _display.length);

  /// The "find your weight" target reps of [se] (banner text), when ramping.
  int? rampTargetReps(SessionExercise se) => rampOf(se)?.state?.targetReps;

  /// True when [stop] may use "Do the next exercise first".
  bool canDoNextFirst([PlayerStop? stop]) {
    final s = stop ?? currentStop;
    if (s == null || !s.kind.isMain) return false;
    if (_nextMainAfter(s) == null) return false;
    final isPrimary = s.members.any((m) => m.item.role == ItemRole.primary);
    if (!isPrimary) return true;
    final mains = _display.where((x) => x.kind.isMain).toList();
    final rank = mains.indexWhere((x) => x.id == s.id);
    return rank - (s.mainRank ?? rank) < 1;
  }

  /// True when the current stop is the last pending set-based stop (the "busy" exits change).
  bool get isLastExercise {
    final s = currentStop;
    return s != null && s.kind.hasSets && _nextMainAfter(s) == null;
  }

  // ------------------------------------------------------------------------------------------
  // Loading
  // ------------------------------------------------------------------------------------------

  /// Rebuilds the player from the DB (plan snapshot + sets + cursor). Called once by PlayerScreen.
  Future<void> load() async {
    _status = PlayerStatus.loading;
    _notify();
    final s = await _sessions.byId(sessionId);
    if (s == null) {
      _status = PlayerStatus.missing;
      _notify();
      return;
    }
    if (s.status != SessionStatus.inProgress) {
      _session = s;
      _status = s.status == SessionStatus.completed ? PlayerStatus.completed : PlayerStatus.discarded;
      _notify();
      return;
    }
    _session = s;
    _cursor = s.cursor ?? PlayerCursor.start;
    await _loadContext(s);
    _rebuild();
    _status = PlayerStatus.playing;

    // Resume: same stop and set; a rest that ended while the app was dead shows "Rest over" at once.
    final stop = currentStop;
    if (stop == null || !stop.isPending) {
      final next = _firstPending();
      if (next == null) {
        await _finish();
        return;
      }
      await _moveTo(next, keepRest: false);
    }
    final ends = _cursor.restEndsAt;
    if (ends != null) {
      if (currentStop?.kind.hasSets ?? false) {
        _restTotalSec = math.max(ends.difference(now).inSeconds, 0);
        _restSignalled = !ends.isAfter(now);
        _restWarned = _restSignalled;
      } else if (!ends.isAfter(now)) {
        await _timerFinished(silent: true);
      }
    }
    if (settings.keepAwake) await _wakelock.enable();
    _syncTicker();
    _notify();
  }

  Future<void> _loadContext(Session s) async {
    final ids = {for (final e in s.exercises) e.exerciseId, ...s.plan.exerciseSteps.map((x) => x.item.exerciseId)};
    _prefs = await _states.allPrefs();
    _exerciseStates = await _states.getAll(ids);
    for (final id in ids) {
      _previous[id] = await _sessions.lastExposure(id, excludingSessionId: s.id);
    }
    _phase = await _resolvePhase(s);
  }

  Future<Phase?> _resolvePhase(Session s) async {
    ProgramTemplate? template;
    final programs = await _programs.all();
    final program = programs.where((p) => p.id == s.programId).firstOrNull;
    template = program?.customTemplate;
    final templateId = s.templateId ?? program?.templateId;
    if (template == null && templateId != null) {
      template = _catalog.templates.where((t) => t.programId == templateId).firstOrNull;
    }
    if (template == null) return null;
    return template.phases.where((p) => p.phaseId == s.plan.phaseId).firstOrNull ??
        phaseFor(template, s.trainingWeek);
  }

  Future<void> _reload() async {
    final s = await _sessions.byId(sessionId);
    if (s == null) return;
    _session = s;
    _rebuild();
  }

  // ------------------------------------------------------------------------------------------
  // Stops
  // ------------------------------------------------------------------------------------------

  void _rebuild() {
    final s = _session;
    if (s == null) return;
    final pool = [...s.exercises]..sort((a, b) => a.position.compareTo(b.position));
    final claimed = <String>{};

    SessionExercise? claim(int stepIndex, String slotKey) {
      final se = pool.where((e) => !claimed.contains(e.id) && e.slotKey == slotKey && e.blockIndex == stepIndex).firstOrNull ??
          pool.where((e) => !claimed.contains(e.id) && e.slotKey == slotKey).firstOrNull;
      if (se != null) claimed.add(se.id);
      return se;
    }

    final visited = _cursor.visitedSteps;
    StopState visitState(int id) =>
        visited.contains(id) ? StopState.done : (visited.contains(-(id + 1)) ? StopState.skipped : StopState.pending);
    StopState seState(List<SessionExercise> list, int id) {
      if (list.isEmpty) return visitState(id);
      if (list.any((e) => e.status == SessionExerciseStatus.pending || e.status == SessionExerciseStatus.active)) {
        return StopState.pending;
      }
      return list.any((e) => e.status == SessionExerciseStatus.done) ? StopState.done : StopState.skipped;
    }

    final stops = <PlayerStop>[];
    var mainRank = 0;
    for (final step in s.plan.steps) {
      switch (step) {
        case WarmupCardioStep(:final item):
          final se = claim(step.index, item.slotKey());
          final list = [?se];
          stops.add(PlayerStop(
              id: stops.length,
              kind: StopKind.warmupCardio,
              step: step,
              exercises: list,
              items: [item],
              state: seState(list, stops.length)));
        case MobilityStep(:final items):
          stops.add(PlayerStop(
              id: stops.length, kind: StopKind.mobility, step: step, items: items, state: visitState(stops.length)));
        case ExerciseStep():
          final se = claim(step.index, step.slotKey);
          if (se == null) continue;
          stops.add(PlayerStop(
              id: stops.length,
              kind: StopKind.exercise,
              step: step,
              members: [step],
              exercises: [se],
              mainRank: mainRank++,
              state: seState([se], stops.length)));
        case SupersetStep(:final members):
          final ms = <ExerciseStep>[];
          final ses = <SessionExercise>[];
          for (final m in members) {
            final se = claim(step.index, m.slotKey);
            if (se == null) continue;
            ms.add(m);
            ses.add(se);
          }
          if (ses.isEmpty) continue;
          stops.add(PlayerStop(
              id: stops.length,
              kind: StopKind.superset,
              step: step,
              members: ms,
              exercises: ses,
              mainRank: mainRank++,
              state: seState(ses, stops.length)));
        case ExtrasStep(:final extras):
          final pairs = <(ExerciseStep, SessionExercise)>[];
          for (final e in extras) {
            final se = claim(e.index, e.slotKey);
            if (se != null) pairs.add((e, se));
          }
          for (final (i, (e, se)) in pairs.indexed) {
            stops.add(PlayerStop(
                id: stops.length,
                kind: StopKind.extra,
                step: step,
                members: [e],
                exercises: [se],
                extraNumber: i + 1,
                extraCount: pairs.length,
                state: seState([se], stops.length)));
          }
        case FinisherStep(:final item):
          final se = claim(step.index, item.slotKey());
          final list = [?se];
          stops.add(PlayerStop(
              id: stops.length,
              kind: StopKind.finisher,
              step: step,
              exercises: list,
              items: [item],
              state: seState(list, stops.length)));
        case CooldownStep(:final items):
          stops.add(PlayerStop(
              id: stops.length, kind: StopKind.cooldown, step: step, items: items, state: visitState(stops.length)));
      }
    }
    // Exercises added during the session: one stop each, after the plan's stops so the plan's
    // stop ids never shift, in the order they were added.
    final planCount = stops.length;
    final added = pool.where((e) => !claimed.contains(e.id) && isAddedSlot(e.slotKey)).toList()
      ..sort((a, b) => _addedNumber(a.slotKey).compareTo(_addedNumber(b.slotKey)));
    for (final se in added) {
      final ex = _catalog.tryExercise(se.exerciseId);
      if (ex == null) continue;
      final step = ExerciseStep(
          index: -1, item: _addedItem(ex, sets: se.target.working.length, role: se.role), rx: se.target, slotKey: se.slotKey);
      stops.add(PlayerStop(
          id: stops.length,
          kind: StopKind.exercise,
          step: step,
          members: [step],
          exercises: [se],
          state: seState([se], stops.length)));
    }
    _stops = stops;

    // Display order: plan order with the added stops joining the main work, and the main stops
    // re-sorted by their session positions ("Do the next exercise first" and "Add an exercise"
    // change those).
    final display = [...stops.take(planCount)];
    final lastMain = display.lastIndexWhere((st) => st.kind.isMain);
    var at = lastMain >= 0
        ? lastMain + 1
        : display.indexWhere((st) => st.kind == StopKind.extra || st.kind == StopKind.finisher || st.kind == StopKind.cooldown);
    if (at < 0) at = display.length;
    display.insertAll(at, stops.skip(planCount));
    final mainSlots = [for (final (i, st) in display.indexed) if (st.kind.isMain) i];
    final mains = [for (final i in mainSlots) display[i]]
      ..sort((a, b) => (a.position ?? 0).compareTo(b.position ?? 0));
    for (final (k, i) in mainSlots.indexed) {
      display[i] = mains[k];
    }
    _display = display;
  }

  PlayerStop? _stopById(int id) => _stops.where((s) => s.id == id).firstOrNull;

  PlayerStop? _stopForSe(String seId) => _stops.where((s) => s.exercises.any((e) => e.id == seId)).firstOrNull;

  SessionExercise? _seById(String id) => _session?.exercises.where((e) => e.id == id).firstOrNull;

  SetLog? _setById(String id) => _session?.allSets.where((s) => s.id == id).firstOrNull;

  int _displayIndex(PlayerStop s) => _display.indexWhere((x) => x.id == s.id);

  PlayerStop? _firstPending() => _display.where((s) => s.isPending).firstOrNull;

  /// The next stop to play after [from]: the first pending stop after it, except that pending
  /// exercises skipped over earlier come before the finisher and the cool-down.
  PlayerStop? _nextPendingAfter(PlayerStop from) {
    final i = _displayIndex(from);
    final after = _display.skip(i + 1).where((s) => s.isPending && s.id != from.id).firstOrNull;
    final earlierWork =
        _display.take(math.max(i, 0)).where((s) => s.isPending && s.kind.hasSets && s.id != from.id).firstOrNull;
    if (after == null) return earlierWork ?? _display.where((s) => s.isPending && s.id != from.id).firstOrNull;
    if (earlierWork != null && !after.kind.hasSets) return earlierWork;
    return after;
  }

  PlayerStop? _nextMainAfter(PlayerStop from) {
    final i = _displayIndex(from);
    return _display.skip(i + 1).where((s) => s.kind.isMain && s.isPending).firstOrNull;
  }

  // ------------------------------------------------------------------------------------------
  // Rows
  // ------------------------------------------------------------------------------------------

  String _draftKey(SetRow r) => '${r.se.id}:${r.kind.wire}:${r.setIndex}';

  ExerciseStep _memberStep(PlayerStop stop, int m) => stop.members[m];

  ProgramItem _itemFor(PlayerStop stop, int m) {
    final se = stop.exercises[m];
    return _memberStep(stop, m).item.copyWith(exerciseId: se.exerciseId);
  }

  List<SetLog> _logsOf(SessionExercise se) =>
      se.sets.where((s) => s.exerciseId == se.exerciseId).toList()..sort((a, b) => a.setIndex.compareTo(b.setIndex));

  bool _hasPain(SessionExercise se) => _logsOf(se).any((s) => s.painFlag);

  /// Replays the logged ramp sets through the find-your-weight rules (SPEC 6.2). Null when the
  /// exercise is not finding its weight.
  RampProgress? _ramp(PlayerStop stop, int m) {
    final se = stop.exercises[m];
    final ex = _catalog.tryExercise(se.exerciseId);
    if (ex == null || !se.target.findWeight || !ex.isLoaded) return null;
    final item = _itemFor(stop, m);
    final seed = se.target.working.firstOrNull?.weightKg;
    var state = startFindWeight(ex, item, se.target.targetRir ?? 3, equipment,
        lastKnownKg: seed != null && seed > 0 ? seed : null);
    for (final log in _logsOf(se).where((s) => s.kind == SetKind.ramp)) {
      state = state.copyWith(currentKg: log.weightKg);
      final r = findWeightStep(state, log.reps, log.rir, log.painFlag, ex, equipment);
      switch (r) {
        case RampDone(:final workingKg):
          return RampProgress.done(workingKg);
        case RampNext(:final nextKg):
          state = state.copyWith(previousKg: () => state.currentKg, currentKg: nextKg, step: state.step + 1);
      }
    }
    return RampProgress.ongoing(state);
  }

  /// Planned working sets of [se] (after add/remove set). In find-your-weight mode the
  /// prescription already holds `max(1, sets - 1)` working sets (the find tries make up the
  /// rest), so it is not reduced again here.
  int _plannedWorking(SessionExercise se) => se.target.working.length;

  InSessionHint? _hintAfter(SessionExercise se, SetLog last) {
    final stop = _stopForSe(se.id);
    if (stop == null) return null;
    final m = stop.exercises.indexWhere((e) => e.id == se.id);
    final ex = _catalog.tryExercise(se.exerciseId);
    if (m < 0 || ex == null || !ex.isLoaded) return null;
    final working = _logsOf(se).where((s) => s.kind == SetKind.working).toList();
    final number = working.indexWhere((s) => s.id == last.id) + 1;
    if (number <= 0) return null;
    return inSessionHint(last, number, _itemFor(stop, m), se.target.targetRir, ex, equipment);
  }

  /// Rows of member [m] in its own order: warm-ups, ramp, working (without slot/state).
  List<SetRow> _memberRows(PlayerStop stop, int m, {String letter = ''}) {
    final se = stop.exercises[m];
    final ex = _catalog.tryExercise(se.exerciseId);
    if (ex == null) return const [];
    final logs = _logsOf(se);
    final rx = se.target;
    final out = <SetRow>[];
    var index = 0;
    SetRow row(SetKind kind, String label, double kg, int reps, {int? duration, int? rir, SetLog? log, int? number}) =>
        SetRow(
          se: se,
          exercise: ex,
          member: m,
          slot: -1,
          setIndex: index++,
          kind: kind,
          label: label,
          weightKg: kg,
          reps: reps,
          durationSec: duration,
          targetRir: rir,
          log: log,
          state: RowState.pending,
          previous: number == null ? null : previousFor(ex.id).elementAtOrNull(number - 1),
          workingNumber: number,
        );

    // Warm-ups.
    final warmLogs = {for (final l in logs.where((l) => l.kind == SetKind.warmup)) l.setIndex: l};
    final warmups = rx.findWeight ? const <PlannedSet>[] : rx.warmups;
    for (final (i, w) in warmups.indexed) {
      out.add(row(SetKind.warmup, 'W${i + 1}', w.weightKg, w.reps, duration: w.durationSec, log: warmLogs[index]));
    }
    // Ramp (find your weight).
    final rampLogs = logs.where((l) => l.kind == SetKind.ramp).toList();
    final ramp = _ramp(stop, m);
    for (final (j, l) in rampLogs.indexed) {
      index = out.length;
      out.add(row(SetKind.ramp, 'F${j + 1}', l.targetKg ?? l.weightKg, l.targetReps ?? l.reps, log: l));
    }
    final rampState = ramp?.state;
    if (rampState != null) {
      index = out.length;
      out.add(row(SetKind.ramp, 'F${rampLogs.length + 1}', rampState.currentKg, rampState.targetReps,
          rir: rampState.targetRir));
    }
    // Working.
    final base = out.length;
    final workLogs = {
      for (final l in logs.where((l) => l.countsAsWork)) l.setIndex: l,
    };
    final planned = _plannedWorking(se);
    final foundKg = ramp?.workingKg;
    SetLog? lastLogged;
    for (var k = 0; k < planned; k++) {
      index = base + k;
      final plan = rx.working.isEmpty
          ? PlannedSet(kind: SetKind.working, weightKg: 0, reps: ex.repRange?.$1 ?? 10)
          : rx.working[math.min(k, rx.working.length - 1)];
      final log = workLogs.remove(index);
      var kg = foundKg ?? (rampState?.currentKg ?? plan.weightKg);
      var reps = plan.reps;
      if (log == null && lastLogged != null && ex.isLoaded) {
        final h = _hintAfter(se, lastLogged);
        kg = h != null && h.automatic && h.suggestedKg != null ? h.suggestedKg! : lastLogged.weightKg;
      }
      // The next set starts from the reps of the set just done, like the weight does.
      if (log == null && lastLogged != null && ex.tracking != Tracking.time && lastLogged.reps > 0) {
        reps = lastLogged.reps;
      }
      final label = '$letter${k + 1}';
      out.add(row(plan.kind == SetKind.warmup ? SetKind.working : plan.kind, label, log?.targetKg ?? kg,
          log?.targetReps ?? reps,
          duration: plan.durationSec, rir: plan.targetRir ?? rx.targetRir, log: log, number: k + 1));
      if (log != null) lastLogged = log;
    }
    // Logged sets that no longer match a planned row (after "remove set") stay visible.
    for (final l in workLogs.values) {
      index = l.setIndex;
      out.add(row(l.kind, '$letter+', l.targetKg ?? l.weightKg, l.targetReps ?? l.reps,
          duration: l.durationSec, log: l, number: null));
    }
    return out;
  }

  List<SetRow> _rows(PlayerStop stop) {
    // Build the set sequence: single exercise = its rows; superset = every member's warm-up and
    // ramp rows, then the working rows round by round (A1, B1, A2, B2 ...).
    final seq = <SetRow>[];
    if (stop.kind == StopKind.superset) {
      final perMember = [
        for (var m = 0; m < stop.exercises.length; m++) _memberRows(stop, m, letter: String.fromCharCode(65 + m)),
      ];
      for (final rows in perMember) {
        seq.addAll(rows.where((r) => r.kind == SetKind.warmup || r.kind == SetKind.ramp));
      }
      final working = [for (final rows in perMember) rows.where((r) => r.workingNumber != null).toList()];
      final rounds = working.fold<int>(0, (a, w) => math.max(a, w.length));
      for (var r = 0; r < rounds; r++) {
        for (final w in working) {
          if (r < w.length) seq.add(w[r]);
        }
      }
      for (final rows in perMember) {
        seq.addAll(rows.where((r) => r.workingNumber == null && r.kind != SetKind.warmup && r.kind != SetKind.ramp));
      }
    } else if (stop.exercises.isNotEmpty) {
      seq.addAll(_memberRows(stop, 0));
    }

    final isCurrent = stop.id == _cursor.stepIndex && _status == PlayerStatus.playing;
    final lastLogged = seq.lastIndexWhere((r) => r.log != null);
    final pointer = isCurrent ? _cursor.setIndex : (stop.isPending ? lastLogged + 1 : seq.length);
    var active = -1;
    if (isCurrent && stop.isPending) {
      for (var i = math.max(pointer, 0); i < seq.length; i++) {
        if (seq[i].log == null) {
          active = i;
          break;
        }
      }
    }
    return [
      for (final (i, r) in seq.indexed)
        SetRow(
          se: r.se,
          exercise: r.exercise,
          member: r.member,
          slot: i,
          setIndex: r.setIndex,
          kind: r.kind,
          label: r.label,
          weightKg: r.weightKg,
          reps: r.reps,
          durationSec: r.durationSec,
          targetRir: r.targetRir,
          log: r.log,
          previous: r.previous,
          workingNumber: r.workingNumber,
          state: r.log != null
              ? RowState.logged
              : i == active
                  ? RowState.active
                  : i < pointer || !stop.isPending
                      ? RowState.skipped
                      : RowState.pending,
        ),
    ];
  }

  /// Rest after [row] when [next] follows in the same stop (0 = no rest sheet).
  int _restBetween(PlayerStop stop, SetRow row, SetRow? next) {
    if (stop.kind == StopKind.superset && next != null && next.workingNumber != null && row.workingNumber != null) {
      final sameRound = next.workingNumber == row.workingNumber && next.member != row.member;
      if (sameRound) return 0;
      return (stop.step as SupersetStep).roundRestSec + (_session!.hotDay ? 30 : 0);
    }
    return switch (row.kind) {
      SetKind.warmup => PlayerTiming.warmupRestSec,
      SetKind.ramp => PlayerTiming.rampRestSec,
      _ => row.se.target.restSec,
    };
  }

  /// Whether to ask "How many more could you have done?" after [set].
  bool _asksRir(SetRow row, {required bool lastWorking}) {
    if (row.exercise.tracking == Tracking.time) return false;
    return switch (row.kind) {
      SetKind.warmup => false,
      SetKind.ramp || SetKind.calibration || SetKind.test => true,
      SetKind.working => switch (settings.rirPrompt) {
          RirPrompt.every => true,
          RirPrompt.last => lastWorking,
          RirPrompt.never => false,
        },
    };
  }

  String _weightText(double kg, Exercise ex) {
    switch (ex.loadType) {
      case LoadType.bodyweight || LoadType.time:
        return '';
      case LoadType.dumbbell when (ex.dumbbellCount ?? 1) > 1:
        return '${ex.dumbbellCount} × ${Fmt.weight(kg)}';
      default:
        return Fmt.weight(kg);
    }
  }

  // ------------------------------------------------------------------------------------------
  // Events: sets
  // ------------------------------------------------------------------------------------------

  /// Changes the active row's weight before logging.
  void setDraftWeight(double kg) {
    final row = activeRow;
    if (row == null) return;
    final key = _draftKey(row);
    _drafts[key] = (math.max(0, kg), _drafts[key]?.$2);
    _notify();
  }

  /// Changes the active row's reps (or seconds for timed sets) before logging.
  void setDraftReps(int reps) {
    final row = activeRow;
    if (row == null) return;
    final key = _draftKey(row);
    _drafts[key] = (_drafts[key]?.$1, math.max(0, reps));
    _notify();
  }

  /// Applies the one-tap suggestion ("Add 2.5 kg for the next set?") to the next set.
  void acceptHint(InSessionHint h) {
    final kg = h.suggestedKg;
    if (kg == null) return;
    setDraftWeight(kg);
    _message = 'Next set: ${Fmt.weight(kg)}';
    _notify();
  }

  /// Logs the active row (SPEC 8 `logSet`): set + cursor in one transaction, then the rest
  /// alarm and a light haptic.
  Future<void> logSet({double? weightKg, int? reps, int? durationSec}) => _run(() async {
        final stop = currentStop;
        final row = activeRow;
        final s = _session;
        if (stop == null || row == null || s == null) return;
        final ex = row.exercise;
        final key = _draftKey(row);
        final kg = ex.isLoaded ? (weightKg ?? _drafts[key]?.$1 ?? row.weightKg) : 0.0;
        final timed = ex.tracking == Tracking.time;
        final heldSec = durationSec ?? (timed ? _heldSeconds(row) : null);
        final set = SetLog(
          id: newId(),
          sessionExerciseId: row.se.id,
          sessionId: s.id,
          exerciseId: ex.id,
          setIndex: row.setIndex,
          kind: row.kind,
          targetKg: ex.isLoaded ? row.weightKg : null,
          targetReps: timed ? null : row.reps,
          weightKg: kg,
          reps: timed ? 0 : (reps ?? _drafts[key]?.$2 ?? row.reps),
          durationSec: heldSec,
          completedAt: now,
        );
        _hold = null;
        await _commitLog(stop, row, set);
      });

  int _heldSeconds(SetRow row) {
    final h = _hold;
    final planned = _drafts[_draftKey(row)]?.$2 ?? row.durationSec ?? row.reps;
    if (h == null || h.setIndex != row.setIndex) return planned;
    return math.max(0, h.totalSec - h.remainingSec(now));
  }

  Future<void> _commitLog(PlayerStop stop, SetRow row, SetLog set) async {
    final before = _cursor;
    final statusesBefore = {for (final e in stop.exercises) e.id: e.status};
    final questionsBefore = _questions;

    // Simulate the session with the new set to compute the cursor written in the same transaction.
    final simulated = _withSet(_session!, set);
    final saved = _session;
    _session = simulated;
    _rebuild();
    final simStop = _stopById(stop.id)!;
    final seq = _rows(simStop);
    final next = seq.skip(row.slot + 1).where((r) => r.log == null).firstOrNull;
    final lastWorking = next == null || !seq.skip(row.slot + 1).any((r) => r.se.id == row.se.id && r.log == null);
    final ask = _asksRir(row, lastWorking: lastWorking);
    final questions = [..._questions, if (ask) set.id];

    var cursor = _cursor.copyWith(setIndex: row.slot + 1, restEndsAt: () => null, findWeight: () => null);
    var restSec = 0;
    var showSheet = false;
    PlayerStop? nextStop;
    var stopFinished = false;
    if (next != null) {
      restSec = _restBetween(simStop, row, next);
      final midRound = restSec == 0;
      showSheet = !midRound && (questions.isNotEmpty || (restSec > 0 && settings.autoRest));
      if (next.isRamp) cursor = cursor.copyWith(findWeight: () => _ramp(simStop, next.member)?.state);
    } else {
      stopFinished = true;
      nextStop = _nextPendingAfterFinishing(simStop);
      final transition = nextStop != null && nextStop.kind.hasSets;
      restSec = transition
          ? (simStop.kind == StopKind.superset ? _restBetween(simStop, row, null) : row.se.target.restSec)
          : 0;
      showSheet = questions.isNotEmpty || (restSec > 0 && settings.autoRest);
      if (nextStop != null) {
        cursor = cursor.copyWith(stepIndex: nextStop.id, setIndex: _initialPointer(nextStop));
      }
    }
    _session = saved;
    _rebuild();
    final ends = showSheet && restSec > 0 && settings.autoRest ? now.add(Duration(seconds: restSec)) : null;
    cursor = cursor.copyWith(restEndsAt: () => ends);

    await _sessions.logSet(set, cursor);
    _cursor = cursor;
    if (stopFinished) {
      for (final se in simStop.exercises) {
        final work = se.sets.any((x) => x.countsAsWork && x.exerciseId == se.exerciseId);
        await _sessions.setExerciseStatus(se.id, work ? SessionExerciseStatus.done : SessionExerciseStatus.skipped,
            reason: work ? null : SkipReason.other);
      }
      if (nextStop != null) await _activate(nextStop);
    }
    await _reload();
    _undo = _Undo(set: set, cursorBefore: before, statusesBefore: statusesBefore, questionsBefore: questionsBefore);
    _drafts.remove(_draftKey(row));
    _questions = showSheet ? questions : (next != null ? questions : const []);
    if (showSheet) {
      _startRestState(RestKind.rest, restSec, ends, questionOnly: ends == null);
    } else {
      _clearRestState();
    }
    if (ends != null) await _scheduleAlarm(ends);
    if (settings.vibration) await _haptics.light();
    if (stopFinished && nextStop == null && !showSheet) {
      await _finish();
    }
  }

  PlayerStop? _nextPendingAfterFinishing(PlayerStop finished) {
    // [finished] is still pending in the simulated session (statuses are written after).
    final i = _displayIndex(finished);
    final others = _display.where((s) => s.id != finished.id).toList();
    final after = _display.skip(i + 1).where((s) => s.isPending).firstOrNull;
    final earlierWork = _display.take(math.max(i, 0)).where((s) => s.isPending && s.kind.hasSets).firstOrNull;
    if (after == null) return earlierWork ?? others.where((s) => s.isPending).firstOrNull;
    if (earlierWork != null && !after.kind.hasSets) return earlierWork;
    return after;
  }

  Session _withSet(Session s, SetLog set) => s.copyWith(exercises: [
        for (final e in s.exercises)
          e.id == set.sessionExerciseId ? e.copyWith(sets: [...e.sets.where((x) => x.id != set.id), set]) : e,
      ]);

  /// The set pointer when entering [stop]: after its last logged row (earlier gaps stay skipped).
  int _initialPointer(PlayerStop stop) {
    if (!stop.kind.hasSets) return 0;
    final seq = _rows(stop);
    return seq.lastIndexWhere((r) => r.log != null) + 1;
  }

  Future<void> _activate(PlayerStop stop) async {
    for (final se in stop.exercises) {
      if (se.status == SessionExerciseStatus.pending) {
        await _sessions.setExerciseStatus(se.id, SessionExerciseStatus.active);
      }
    }
  }

  /// Answers "How many more could you have done?" for [setId] (null = not answered).
  Future<void> answerRir(String setId, int? rir) => _run(() async {
        final set = _setById(setId);
        if (set == null) return;
        await _sessions.updateSet(set.copyWith(rir: () => rir));
        await _reload();
        if (set.kind != SetKind.calibration) _questions = _questions.where((id) => id != setId).toList();
        await _refreshRampCursor();
      });

  /// Logs the extra reps of a calibration set (SPEC 6.6).
  Future<void> answerCalibration(String setId, int extraReps) => _run(() async {
        final set = _setById(setId);
        if (set == null) return;
        await _sessions.updateSet(set.copyWith(calibrationExtraReps: () => extraReps));
        await _reload();
        _questions = _questions.where((id) => id != setId).toList();
      });

  /// Keeps [PlayerCursor.findWeight] equal to the live ramp state after an answer or an edit.
  Future<void> _refreshRampCursor() async {
    final row = activeRow;
    final stop = currentStop;
    final state = row != null && row.isRamp && stop != null ? _ramp(stop, row.member)?.state : null;
    if (state != _cursor.findWeight) {
      _cursor = _cursor.copyWith(findWeight: () => state);
      await _sessions.saveCursor(sessionId, _cursor);
    }
  }

  /// Deletes the last logged set and restores the cursor (undo snackbar).
  Future<void> undoLast() => _run(() async {
        final u = _undo;
        if (u == null) return;
        _undo = null;
        await _sessions.deleteSet(u.set.id);
        for (final MapEntry(:key, :value) in u.statusesBefore.entries) {
          final se = _seById(key);
          if (se != null && se.status != value) await _sessions.setExerciseStatus(key, value);
        }
        final cursor = u.cursorBefore.copyWith(restEndsAt: () => null);
        await _sessions.saveCursor(sessionId, cursor);
        _cursor = cursor;
        _questions = u.questionsBefore.where((id) => id != u.set.id).toList();
        _clearRestState();
        await _restAlarm.cancel();
        await _reload();
      });

  /// Skips the active set without logging it (the row shows "skipped"). In find-your-weight
  /// mode it ends the ramp at the current weight instead.
  Future<void> skipSet() => _run(() async {
        final stop = currentStop;
        final row = activeRow;
        if (stop == null || row == null) return;
        if (row.isRamp) {
          final kg = _drafts[_draftKey(row)]?.$1 ?? row.weightKg;
          final se = row.se;
          final n = _plannedWorking(se);
          final rx = se.target.copyWith(
            findWeight: false,
            warmups: const [],
            working: [
              for (var i = 0; i < n; i++)
                (se.target.working.isEmpty
                        ? PlannedSet(kind: SetKind.working, weightKg: kg, reps: row.exercise.repRange?.$1 ?? 10)
                        : se.target.working[math.min(i, se.target.working.length - 1)])
                    .copyWith(weightKg: kg),
            ],
          );
          await _sessions.replaceExercise(se.id, se.exerciseId, rx);
          _cursor = _cursor.copyWith(findWeight: () => null);
          await _sessions.saveCursor(sessionId, _cursor);
          await _reload();
          return;
        }
        final seq = _rows(stop);
        final hasMore = seq.skip(row.slot + 1).any((r) => r.log == null);
        if (hasMore) {
          _cursor = _cursor.copyWith(setIndex: row.slot + 1);
          await _sessions.saveCursor(sessionId, _cursor);
          await _reload();
          await _refreshRampCursor();
        } else {
          await _finishStop(stop);
        }
      });

  /// Adds one working set to the active exercise (copy of its last planned set).
  Future<void> addSet() => _run(() async {
        final se = activeRow?.se ?? currentStop?.exercise;
        if (se == null) return;
        final rx = se.target;
        final last = rx.working.lastOrNull ??
            PlannedSet(kind: SetKind.working, weightKg: 0, reps: exerciseOf(se).repRange?.$1 ?? 10);
        await _sessions.replaceExercise(se.id, se.exerciseId,
            rx.copyWith(working: [...rx.working, last.copyWith(kind: SetKind.working)]));
        if (se.status != SessionExerciseStatus.active && se.status != SessionExerciseStatus.pending) {
          await _sessions.setExerciseStatus(se.id, SessionExerciseStatus.active);
          final stop = _stopForSe(se.id);
          if (stop != null && stop.id != _cursor.stepIndex) {
            _cursor = _cursor.copyWith(stepIndex: stop.id, setIndex: _initialPointer(stop), restEndsAt: () => null);
            await _sessions.saveCursor(sessionId, _cursor);
          }
        }
        await _reload();
      });

  /// Removes the last unlogged working set of the active exercise (never below one set).
  Future<void> removeSet() => _run(() async {
        final row = activeRow;
        final se = row?.se ?? currentStop?.exercise;
        if (se == null) return;
        final rows = rowsOf().where((r) => r.se.id == se.id && r.workingNumber != null).toList();
        final unlogged = rows.where((r) => r.log == null).toList();
        if (unlogged.isEmpty || _plannedWorking(se) <= 1 || se.target.working.length <= 1) {
          _message = 'This is the last set. Use "Skip exercise" to skip it.';
          return;
        }
        final rx = se.target;
        await _sessions.replaceExercise(se.id, se.exerciseId, rx.copyWith(working: rx.working.sublist(0, rx.working.length - 1)));
        await _reload();
        final stop = currentStop;
        if (stop != null && rowsOf(stop).every((r) => r.state != RowState.active)) await _finishStop(stop);
      });

  /// Skips the current exercise (or the active superset member's whole pair) with [reason].
  Future<void> skipExercise(SkipReason reason) => _run(() async {
        final stop = currentStop;
        if (stop == null) return;
        for (final se in stop.exercises) {
          final work = se.sets.any((x) => x.countsAsWork && x.exerciseId == se.exerciseId);
          await _sessions.setExerciseStatus(
              se.id, work ? SessionExerciseStatus.done : SessionExerciseStatus.skipped,
              reason: work ? null : reason);
        }
        if (!stop.kind.hasSets && stop.exercises.isEmpty) _cursor = _visit(stop, skipped: true);
        await _reload();
        await _advanceFrom(stop);
      });

  /// "It hurts": flags the last logged set of the current exercise and remembers the pain date
  /// (no swap suggestion offers this exercise for 14 days). Returns false when nothing was logged.
  Future<bool> markPain() async {
    var flagged = false;
    await _run(() async {
      final stop = currentStop;
      final row = activeRow;
      final se = row?.se ?? stop?.exercise;
      if (se == null) return;
      final last = _logsOf(se).lastOrNull;
      if (last != null) {
        await _sessions.updateSet(last.copyWith(painFlag: true));
        flagged = true;
      }
      await _states.putPrefs(prefsFor(se.exerciseId).copyWith(lastPainAt: () => now));
      _prefs = await _states.allPrefs();
      await _reload();
      await _refreshRampCursor();
    });
    return flagged;
  }

  /// Edits a logged set (weight, reps, reps in reserve).
  Future<void> editSet(String setId, {required double weightKg, required int reps, int? rir, int? durationSec}) =>
      _run(() async {
        final set = _setById(setId);
        if (set == null) return;
        await _sessions.updateSet(set.copyWith(
          weightKg: weightKg,
          reps: reps,
          rir: () => rir,
          durationSec: durationSec == null ? null : () => durationSec,
        ));
        await _reload();
        await _refreshRampCursor();
      });

  /// Deletes a logged set; returns it for the undo snackbar ([restoreSet]). Ramp sets cannot be
  /// deleted once working sets exist (the working weight came from them): edit them instead.
  Future<SetLog?> deleteSet(String setId) async {
    SetLog? deleted;
    await _run(() async {
      final set = _setById(setId);
      if (set == null) return;
      final se = _seById(set.sessionExerciseId);
      if (set.kind == SetKind.ramp && se != null && _logsOf(se).any((l) => l.countsAsWork)) {
        _message = 'Ramp sets set your working weight. Fix the numbers instead.';
        return;
      }
      await _sessions.deleteSet(setId);
      if (_undo?.set.id == setId) _undo = null;
      _questions = _questions.where((id) => id != setId).toList();
      deleted = set;
      await _reload();
      await _refreshRampCursor();
    });
    return deleted;
  }

  /// Puts back a set removed by [deleteSet] (undo).
  Future<void> restoreSet(SetLog set) => _run(() async {
        await _sessions.logSet(set, _cursor);
        await _reload();
        await _refreshRampCursor();
      });

  /// Saves the machine note ("seat 4") of [exerciseId].
  Future<void> setMachineNote(String exerciseId, String note) => _run(() async {
        final trimmed = note.trim();
        await _states.putPrefs(prefsFor(exerciseId).copyWith(machineNote: () => trimmed.isEmpty ? null : trimmed));
        _prefs = await _states.allPrefs();
      });

  // ------------------------------------------------------------------------------------------
  // Events: rest
  // ------------------------------------------------------------------------------------------

  void _startRestState(RestKind kind, int totalSec, DateTime? ends, {bool questionOnly = false}) {
    _restKind = kind;
    _restTotalSec = totalSec;
    _restWarned = totalSec <= PlayerTiming.warnAtSec;
    _restSignalled = false;
    _questionOnlySheet = questionOnly;
    _syncTicker();
  }

  void _clearRestState() {
    _restKind = RestKind.rest;
    _restTotalSec = 0;
    _questionOnlySheet = false;
    _syncTicker();
  }

  Future<void> _scheduleAlarm(DateTime at, {String? title, String? body}) async {
    if (!settings.restNotification) return;
    if (!_permissionAsked) {
      _permissionAsked = true;
      await _restAlarm.ensurePermission();
    }
    await _restAlarm.schedule(at, title: title ?? 'Rest over', body: body ?? _alarmBody());
  }

  /// "Rest over: Set 3 of Incline Dumbbell Press" (SPEC 4.4).
  String _alarmBody() {
    final row = activeRow;
    final stop = currentStop;
    if (row == null) return stop == null ? 'Time for your next step.' : 'Rest over: next up, ${stopTitle(stop)}';
    final what = switch (row.kind) {
      SetKind.warmup => 'warm-up set ${row.label.substring(1)}',
      SetKind.ramp => 'find-your-weight set ${row.label.substring(1)}',
      _ => 'Set ${row.workingNumber ?? row.label}',
    };
    return 'Rest over: $what of ${row.exercise.name}';
  }

  /// -15 / +15 seconds.
  Future<void> adjustRest(int deltaSec) => _run(() async {
        final ends = _cursor.restEndsAt;
        if (ends == null) return;
        final base = ends.isBefore(now) ? now : ends;
        var next = base.add(Duration(seconds: deltaSec));
        if (!next.isAfter(now)) next = now.add(const Duration(seconds: 1));
        _cursor = _cursor.copyWith(restEndsAt: () => next);
        await _sessions.saveCursor(sessionId, _cursor);
        _restTotalSec = math.max(_restTotalSec + deltaSec, next.difference(now).inSeconds);
        _restSignalled = false;
        _restWarned = next.difference(now).inSeconds <= PlayerTiming.warnAtSec;
        await _scheduleAlarm(next);
        _syncTicker();
      });

  /// Ends the rest now (also "Next set" after "Rest over"). Unanswered questions stay unanswered.
  Future<void> skipRest() => _run(() async {
        _questions = const [];
        _clearRestState();
        if (_cursor.restEndsAt != null) {
          _cursor = _cursor.copyWith(restEndsAt: () => null);
          await _sessions.saveCursor(sessionId, _cursor);
        }
        await _restAlarm.cancel();
        if (_status == PlayerStatus.playing && _firstPending() == null) await _finish();
      });

  /// "Wait 2 min / ask to work in": a 2:00 timer on the rest sheet.
  Future<void> startWait() => _run(() async {
        final ends = now.add(const Duration(seconds: PlayerTiming.waitSec));
        _cursor = _cursor.copyWith(restEndsAt: () => ends);
        await _sessions.saveCursor(sessionId, _cursor);
        _questions = const [];
        _startRestState(RestKind.wait, PlayerTiming.waitSec, ends);
        await _scheduleAlarm(ends, title: 'Time to check the machine', body: 'Two minutes are up: is it free?');
      });

  // ------------------------------------------------------------------------------------------
  // Events: timers (deadline based; a 1 s periodic timer only repaints)
  // ------------------------------------------------------------------------------------------

  void _syncTicker() {
    final needed = _status == PlayerStatus.playing && (_cursor.restEndsAt != null || (_hold?.running ?? false));
    if (needed && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    } else if (!needed && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  /// Processes deadlines (rest over, timer done, hold done) and repaints. Called every second
  /// while a deadline is running, and by [appResumed].
  Future<void> tick() async {
    if (_disposed || _status != PlayerStatus.playing) return;
    final stop = currentStop;
    final ends = _cursor.restEndsAt;
    if (stop != null && ends != null) {
      final left = ends.difference(now).inMilliseconds;
      if (stop.kind.hasSets || _restKind == RestKind.wait) {
        if (!_restWarned && left <= PlayerTiming.warnAtSec * 1000 && left > 0) {
          _restWarned = true;
          if (settings.vibration) unawaited(_haptics.light());
        }
        if (!_restSignalled && left <= 0) {
          _restSignalled = true;
          _restWarned = true;
          await _restOver();
        }
      } else {
        final timer = stopTimer;
        final total = timer?.totalSec;
        if (timer != null && total != null && timer.item.perSide && !_halfBeeped && left <= total * 500 && left > 0) {
          _halfBeeped = true;
          _message = 'Switch sides';
          if (settings.sound) unawaited(_sound.beep());
        }
        if (left <= 0) await _run(() => _timerFinished());
      }
    }
    final h = _hold;
    if (h != null && h.running && h.remainingSec(now) == 0) {
      _hold = null;
      if (settings.sound) unawaited(_sound.restDone());
      if (settings.vibration) unawaited(_haptics.heavyTriple());
      await logSet(durationSec: h.totalSec);
    }
    _syncTicker();
    _notify();
  }

  /// Rest reached 0 in the foreground: three heavy pulses and the rest-over sound.
  Future<void> _restOver() async {
    await _restAlarm.cancel();
    if (settings.vibration) unawaited(_haptics.heavyTriple());
    if (settings.sound) unawaited(_sound.restDone());
  }

  List<ProgramItem> _timedItems(PlayerStop stop) => switch (stop.kind) {
        StopKind.mobility => [for (var r = 0; r < _drillRounds; r++) ...stop.items],
        StopKind.cooldown when !settings.cooldownBlock =>
          stop.items.where((i) => i.role != ItemRole.stretch).toList(),
        _ => stop.items,
      };

  int? _itemSeconds(PlayerStop stop, ProgramItem item) {
    if (stop.kind == StopKind.finisher) return (stop.step as FinisherStep).durationSec;
    final ex = _catalog.tryExercise(item.exerciseId);
    final base = item.durationSeconds ?? (item.repRange == null ? ex?.durationSeconds : null);
    if (base == null) return null;
    return item.perSide ? base * 2 : base;
  }

  /// Starts or resumes the current item's timer.
  Future<void> startTimer() => _run(() async {
        final t = stopTimer;
        final total = t?.totalSec;
        if (t == null || total == null || t.running) return;
        final remaining = t.pausedRemainingSec ?? total;
        final ends = now.add(Duration(seconds: remaining));
        _timerPausedRemaining = null;
        _halfBeeped = t.item.perSide && remaining <= total ~/ 2;
        _cursor = _cursor.copyWith(restEndsAt: () => ends);
        await _sessions.saveCursor(sessionId, _cursor);
        if (remaining >= PlayerTiming.notifyTimerAtSec) {
          await _scheduleAlarm(ends, title: "Time's up", body: '${t.exercise.name}: done. Open the app for the next step.');
        }
        _syncTicker();
      });

  /// Pauses the current item's timer.
  Future<void> pauseTimer() => _run(() async {
        final t = stopTimer;
        if (t == null || !t.running) return;
        _timerPausedRemaining = t.remainingSec(now);
        _cursor = _cursor.copyWith(restEndsAt: () => null);
        await _sessions.saveCursor(sessionId, _cursor);
        await _restAlarm.cancel();
        _syncTicker();
      });

  /// "Done" on a timed or checklist item: logs timed cardio and moves to the next item or stop.
  Future<void> completeItem() => _run(() => _completeItem(logCardio: true));

  /// Skips the current item (finisher "Skip", a drill you cannot do).
  Future<void> skipItem() => _run(() => _completeItem(logCardio: false));

  Future<void> _timerFinished({bool silent = false}) async {
    final t = stopTimer;
    final stop = currentStop;
    if (t == null || stop == null) return;
    if (!silent) {
      // Every timer rings when it runs down, short ones too (a 0.15 s beep was easy to miss).
      final long = (t.totalSec ?? 0) >= PlayerTiming.notifyTimerAtSec;
      if (long) await _restAlarm.cancel();
      if (settings.sound) unawaited(_sound.restDone());
      if (settings.vibration) unawaited(long ? _haptics.heavyTriple() : _haptics.light());
    }
    await _completeItem(logCardio: true, finishedTimer: true);
  }

  Future<void> _completeItem({required bool logCardio, bool finishedTimer = false}) async {
    final stop = currentStop;
    final t = stopTimer;
    if (stop == null || t == null) return;
    final total = t.totalSec;
    final done = total == null ? null : (finishedTimer ? total : math.max(0, total - t.remainingSec(now)));
    _timerPausedRemaining = null;
    _halfBeeped = false;
    final cardioSe = stop.exercise;
    if ((stop.kind == StopKind.warmupCardio || stop.kind == StopKind.finisher) && cardioSe != null) {
      if (logCardio && (done ?? 0) > 0) {
        final set = SetLog(
          id: newId(),
          sessionExerciseId: cardioSe.id,
          sessionId: sessionId,
          exerciseId: cardioSe.exerciseId,
          setIndex: 0,
          kind: SetKind.working,
          weightKg: 0,
          reps: 0,
          durationSec: done,
          completedAt: now,
        );
        await _sessions.logSet(set, _cursor.copyWith(restEndsAt: () => null));
      }
      await _sessions.setExerciseStatus(
          cardioSe.id, logCardio ? SessionExerciseStatus.done : SessionExerciseStatus.skipped,
          reason: logCardio ? null : SkipReason.other);
      _cursor = _cursor.copyWith(restEndsAt: () => null);
      await _reload();
      await _advanceFrom(stop);
      return;
    }
    final next = t.itemIndex + 1;
    if (next < t.itemCount) {
      _cursor = _cursor.copyWith(setIndex: next, restEndsAt: () => null);
      await _sessions.saveCursor(sessionId, _cursor);
      await _restAlarm.cancel();
      // Stretches run back to back: start the next one with a beep (SPEC 4.4).
      final after = stopTimer;
      if (stop.kind == StopKind.cooldown && finishedTimer && after != null && after.isTimed) {
        final ends = now.add(Duration(seconds: after.totalSec!));
        _cursor = _cursor.copyWith(restEndsAt: () => ends);
        await _sessions.saveCursor(sessionId, _cursor);
      }
      _syncTicker();
      return;
    }
    _cursor = _visit(stop, skipped: false).copyWith(restEndsAt: () => null);
    await _sessions.saveCursor(sessionId, _cursor);
    await _reload();
    await _advanceFrom(stop);
  }

  PlayerCursor _visit(PlayerStop stop, {required bool skipped}) {
    final mark = skipped ? -(stop.id + 1) : stop.id;
    final visited = [..._cursor.visitedSteps.where((v) => v != stop.id && v != -(stop.id + 1)), mark];
    return _cursor.copyWith(visitedSteps: visited);
  }

  /// "Skip stretches": ends the cool-down now.
  Future<void> skipStretches() => _run(() async {
        final stop = currentStop;
        if (stop == null || stop.kind != StopKind.cooldown) return;
        _cursor = _visit(stop, skipped: false).copyWith(restEndsAt: () => null);
        _timerPausedRemaining = null;
        await _sessions.saveCursor(sessionId, _cursor);
        await _restAlarm.cancel();
        await _reload();
        await _advanceFrom(stop);
      });

  /// Warm-up cardio "No machine free": do the warm-up drills twice instead (SPEC 4.4).
  Future<void> cardioUnavailable() => _run(() async {
        final stop = currentStop;
        if (stop == null || stop.kind != StopKind.warmupCardio) return;
        final se = stop.exercise;
        if (se != null) await _sessions.setExerciseStatus(se.id, SessionExerciseStatus.skipped, reason: SkipReason.busy);
        if (se == null) _cursor = _visit(stop, skipped: true);
        _cursor = _cursor.copyWith(restEndsAt: () => null);
        _timerPausedRemaining = null;
        await _restAlarm.cancel();
        _drillRounds = _stops.any((s) => s.kind == StopKind.mobility) ? 2 : 1;
        if (_drillRounds == 2) _message = 'No problem: do the warm-up drills twice instead.';
        await _reload();
        await _advanceFrom(stop);
      });

  /// "Skip extras": skips every extra that is not started.
  Future<void> skipExtras() => _run(() async {
        final stop = currentStop;
        for (final s in _stops.where((s) => s.kind == StopKind.extra && s.isPending)) {
          for (final se in s.exercises) {
            final work = se.sets.any((x) => x.countsAsWork && x.exerciseId == se.exerciseId);
            if (!work) await _sessions.setExerciseStatus(se.id, SessionExerciseStatus.skipped, reason: SkipReason.noTime);
          }
        }
        await _reload();
        if (stop != null && stop.kind == StopKind.extra) await _advanceFrom(stop);
      });

  /// Starts (or resumes) the hold timer of the active timed set (planks).
  void startHold() {
    final row = activeRow;
    if (row == null || !row.isTimed) return;
    final h = _hold;
    final total = _drafts[_draftKey(row)]?.$2 ?? row.durationSec ?? 30;
    final remaining = h != null && h.setIndex == row.setIndex ? h.remainingSec(now) : total;
    _hold = HoldTimer(
        setIndex: row.setIndex,
        totalSec: h != null && h.setIndex == row.setIndex ? h.totalSec : total,
        endsAt: now.add(Duration(seconds: remaining)));
    _syncTicker();
    _notify();
  }

  void pauseHold() {
    final h = _hold;
    if (h == null || !h.running) return;
    _hold = HoldTimer(setIndex: h.setIndex, totalSec: h.totalSec, pausedRemainingSec: h.remainingSec(now));
    _syncTicker();
    _notify();
  }

  // ------------------------------------------------------------------------------------------
  // Events: navigation
  // ------------------------------------------------------------------------------------------

  /// Finishes the current set-based stop (no more rows) and moves on.
  Future<void> _finishStop(PlayerStop stop) async {
    for (final se in stop.exercises) {
      final work = se.sets.any((x) => x.countsAsWork && x.exerciseId == se.exerciseId);
      await _sessions.setExerciseStatus(se.id, work ? SessionExerciseStatus.done : SessionExerciseStatus.skipped,
          reason: work ? null : SkipReason.other);
    }
    await _reload();
    await _advanceFrom(stop);
  }

  /// Moves to the stop after [stop]; finishes the workout when nothing is left.
  Future<void> _advanceFrom(PlayerStop stop) async {
    final fresh = _stopById(stop.id) ?? stop;
    final next = _nextPendingAfter(fresh);
    if (next == null) {
      await _finish();
      return;
    }
    await _moveTo(next, keepRest: _cursor.restEndsAt != null && next.kind.hasSets);
  }

  Future<void> _moveTo(PlayerStop stop, {required bool keepRest}) async {
    _timerPausedRemaining = null;
    _halfBeeped = false;
    _hold = null;
    if (!keepRest) {
      _questions = const [];
      _clearRestState();
      await _restAlarm.cancel();
    }
    _cursor = _cursor.copyWith(
      stepIndex: stop.id,
      setIndex: _initialPointer(stop),
      restEndsAt: keepRest ? null : () => null,
      findWeight: () => null,
    );
    await _activate(stop);
    await _sessions.saveCursor(sessionId, _cursor);
    await _reload();
    await _refreshRampCursor();
    _syncTicker();
  }

  /// Plays the next stop now (also "Next exercise" on a finished stop).
  Future<void> nextStep() => _run(() async {
        final stop = currentStop;
        if (stop == null) return;
        await _advanceFrom(stop);
      });

  /// Goes back to the previous stop in play order (to look or fix something).
  Future<void> prevStep() => _run(() async {
        final stop = currentStop;
        if (stop == null) return;
        final i = _displayIndex(stop);
        if (i <= 0) return;
        await _jump(_display[i - 1]);
      });

  /// Jumps to any stop (step list sheet). Finished stops can be reviewed and edited.
  Future<void> jumpTo(int stopId) => _run(() async {
        final stop = _stopById(stopId);
        if (stop == null || stop.id == _cursor.stepIndex) return;
        await _jump(stop);
      });

  Future<void> _jump(PlayerStop stop) async {
    // Revisiting a finished timed stop reopens it.
    if (!stop.kind.hasSets && !stop.isPending) {
      _cursor = _cursor.copyWith(
          visitedSteps: _cursor.visitedSteps.where((v) => v != stop.id && v != -(stop.id + 1)).toList());
      for (final se in stop.exercises) {
        if (se.sets.isEmpty) await _sessions.setExerciseStatus(se.id, SessionExerciseStatus.pending);
      }
      await _reload();
    }
    final fresh = _stopById(stop.id) ?? stop;
    _questions = const [];
    _clearRestState();
    await _restAlarm.cancel();
    _timerPausedRemaining = null;
    _hold = null;
    _cursor = _cursor.copyWith(
        stepIndex: fresh.id, setIndex: _initialPointer(fresh), restEndsAt: () => null, findWeight: () => null);
    if (fresh.isPending) await _activate(fresh);
    await _sessions.saveCursor(sessionId, _cursor);
    await _reload();
    await _refreshRampCursor();
    _syncTicker();
  }

  /// "Do the next exercise first": moves this exercise after the next one and plays that one.
  Future<void> doNextFirst() => _run(() async {
        final stop = currentStop;
        if (stop == null || !canDoNextFirst(stop)) return;
        final next = _nextMainAfter(stop)!;
        final order = [..._display];
        order.removeWhere((s) => s.id == stop.id);
        order.insert(order.indexWhere((s) => s.id == next.id) + 1, stop);
        final ids = [for (final s in order) ...s.exercises.map((e) => e.id)];
        final s = _session!;
        final rest = [
          for (final e in [...s.exercises]..sort((a, b) => a.position.compareTo(b.position)))
            if (!ids.contains(e.id)) e.id,
        ];
        await _sessions.reorder(sessionId, [...ids, ...rest]);
        await _reload();
        await _jump(_stopById(next.id)!);
        _message = '${stopTitle(stop)} moved after ${stopTitle(next)}.';
      });

  // ------------------------------------------------------------------------------------------
  // Events: swap
  // ------------------------------------------------------------------------------------------

  /// Alternatives for [se] (SPEC 6.9).
  List<SwapOption> swapOptions(SessionExercise se) {
    final stop = _stopForSe(se.id);
    final phase = _phase;
    final ex = _catalog.tryExercise(se.exerciseId);
    if (stop == null || phase == null || ex == null) return const [];
    final m = stop.exercises.indexWhere((e) => e.id == se.id);
    final today = {for (final e in _session!.exercises) e.exerciseId};
    return suggestSwaps(ex, _itemFor(stop, m), _catalog, equipment, phase, today, _prefs, _exerciseStates,
        smithEarly: settings.smithEarly);
  }

  /// Swaps [se] to [exerciseId]. Keeps the sets/rep target; takes the substitute's own working
  /// weight or starts find-your-weight. Returns true when the same swap was also made "just for
  /// today" last time (the UI then asks "Make this your default?").
  Future<bool> swap(SessionExercise se, String exerciseId, SwapScope scope) async {
    var askDefault = false;
    await _run(() async {
      final s = _session!;
      final stop = _stopForSe(se.id);
      final ex = _catalog.tryExercise(exerciseId);
      if (stop == null || ex == null) return;
      final m = stop.exercises.indexWhere((e) => e.id == se.id);
      final fresh = stop.exercises[m];
      final item = _memberStep(stop, m).item.copyWith(exerciseId: exerciseId, sets: fresh.target.working.length);
      final state = _exerciseStates[exerciseId] ?? await _states.get(exerciseId);
      final prefs = await _states.prefs(exerciseId);
      final phase = _phase;
      Prescription rx;
      if (phase != null) {
        rx = prescribe(ex, item, phase, s.trainingWeek, state, equipment, prefs, GapRule.none,
            isDeload: s.isDeload, hotDay: s.hotDay);
      } else {
        rx = fresh.target.copyWith(exerciseId: exerciseId, warmups: const [], findWeight: state?.workingKg == null);
      }
      // Keep today's set count (after add/remove set).
      if (rx.working.isNotEmpty && rx.working.length != fresh.target.working.length) {
        rx = rx.copyWith(working: [
          for (var i = 0; i < fresh.target.working.length; i++) rx.working[math.min(i, rx.working.length - 1)],
        ]);
      }
      // An added exercise has no program slot: its swaps are for today only.
      if (stop.isAdded) scope = SwapScope.today;
      final original = fresh.originalExerciseId ?? fresh.exerciseId;
      if (scope == SwapScope.today && exerciseId != original) {
        askDefault = await _sameSwapLastTime(fresh, original, exerciseId);
      }
      await _sessions.replaceExercise(fresh.id, exerciseId, rx);
      if (scope == SwapScope.notAtGym) {
        await _states.putPrefs(prefsFor(fresh.exerciseId).copyWith(hidden: true));
      }
      if (scope != SwapScope.today) {
        await _programs.setOverride(
            ProgramOverride(programId: s.programId, dayId: s.dayId, slotKey: fresh.slotKey, exerciseId: exerciseId));
      }
      if (state != null) _exerciseStates[exerciseId] = state;
      _prefs = await _states.allPrefs();
      _previous[exerciseId] = await _sessions.lastExposure(exerciseId, excludingSessionId: sessionId);
      _drafts.removeWhere((k, _) => k.startsWith('${fresh.id}:'));
      await _reload();
      // Start the swapped exercise from its first unlogged row.
      final current = currentStop;
      if (current != null && current.id == stop.id) {
        _cursor = _cursor.copyWith(setIndex: _initialPointer(current));
        await _sessions.saveCursor(sessionId, _cursor);
        await _refreshRampCursor();
      }
      _message = switch (scope) {
        SwapScope.today => 'Swapped to ${ex.name} for today.',
        SwapScope.program => '${ex.name} is now in your program.',
        SwapScope.notAtGym => 'Hidden ${_name(fresh.exerciseId)}. ${ex.name} is now in your program.',
      };
    });
    return askDefault;
  }

  // ------------------------------------------------------------------------------------------
  // Events: add / remove an exercise
  // ------------------------------------------------------------------------------------------

  /// The program item of an exercise added during the session.
  ProgramItem _addedItem(Exercise ex, {int? sets, ItemRole? role}) => ProgramItem(
        exerciseId: ex.id,
        sets: math.max(1, sets ?? ex.defaultSets),
        repRange: ex.repRange,
        durationSeconds: ex.durationSeconds,
        restSeconds: ex.restSeconds,
        role: role ?? (ex.mechanic == Mechanic.compound ? ItemRole.secondary : ItemRole.accessory),
        warmupSets: ex.mechanic == Mechanic.compound ? 'auto' : 0,
        substitutions: ex.substitutions,
      );

  /// Exercises the "Add an exercise" picker leaves out: today's exercises and cardio machines.
  Set<String> get addExerciseExcludes => {
        for (final e in _session?.exercises ?? const <SessionExercise>[]) e.exerciseId,
        for (final e in _catalog.exercises)
          if (e.category == ExerciseCategory.cardio) e.id,
      };

  /// Adds [exerciseId] to today's workout (it does not change the program). It goes before the
  /// current exercise when that has nothing logged yet (and plays now), after it when it has
  /// sets logged, and before the first exercise during the warm-up.
  Future<void> addExercise(String exerciseId) => _run(() async {
        final s = _session;
        final ex = _catalog.tryExercise(exerciseId);
        final phase = _phase;
        if (s == null || ex == null) return;
        if (phase == null) {
          _message = "Couldn't add ${ex.name}: the program for this workout is missing.";
          return;
        }
        final current = currentStop;
        final number = s.exercises
                .where((e) => isAddedSlot(e.slotKey))
                .fold(0, (m, e) => math.max(m, _addedNumber(e.slotKey))) +
            1;
        final item = _addedItem(ex);
        final states = await _states.getAll({exerciseId, ...?seedTransferSources[exerciseId]});
        final state = states[exerciseId];
        final prefs = await _states.prefs(exerciseId);
        final seed = state?.workingKg == null ? transferSeed(exerciseId, states, equipment) : null;
        var rx = prescribe(ex, item, phase, s.trainingWeek, state, equipment, prefs, GapRule.none,
            isDeload: s.isDeload, hotDay: s.hotDay, seedKg: seed);
        if (!settings.warmupSets) rx = rx.copyWith(warmups: const []);
        final se = await _sessions.addExtra(
            sessionId, ExerciseStep(index: -1, item: item, rx: rx, slotKey: '$addedSlotPrefix$number'));
        if (state != null) _exerciseStates[exerciseId] = state;
        _prefs = await _states.allPrefs();
        _previous[exerciseId] = await _sessions.lastExposure(exerciseId, excludingSessionId: sessionId);
        await _reload();

        // Place it in the play order.
        final addedStop = _stopForSe(se.id);
        if (addedStop == null) return;
        final order = [..._display]..removeWhere((x) => x.id == addedStop.id);
        final cur = current == null ? -1 : order.indexWhere((x) => x.id == current.id);
        final firstMain = order.indexWhere((x) => x.kind.isMain);
        final started = current != null && current.isPending && current.exercises.any((e) => e.sets.isNotEmpty);
        int? at;
        var playNow = true;
        var duringWarmup = false;
        if (current != null && current.kind.isMain) {
          at = started ? cur + 1 : cur;
          playNow = !started;
        } else if (firstMain >= 0 && cur >= 0 && cur < firstMain) {
          at = firstMain;
          playNow = false;
          duringWarmup = true;
        }
        if (at != null) {
          order.insert(at, addedStop);
          final ids = [for (final st in order) ...st.exercises.map((e) => e.id)];
          final rest = [
            for (final e in [..._session!.exercises]..sort((a, b) => a.position.compareTo(b.position)))
              if (!ids.contains(e.id)) e.id,
          ];
          await _sessions.reorder(sessionId, [...ids, ...rest]);
          await _reload();
        }
        final fresh = _stopForSe(se.id);
        if (playNow && fresh != null) {
          await _jump(fresh);
          _message = 'Added ${ex.name} to today.';
        } else {
          _message = duringWarmup
              ? 'Added ${ex.name}. It comes right after the warm-up.'
              : 'Added ${ex.name}. It comes next.';
        }
      });

  /// True when the current stop is an exercise added today (it can be removed).
  bool get canRemoveExercise => currentStop?.isAdded ?? false;

  /// Removes the current exercise if it was added today (with its logged sets) and plays the next.
  Future<void> removeAddedExercise() => _run(() async {
        final stop = currentStop;
        if (stop == null || !stop.isAdded) return;
        final se = stop.exercise!;
        final next = _nextPendingAfter(stop);
        final nextSe = next?.exercises.firstOrNull?.id;
        final nextId = next?.id;
        await _sessions.removeExercise(se.id);
        _drafts.removeWhere((k, _) => k.startsWith('${se.id}:'));
        _undo = null;
        _questions = const [];
        await _reload();
        _message = 'Removed ${_name(se.exerciseId)} from today.';
        final target = nextSe != null ? _stopForSe(nextSe) : (nextId == null ? null : _stopById(nextId));
        if (target == null) {
          await _finish();
          return;
        }
        await _moveTo(target, keepRest: false);
      });

  /// "Make this your default?" after the same swap twice in a row.
  Future<void> makeDefault(SessionExercise se) => _run(() async {
        final s = _session!;
        final fresh = _seById(se.id) ?? se;
        await _programs.setOverride(
            ProgramOverride(programId: s.programId, dayId: s.dayId, slotKey: fresh.slotKey, exerciseId: fresh.exerciseId));
        _message = '${_name(fresh.exerciseId)} is now in your program.';
      });

  Future<bool> _sameSwapLastTime(SessionExercise se, String original, String replacement) async {
    final s = _session!;
    final done = await _sessions.listCompleted(programId: s.programId);
    final last = done.where((x) => x.dayId == s.dayId && x.id != s.id).lastOrNull;
    if (last == null) return false;
    return last.exercises.any((e) =>
        e.slotKey == se.slotKey && e.originalExerciseId == original && e.exerciseId == replacement);
  }

  // ------------------------------------------------------------------------------------------
  // Lifecycle and end
  // ------------------------------------------------------------------------------------------

  /// The app came back to the foreground: catch up on deadlines and keep the screen awake.
  Future<void> appResumed() async {
    if (_status != PlayerStatus.playing) return;
    if (settings.keepAwake) await _wakelock.enable();
    await tick();
  }

  /// "End workout": save (unfinished sets skipped) or discard.
  Future<void> endWorkout({required bool save}) => _run(() async {
        if (save) {
          await _finish();
        } else {
          await _sessions.discard(sessionId);
          await _restAlarm.cancel();
          await _wakelock.disable();
          _status = PlayerStatus.discarded;
          _syncTicker();
        }
      });

  /// Completion (SPEC 8): statuses, complete, progression, PRs, rotation, reactive deload,
  /// milestones, wakelock. Each follow-up step is guarded so the summary is always reached.
  Future<void> _finish() async {
    if (_status != PlayerStatus.playing) return;
    _status = PlayerStatus.finishing;
    _ticker?.cancel();
    _ticker = null;
    _notify();
    final s = _session!;
    for (final se in s.exercises) {
      if (se.status == SessionExerciseStatus.pending || se.status == SessionExerciseStatus.active) {
        final work = se.sets.any((x) => x.countsAsWork && x.exerciseId == se.exerciseId);
        await _sessions.setExerciseStatus(se.id, work ? SessionExerciseStatus.done : SessionExerciseStatus.skipped,
            reason: work ? null : SkipReason.noTime);
      }
    }
    // Lets a workout logged by mistake be deleted later today without leaving its progress behind.
    await _guarded('undo snapshot', () => _sessions.saveUndoSnapshot(sessionId));
    final completed = await _sessions.complete(sessionId);
    _session = completed;
    await _guarded('progression', () => _progress(completed));
    await _guarded('records', () => _records(completed));
    await _guarded('rotation', () => _programs.advanceAfter(completed.programId, completed.dayId));
    await _guarded('reactive deload', () => _decrementReactiveDeload(completed));
    await _guarded('milestones', _milestones.evaluateNow);
    await _guarded('alarm', _restAlarm.cancel);
    await _guarded('wakelock', _wakelock.disable);
    _status = PlayerStatus.completed;
    _notify();
  }

  Future<void> _guarded(String what, Future<Object?> Function() step) async {
    try {
      await step();
    } on Object catch (e, st) {
      debugPrint('Session completion: $what failed: $e\n$st');
    }
  }

  /// Double progression per exercise (SPEC 6.5). Deload and retest sessions only refresh the best
  /// estimated single.
  Future<void> _progress(Session s) async {
    final eq = equipment;
    final frozen = s.isDeload || s.phaseId == PhaseId.retest;
    for (final se in s.exercises) {
      final ex = _catalog.tryExercise(se.exerciseId);
      if (ex == null || ex.tracking != Tracking.weightReps) continue;
      final working = se.sets.where((x) => x.kind == SetKind.working && x.exerciseId == ex.id).toList()
        ..sort((a, b) => a.setIndex.compareTo(b.setIndex));
      final all = se.sets.where((x) => x.countsAsWork && x.exerciseId == ex.id).toList();
      if (all.isEmpty) continue;
      final prev = await _states.get(ex.id);
      if (frozen || working.isEmpty) {
        final best = _bestE1rm(all, ex, eq);
        if (best == null) continue;
        final base = prev ?? ExerciseState(exerciseId: ex.id, updatedAt: now);
        await _states.put(base.copyWith(
          bestE1rm: () => math.max(base.bestE1rm ?? 0, best),
          firstE1rm: () => base.firstE1rm ?? best,
          updatedAt: now,
        ));
        continue;
      }
      final step = s.plan.exerciseSteps.where((x) => x.slotKey == se.slotKey).firstOrNull;
      final item = (step?.item ?? _fallbackItem(ex)).copyWith(exerciseId: ex.id, sets: _plannedWorking(se));
      final last = await _sessions.lastExposure(ex.id, excludingSessionId: s.id);
      final next = afterSession(prev, ex, item, se.target.targetRir, working, last, eq, _prefs[ex.id], now);
      await _states.put(next.copyWith(lastSessionId: () => s.id, updatedAt: now));
      if (all.any((x) => x.painFlag)) {
        await _states.putPrefs(prefsFor(ex.id).copyWith(lastPainAt: () => now));
      }
    }
  }

  ProgramItem _fallbackItem(Exercise ex) =>
      ProgramItem(exerciseId: ex.id, sets: ex.defaultSets, repRange: ex.repRange, restSeconds: ex.restSeconds, role: ItemRole.accessory);

  double? _bestE1rm(List<SetLog> sets, Exercise ex, EquipmentProfile eq) {
    double? best;
    for (final x in sets) {
      if (x.reps < 1 || x.reps > 12) continue;
      final e = epley1rm(totalLoadKg(x, ex, eq), x.reps);
      if (best == null || e > best) best = e;
    }
    return best;
  }

  /// Stores new records; sets that beat an existing record are marked `is_pr` (the first time an
  /// exercise is done it only sets silent baselines, SPEC 6.11).
  Future<void> _records(Session s) async {
    final sets = s.allSets.where((x) => x.countsAsWork).toList();
    if (sets.isEmpty) return;
    final existing = <String, List<PersonalRecord>>{};
    for (final id in {for (final x in sets) x.exerciseId}) {
      existing[id] = await _states.records(id);
    }
    final prs = detectPrs(sets, existing, _catalog, equipment);
    final marked = <String>{};
    for (final pr in prs) {
      await _states.putRecord(pr);
      final hadBaseline = existing[pr.exerciseId]?.any((r) => r.type == pr.type) ?? false;
      if (hadBaseline) marked.add(pr.setLogId);
    }
    for (final id in marked) {
      final set = sets.where((x) => x.id == id).firstOrNull;
      if (set != null && !set.isPr) await _sessions.updateSet(set.copyWith(isPr: true));
    }
  }

  Future<void> _decrementReactiveDeload(Session s) async {
    if (!s.isDeload) return;
    final program = (await _programs.all()).where((p) => p.id == s.programId).firstOrNull;
    if (program == null || program.reactiveDeloadRemaining <= 0) return;
    await _programs.save(program.copyWith(reactiveDeloadRemaining: program.reactiveDeloadRemaining - 1));
  }

  // ------------------------------------------------------------------------------------------
  // Plumbing
  // ------------------------------------------------------------------------------------------

  /// Runs one event: ignores taps while another event is writing, then repaints.
  Future<void> _run(Future<void> Function() event) async {
    if (_busy || _disposed) return;
    if (_status != PlayerStatus.playing) return;
    _busy = true;
    try {
      await event();
    } finally {
      _busy = false;
      _syncTicker();
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }
}
