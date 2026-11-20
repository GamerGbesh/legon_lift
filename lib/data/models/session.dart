import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/equality.dart';
import '../../domain/api.dart' show FindWeightState, Prescription, SessionPlan;
import 'enums.dart';
import 'json_read.dart';

/// Optional pre-start readiness check-in, each 1..5 (null = not answered).
@immutable
class ReadinessCheck {
  const ReadinessCheck({this.sleep, this.soreness, this.energy});

  static const ReadinessCheck none = ReadinessCheck();

  final int? sleep, soreness, energy;

  bool get isEmpty => sleep == null && soreness == null && energy == null;

  Json toJson() => {'sleep': sleep, 'soreness': soreness, 'energy': energy};

  factory ReadinessCheck.fromJson(Json j) => ReadinessCheck(
        sleep: readIntOrNull(j, 'sleep'),
        soreness: readIntOrNull(j, 'soreness'),
        energy: readIntOrNull(j, 'energy'),
      );

  ReadinessCheck copyWith({int? Function()? sleep, int? Function()? soreness, int? Function()? energy}) => ReadinessCheck(
        sleep: sleep != null ? sleep() : this.sleep,
        soreness: soreness != null ? soreness() : this.soreness,
        energy: energy != null ? energy() : this.energy,
      );

  List<Object?> get _props => [sleep, soreness, energy];
  @override
  bool operator ==(Object other) => other is ReadinessCheck && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}

/// Where the player is (stored as JSON in `sessions.cursor_json`). Restores the exact state after
/// an app kill: step, set, find-weight ramp and rest deadline (SPEC 4.4, 8).
@immutable
class PlayerCursor {
  const PlayerCursor({
    this.stepIndex = 0,
    this.setIndex = 0,
    this.restEndsAt,
    this.findWeight,
    this.visitedSteps = const [],
  });

  static const PlayerCursor start = PlayerCursor();

  final int stepIndex, setIndex;
  final DateTime? restEndsAt;
  final FindWeightState? findWeight;
  final List<int> visitedSteps;

  Json toJson() => {
        'stepIndex': stepIndex,
        'setIndex': setIndex,
        'restEndsAt': instantToJsonOrNull(restEndsAt),
        'findWeight': findWeight?.toJson(),
        'visitedSteps': visitedSteps,
      };

  factory PlayerCursor.fromJson(Json j) => PlayerCursor(
        stepIndex: readInt(j, 'stepIndex'),
        setIndex: readInt(j, 'setIndex'),
        restEndsAt: readInstantOrNull(j, 'restEndsAt'),
        findWeight: readMapOrNull(j, 'findWeight') == null ? null : FindWeightState.fromJson(readMap(j, 'findWeight')),
        visitedSteps: readIntList(j, 'visitedSteps', optional: true),
      );

  PlayerCursor copyWith({
    int? stepIndex,
    int? setIndex,
    DateTime? Function()? restEndsAt,
    FindWeightState? Function()? findWeight,
    List<int>? visitedSteps,
  }) =>
      PlayerCursor(
        stepIndex: stepIndex ?? this.stepIndex,
        setIndex: setIndex ?? this.setIndex,
        restEndsAt: restEndsAt != null ? restEndsAt() : this.restEndsAt,
        findWeight: findWeight != null ? findWeight() : this.findWeight,
        visitedSteps: visitedSteps ?? this.visitedSteps,
      );

  List<Object?> get _props => [stepIndex, setIndex, restEndsAt, findWeight, visitedSteps];
  @override
  bool operator ==(Object other) => other is PlayerCursor && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}

/// A logged set (table `set_logs`). [weightKg] follows SPEC 0.4 (one dumbbell, total bar, ...).
@immutable
class SetLog {
  const SetLog({
    required this.id,
    required this.sessionExerciseId,
    required this.sessionId,
    required this.exerciseId,
    required this.setIndex,
    required this.kind,
    this.targetKg,
    this.targetReps,
    required this.weightKg,
    required this.reps,
    this.durationSec,
    this.rir,
    this.calibrationExtraReps,
    this.painFlag = false,
    required this.completedAt,
    this.isPr = false,
  });

  final String id, sessionExerciseId, sessionId, exerciseId;
  final int setIndex;
  final SetKind kind;
  final double? targetKg;
  final int? targetReps;
  final double weightKg;
  final int reps;
  final int? durationSec;

  /// Reps in reserve answered after the set (0..4, 4 = "4+"); null = not answered.
  final int? rir;
  final int? calibrationExtraReps;
  final bool painFlag;
  final DateTime completedAt;
  final bool isPr;

  /// Working and test sets count for volume, PRs and milestones; warm-up and ramp sets never do.
  bool get countsAsWork => kind == SetKind.working || kind == SetKind.test || kind == SetKind.calibration;

  Json toMap() => {
        'id': id,
        'session_exercise_id': sessionExerciseId,
        'session_id': sessionId,
        'exercise_id': exerciseId,
        'set_index': setIndex,
        'kind': kind.wire,
        'target_kg': targetKg,
        'target_reps': targetReps,
        'weight_kg': weightKg,
        'reps': reps,
        'duration_sec': durationSec,
        'rir': rir,
        'calibration_extra_reps': calibrationExtraReps,
        'pain_flag': boolToInt(painFlag),
        'completed_at': instantToJson(completedAt),
        'is_pr': boolToInt(isPr),
      };

  factory SetLog.fromMap(Json m) => SetLog(
        id: readString(m, 'id'),
        sessionExerciseId: readString(m, 'session_exercise_id'),
        sessionId: readString(m, 'session_id'),
        exerciseId: readString(m, 'exercise_id'),
        setIndex: readInt(m, 'set_index'),
        kind: SetKind.fromWire(readString(m, 'kind')),
        targetKg: readDoubleOrNull(m, 'target_kg'),
        targetReps: readIntOrNull(m, 'target_reps'),
        weightKg: readDouble(m, 'weight_kg'),
        reps: readInt(m, 'reps'),
        durationSec: readIntOrNull(m, 'duration_sec'),
        rir: readIntOrNull(m, 'rir'),
        calibrationExtraReps: readIntOrNull(m, 'calibration_extra_reps'),
        painFlag: readBool(m, 'pain_flag', fallback: false),
        completedAt: readInstant(m, 'completed_at'),
        isPr: readBool(m, 'is_pr', fallback: false),
      );

  Json toJson() => {
        'id': id,
        'sessionExerciseId': sessionExerciseId,
        'sessionId': sessionId,
        'exerciseId': exerciseId,
        'setIndex': setIndex,
        'kind': kind.wire,
        'targetKg': targetKg,
        'targetReps': targetReps,
        'weightKg': weightKg,
        'reps': reps,
        'durationSec': durationSec,
        'rir': rir,
        'calibrationExtraReps': calibrationExtraReps,
        'painFlag': painFlag,
        'completedAt': instantToJson(completedAt),
        'isPr': isPr,
      };

  factory SetLog.fromJson(Json j) => SetLog(
        id: readString(j, 'id'),
        sessionExerciseId: readString(j, 'sessionExerciseId'),
        sessionId: readString(j, 'sessionId'),
        exerciseId: readString(j, 'exerciseId'),
        setIndex: readInt(j, 'setIndex'),
        kind: SetKind.fromWire(readString(j, 'kind')),
        targetKg: readDoubleOrNull(j, 'targetKg'),
        targetReps: readIntOrNull(j, 'targetReps'),
        weightKg: readDouble(j, 'weightKg'),
        reps: readInt(j, 'reps'),
        durationSec: readIntOrNull(j, 'durationSec'),
        rir: readIntOrNull(j, 'rir'),
        calibrationExtraReps: readIntOrNull(j, 'calibrationExtraReps'),
        painFlag: readBool(j, 'painFlag', fallback: false),
        completedAt: readInstant(j, 'completedAt'),
        isPr: readBool(j, 'isPr', fallback: false),
      );

  SetLog copyWith({
    String? id,
    String? sessionExerciseId,
    String? sessionId,
    String? exerciseId,
    int? setIndex,
    SetKind? kind,
    double? Function()? targetKg,
    int? Function()? targetReps,
    double? weightKg,
    int? reps,
    int? Function()? durationSec,
    int? Function()? rir,
    int? Function()? calibrationExtraReps,
    bool? painFlag,
    DateTime? completedAt,
    bool? isPr,
  }) =>
      SetLog(
        id: id ?? this.id,
        sessionExerciseId: sessionExerciseId ?? this.sessionExerciseId,
        sessionId: sessionId ?? this.sessionId,
        exerciseId: exerciseId ?? this.exerciseId,
        setIndex: setIndex ?? this.setIndex,
        kind: kind ?? this.kind,
        targetKg: targetKg != null ? targetKg() : this.targetKg,
        targetReps: targetReps != null ? targetReps() : this.targetReps,
        weightKg: weightKg ?? this.weightKg,
        reps: reps ?? this.reps,
        durationSec: durationSec != null ? durationSec() : this.durationSec,
        rir: rir != null ? rir() : this.rir,
        calibrationExtraReps: calibrationExtraReps != null ? calibrationExtraReps() : this.calibrationExtraReps,
        painFlag: painFlag ?? this.painFlag,
        completedAt: completedAt ?? this.completedAt,
        isPr: isPr ?? this.isPr,
      );

  List<Object?> get _props => [
        id, sessionExerciseId, sessionId, exerciseId, setIndex, kind, targetKg, targetReps, weightKg, reps, //
        durationSec, rir, calibrationExtraReps, painFlag, completedAt, isPr,
      ];
  @override
  bool operator ==(Object other) => other is SetLog && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);

  @override
  String toString() => 'SetLog(${kind.wire} $exerciseId #$setIndex ${weightKg}x$reps rir:$rir)';
}

/// One exercise inside a session (table `session_exercises`) with its logged [sets].
@immutable
class SessionExercise {
  const SessionExercise({
    required this.id,
    required this.sessionId,
    required this.exerciseId,
    required this.slotKey,
    this.originalExerciseId,
    required this.position,
    required this.blockIndex,
    required this.blockType,
    this.supersetGroup,
    required this.role,
    this.status = SessionExerciseStatus.pending,
    this.skipReason,
    required this.target,
    this.note,
    this.sets = const [],
  });

  final String id, sessionId, exerciseId, slotKey;

  /// The planned exercise when this one was swapped in.
  final String? originalExerciseId;
  final int position, blockIndex;
  final BlockType blockType;
  final String? supersetGroup;
  final ItemRole role;
  final SessionExerciseStatus status;
  final SkipReason? skipReason;
  final Prescription target;
  final String? note;
  final List<SetLog> sets;

  Iterable<SetLog> get workingSets => sets.where((s) => s.kind == SetKind.working);

  /// SQLite row ([sets] live in `set_logs`).
  Json toMap() => {
        'id': id,
        'session_id': sessionId,
        'position': position,
        'block_index': blockIndex,
        'block_type': blockType.wire,
        'superset_group': supersetGroup,
        'exercise_id': exerciseId,
        'original_exercise_id': originalExerciseId,
        'slot_key': slotKey,
        'role': role.wire,
        'status': status.wire,
        'skip_reason': skipReason?.wire,
        'target_json': jsonEncode(target.toJson()),
        'note': note,
      };

  factory SessionExercise.fromMap(Json m, {List<SetLog> sets = const []}) {
    final skip = readStringOrNull(m, 'skip_reason');
    return SessionExercise(
      id: readString(m, 'id'),
      sessionId: readString(m, 'session_id'),
      position: readInt(m, 'position'),
      blockIndex: readInt(m, 'block_index'),
      blockType: BlockType.fromWire(readString(m, 'block_type')),
      supersetGroup: readStringOrNull(m, 'superset_group'),
      exerciseId: readString(m, 'exercise_id'),
      originalExerciseId: readStringOrNull(m, 'original_exercise_id'),
      slotKey: readString(m, 'slot_key'),
      role: ItemRole.fromWire(readString(m, 'role')),
      status: SessionExerciseStatus.fromWire(readString(m, 'status')),
      skipReason: skip == null ? null : SkipReason.fromWire(skip),
      target: Prescription.fromJson((jsonDecode(readString(m, 'target_json')) as Map).cast<String, dynamic>()),
      note: readStringOrNull(m, 'note'),
      sets: sets,
    );
  }

  Json toJson() => {
        'id': id,
        'sessionId': sessionId,
        'exerciseId': exerciseId,
        'slotKey': slotKey,
        'originalExerciseId': originalExerciseId,
        'position': position,
        'blockIndex': blockIndex,
        'blockType': blockType.wire,
        'supersetGroup': supersetGroup,
        'role': role.wire,
        'status': status.wire,
        'skipReason': skipReason?.wire,
        'target': target.toJson(),
        'note': note,
        'sets': [for (final s in sets) s.toJson()],
      };

  factory SessionExercise.fromJson(Json j) {
    final skip = readStringOrNull(j, 'skipReason');
    return SessionExercise(
      id: readString(j, 'id'),
      sessionId: readString(j, 'sessionId'),
      exerciseId: readString(j, 'exerciseId'),
      slotKey: readString(j, 'slotKey'),
      originalExerciseId: readStringOrNull(j, 'originalExerciseId'),
      position: readInt(j, 'position'),
      blockIndex: readInt(j, 'blockIndex'),
      blockType: BlockType.fromWire(readString(j, 'blockType')),
      supersetGroup: readStringOrNull(j, 'supersetGroup'),
      role: ItemRole.fromWire(readString(j, 'role')),
      status: SessionExerciseStatus.fromWire(readString(j, 'status')),
      skipReason: skip == null ? null : SkipReason.fromWire(skip),
      target: Prescription.fromJson(readMap(j, 'target')),
      note: readStringOrNull(j, 'note'),
      sets: j['sets'] == null ? const [] : readObjectList(j, 'sets', SetLog.fromJson),
    );
  }

  SessionExercise copyWith({
    String? id,
    String? sessionId,
    String? exerciseId,
    String? slotKey,
    String? Function()? originalExerciseId,
    int? position,
    int? blockIndex,
    BlockType? blockType,
    String? Function()? supersetGroup,
    ItemRole? role,
    SessionExerciseStatus? status,
    SkipReason? Function()? skipReason,
    Prescription? target,
    String? Function()? note,
    List<SetLog>? sets,
  }) =>
      SessionExercise(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        exerciseId: exerciseId ?? this.exerciseId,
        slotKey: slotKey ?? this.slotKey,
        originalExerciseId: originalExerciseId != null ? originalExerciseId() : this.originalExerciseId,
        position: position ?? this.position,
        blockIndex: blockIndex ?? this.blockIndex,
        blockType: blockType ?? this.blockType,
        supersetGroup: supersetGroup != null ? supersetGroup() : this.supersetGroup,
        role: role ?? this.role,
        status: status ?? this.status,
        skipReason: skipReason != null ? skipReason() : this.skipReason,
        target: target ?? this.target,
        note: note != null ? note() : this.note,
        sets: sets ?? this.sets,
      );

  List<Object?> get _props => [
        id, sessionId, exerciseId, slotKey, originalExerciseId, position, blockIndex, blockType, supersetGroup, //
        role, status, skipReason, target, note, sets,
      ];
  @override
  bool operator ==(Object other) => other is SessionExercise && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}

/// A workout (table `sessions`). [plan] is the snapshot built at start; [exercises] are loaded
/// from `session_exercises` + `set_logs`.
@immutable
class Session {
  const Session({
    required this.id,
    required this.programId,
    this.templateId,
    required this.phaseId,
    required this.trainingWeek,
    required this.dayId,
    required this.dayName,
    required this.status,
    required this.startedAt,
    this.endedAt,
    this.isDeload = false,
    this.hotDay = false,
    this.readiness = ReadinessCheck.none,
    this.bodyweightKg,
    this.feeling,
    this.note,
    this.cursor,
    required this.plan,
    this.totalVolumeKg = 0,
    this.exercises = const [],
  });

  final String id, programId;
  final String? templateId;
  final PhaseId phaseId;
  final int trainingWeek;
  final String dayId, dayName;
  final SessionStatus status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final bool isDeload, hotDay;
  final ReadinessCheck readiness;
  final double? bodyweightKg;

  /// 1..5 after the session.
  final int? feeling;
  final String? note;
  final PlayerCursor? cursor;
  final SessionPlan plan;
  final double totalVolumeKg;
  final List<SessionExercise> exercises;

  bool get isInProgress => status == SessionStatus.inProgress;

  Iterable<SetLog> get allSets => exercises.expand((e) => e.sets);

  Duration? get duration => endedAt?.difference(startedAt);

  /// SQLite row without `updated_at` (stamped by the repository); [exercises] are stored separately.
  Json toMap() => {
        'id': id,
        'program_id': programId,
        'template_id': templateId,
        'phase_id': phaseId.wire,
        'training_week': trainingWeek,
        'day_id': dayId,
        'day_name': dayName,
        'status': status.wire,
        'started_at': instantToJson(startedAt),
        'ended_at': instantToJsonOrNull(endedAt),
        'is_deload': boolToInt(isDeload),
        'hot_day': boolToInt(hotDay),
        'readiness_sleep': readiness.sleep,
        'readiness_soreness': readiness.soreness,
        'readiness_energy': readiness.energy,
        'bodyweight_kg': bodyweightKg,
        'feeling': feeling,
        'note': note,
        'cursor_json': cursor == null ? null : jsonEncode(cursor!.toJson()),
        'plan_json': jsonEncode(plan.toJson()),
        'total_volume_kg': totalVolumeKg,
      };

  factory Session.fromMap(Json m, {List<SessionExercise> exercises = const []}) {
    final cursor = readStringOrNull(m, 'cursor_json');
    return Session(
      id: readString(m, 'id'),
      programId: readString(m, 'program_id'),
      templateId: readStringOrNull(m, 'template_id'),
      phaseId: PhaseId.fromWire(readString(m, 'phase_id')),
      trainingWeek: readInt(m, 'training_week'),
      dayId: readString(m, 'day_id'),
      dayName: readString(m, 'day_name'),
      status: SessionStatus.fromWire(readString(m, 'status')),
      startedAt: readInstant(m, 'started_at'),
      endedAt: readInstantOrNull(m, 'ended_at'),
      isDeload: readBool(m, 'is_deload', fallback: false),
      hotDay: readBool(m, 'hot_day', fallback: false),
      readiness: ReadinessCheck(
        sleep: readIntOrNull(m, 'readiness_sleep'),
        soreness: readIntOrNull(m, 'readiness_soreness'),
        energy: readIntOrNull(m, 'readiness_energy'),
      ),
      bodyweightKg: readDoubleOrNull(m, 'bodyweight_kg'),
      feeling: readIntOrNull(m, 'feeling'),
      note: readStringOrNull(m, 'note'),
      cursor: cursor == null ? null : PlayerCursor.fromJson((jsonDecode(cursor) as Map).cast<String, dynamic>()),
      plan: SessionPlan.fromJson((jsonDecode(readString(m, 'plan_json')) as Map).cast<String, dynamic>()),
      totalVolumeKg: readDoubleOrNull(m, 'total_volume_kg') ?? 0,
      exercises: exercises,
    );
  }

  Json toJson() => {
        'id': id,
        'programId': programId,
        'templateId': templateId,
        'phaseId': phaseId.wire,
        'trainingWeek': trainingWeek,
        'dayId': dayId,
        'dayName': dayName,
        'status': status.wire,
        'startedAt': instantToJson(startedAt),
        'endedAt': instantToJsonOrNull(endedAt),
        'isDeload': isDeload,
        'hotDay': hotDay,
        'readiness': readiness.toJson(),
        'bodyweightKg': bodyweightKg,
        'feeling': feeling,
        'note': note,
        'cursor': cursor?.toJson(),
        'plan': plan.toJson(),
        'totalVolumeKg': totalVolumeKg,
        'exercises': [for (final e in exercises) e.toJson()],
      };

  factory Session.fromJson(Json j) => Session(
        id: readString(j, 'id'),
        programId: readString(j, 'programId'),
        templateId: readStringOrNull(j, 'templateId'),
        phaseId: PhaseId.fromWire(readString(j, 'phaseId')),
        trainingWeek: readInt(j, 'trainingWeek'),
        dayId: readString(j, 'dayId'),
        dayName: readString(j, 'dayName'),
        status: SessionStatus.fromWire(readString(j, 'status')),
        startedAt: readInstant(j, 'startedAt'),
        endedAt: readInstantOrNull(j, 'endedAt'),
        isDeload: readBool(j, 'isDeload', fallback: false),
        hotDay: readBool(j, 'hotDay', fallback: false),
        readiness: readMapOrNull(j, 'readiness') == null ? ReadinessCheck.none : ReadinessCheck.fromJson(readMap(j, 'readiness')),
        bodyweightKg: readDoubleOrNull(j, 'bodyweightKg'),
        feeling: readIntOrNull(j, 'feeling'),
        note: readStringOrNull(j, 'note'),
        cursor: readMapOrNull(j, 'cursor') == null ? null : PlayerCursor.fromJson(readMap(j, 'cursor')),
        plan: SessionPlan.fromJson(readMap(j, 'plan')),
        totalVolumeKg: readDoubleOrNull(j, 'totalVolumeKg') ?? 0,
        exercises: j['exercises'] == null ? const [] : readObjectList(j, 'exercises', SessionExercise.fromJson),
      );

  Session copyWith({
    String? id,
    String? programId,
    String? Function()? templateId,
    PhaseId? phaseId,
    int? trainingWeek,
    String? dayId,
    String? dayName,
    SessionStatus? status,
    DateTime? startedAt,
    DateTime? Function()? endedAt,
    bool? isDeload,
    bool? hotDay,
    ReadinessCheck? readiness,
    double? Function()? bodyweightKg,
    int? Function()? feeling,
    String? Function()? note,
    PlayerCursor? Function()? cursor,
    SessionPlan? plan,
    double? totalVolumeKg,
    List<SessionExercise>? exercises,
  }) =>
      Session(
        id: id ?? this.id,
        programId: programId ?? this.programId,
        templateId: templateId != null ? templateId() : this.templateId,
        phaseId: phaseId ?? this.phaseId,
        trainingWeek: trainingWeek ?? this.trainingWeek,
        dayId: dayId ?? this.dayId,
        dayName: dayName ?? this.dayName,
        status: status ?? this.status,
        startedAt: startedAt ?? this.startedAt,
        endedAt: endedAt != null ? endedAt() : this.endedAt,
        isDeload: isDeload ?? this.isDeload,
        hotDay: hotDay ?? this.hotDay,
        readiness: readiness ?? this.readiness,
        bodyweightKg: bodyweightKg != null ? bodyweightKg() : this.bodyweightKg,
        feeling: feeling != null ? feeling() : this.feeling,
        note: note != null ? note() : this.note,
        cursor: cursor != null ? cursor() : this.cursor,
        plan: plan ?? this.plan,
        totalVolumeKg: totalVolumeKg ?? this.totalVolumeKg,
        exercises: exercises ?? this.exercises,
      );

  List<Object?> get _props => [
        id, programId, templateId, phaseId, trainingWeek, dayId, dayName, status, startedAt, endedAt, isDeload, //
        hotDay, readiness, bodyweightKg, feeling, note, cursor, plan, totalVolumeKg, exercises,
      ];
  @override
  bool operator ==(Object other) => other is Session && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);

  @override
  String toString() => 'Session($id $dayId ${status.wire})';
}
