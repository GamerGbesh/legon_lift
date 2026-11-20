import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/equality.dart';
import 'enums.dart';
import 'json_read.dart';

/// Progression state per exercise (table `exercise_state`, SPEC 6.5).
///
/// Nullable fields in [copyWith] take a closure so they can be cleared: `copyWith(workingKg: () => null)`.
@immutable
class ExerciseState {
  const ExerciseState({
    required this.exerciseId,
    this.workingKg,
    this.repTargets = const [],
    this.stallCount = 0,
    this.resetCount = 0,
    this.lastTrend = Trend.calibrate,
    this.lastReason = '',
    this.lastSessionId,
    this.lastRepRange,
    this.firstE1rm,
    this.bestE1rm,
    this.lastJumpPct,
    required this.updatedAt,
  });

  final String exerciseId;

  /// Null until "find your weight" has run (SPEC 6.2).
  final double? workingKg;
  final List<int> repTargets;
  final int stallCount, resetCount;
  final Trend lastTrend;

  /// Plain-language reason shown in "Next time" ("You hit 12, 12, 12 last time: +2.5 kg").
  final String lastReason;
  final String? lastSessionId;
  final (int, int)? lastRepRange;
  final double? firstE1rm, bestE1rm;

  /// Relative size of the last jump, for the post-jump grace rule (SPEC 6.5).
  final double? lastJumpPct;
  final DateTime updatedAt;

  /// Two -10% resets: suggest a variation (Today card "Try a variation?").
  bool get suggestSubstitution => resetCount >= 2;

  Json toMap() => {
        'exercise_id': exerciseId,
        'working_kg': workingKg,
        'rep_targets_json': jsonEncode(repTargets),
        'stall_count': stallCount,
        'reset_count': resetCount,
        'last_trend': lastTrend.wire,
        'last_reason': lastReason,
        'last_session_id': lastSessionId,
        'last_rep_min': lastRepRange?.$1,
        'last_rep_max': lastRepRange?.$2,
        'first_e1rm': firstE1rm,
        'best_e1rm': bestE1rm,
        'last_jump_pct': lastJumpPct,
        'updated_at': instantToJson(updatedAt),
      };

  factory ExerciseState.fromMap(Json m) {
    final lo = readIntOrNull(m, 'last_rep_min');
    final hi = readIntOrNull(m, 'last_rep_max');
    return ExerciseState(
      exerciseId: readString(m, 'exercise_id'),
      workingKg: readDoubleOrNull(m, 'working_kg'),
      repTargets: (jsonDecode(readStringOrNull(m, 'rep_targets_json') ?? '[]') as List).map((e) => (e as num).toInt()).toList(),
      stallCount: readIntOrNull(m, 'stall_count') ?? 0,
      resetCount: readIntOrNull(m, 'reset_count') ?? 0,
      lastTrend: Trend.fromWire(readStringOrNull(m, 'last_trend') ?? 'calibrate'),
      lastReason: readStringOrNull(m, 'last_reason') ?? '',
      lastSessionId: readStringOrNull(m, 'last_session_id'),
      lastRepRange: lo == null || hi == null ? null : (lo, hi),
      firstE1rm: readDoubleOrNull(m, 'first_e1rm'),
      bestE1rm: readDoubleOrNull(m, 'best_e1rm'),
      lastJumpPct: readDoubleOrNull(m, 'last_jump_pct'),
      updatedAt: readInstant(m, 'updated_at'),
    );
  }

  Json toJson() => {
        'exerciseId': exerciseId,
        'workingKg': workingKg,
        'repTargets': repTargets,
        'stallCount': stallCount,
        'resetCount': resetCount,
        'lastTrend': lastTrend.wire,
        'lastReason': lastReason,
        'lastSessionId': lastSessionId,
        'lastRepRange': rangeToJson(lastRepRange),
        'firstE1rm': firstE1rm,
        'bestE1rm': bestE1rm,
        'lastJumpPct': lastJumpPct,
        'updatedAt': instantToJson(updatedAt),
      };

  factory ExerciseState.fromJson(Json j) => ExerciseState(
        exerciseId: readString(j, 'exerciseId'),
        workingKg: readDoubleOrNull(j, 'workingKg'),
        repTargets: readIntList(j, 'repTargets', optional: true),
        stallCount: readIntOrNull(j, 'stallCount') ?? 0,
        resetCount: readIntOrNull(j, 'resetCount') ?? 0,
        lastTrend: Trend.fromWire(readStringOrNull(j, 'lastTrend') ?? 'calibrate'),
        lastReason: readStringOrNull(j, 'lastReason') ?? '',
        lastSessionId: readStringOrNull(j, 'lastSessionId'),
        lastRepRange: readRangeOrNull(j, 'lastRepRange'),
        firstE1rm: readDoubleOrNull(j, 'firstE1rm'),
        bestE1rm: readDoubleOrNull(j, 'bestE1rm'),
        lastJumpPct: readDoubleOrNull(j, 'lastJumpPct'),
        updatedAt: readInstant(j, 'updatedAt'),
      );

  ExerciseState copyWith({
    String? exerciseId,
    double? Function()? workingKg,
    List<int>? repTargets,
    int? stallCount,
    int? resetCount,
    Trend? lastTrend,
    String? lastReason,
    String? Function()? lastSessionId,
    (int, int)? Function()? lastRepRange,
    double? Function()? firstE1rm,
    double? Function()? bestE1rm,
    double? Function()? lastJumpPct,
    DateTime? updatedAt,
  }) =>
      ExerciseState(
        exerciseId: exerciseId ?? this.exerciseId,
        workingKg: workingKg != null ? workingKg() : this.workingKg,
        repTargets: repTargets ?? this.repTargets,
        stallCount: stallCount ?? this.stallCount,
        resetCount: resetCount ?? this.resetCount,
        lastTrend: lastTrend ?? this.lastTrend,
        lastReason: lastReason ?? this.lastReason,
        lastSessionId: lastSessionId != null ? lastSessionId() : this.lastSessionId,
        lastRepRange: lastRepRange != null ? lastRepRange() : this.lastRepRange,
        firstE1rm: firstE1rm != null ? firstE1rm() : this.firstE1rm,
        bestE1rm: bestE1rm != null ? bestE1rm() : this.bestE1rm,
        lastJumpPct: lastJumpPct != null ? lastJumpPct() : this.lastJumpPct,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  List<Object?> get _props => [
        exerciseId, workingKg, repTargets, stallCount, resetCount, lastTrend, lastReason, lastSessionId, //
        lastRepRange, firstE1rm, bestE1rm, lastJumpPct, updatedAt,
      ];
  @override
  bool operator ==(Object other) => other is ExerciseState && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);

  @override
  String toString() => 'ExerciseState($exerciseId w:$workingKg reps:$repTargets ${lastTrend.wire})';
}

/// Best value per exercise and type (table `personal_records`). Values use totalLoadKg (SPEC 0.4).
@immutable
class PersonalRecord {
  const PersonalRecord({
    required this.exerciseId,
    required this.type,
    required this.value,
    required this.setLogId,
    required this.achievedAt,
  });

  final String exerciseId;
  final PrType type;
  final double value;
  final String setLogId;
  final DateTime achievedAt;

  Json toMap() => {
        'exercise_id': exerciseId,
        'type': type.wire,
        'value': value,
        'set_log_id': setLogId,
        'achieved_at': instantToJson(achievedAt),
      };

  factory PersonalRecord.fromMap(Json m) => PersonalRecord(
        exerciseId: readString(m, 'exercise_id'),
        type: PrType.fromWire(readString(m, 'type')),
        value: readDouble(m, 'value'),
        setLogId: readString(m, 'set_log_id'),
        achievedAt: readInstant(m, 'achieved_at'),
      );

  Json toJson() => {
        'exerciseId': exerciseId,
        'type': type.wire,
        'value': value,
        'setLogId': setLogId,
        'achievedAt': instantToJson(achievedAt),
      };

  factory PersonalRecord.fromJson(Json j) => PersonalRecord(
        exerciseId: readString(j, 'exerciseId'),
        type: PrType.fromWire(readString(j, 'type')),
        value: readDouble(j, 'value'),
        setLogId: readString(j, 'setLogId'),
        achievedAt: readInstant(j, 'achievedAt'),
      );

  PersonalRecord copyWith({String? exerciseId, PrType? type, double? value, String? setLogId, DateTime? achievedAt}) =>
      PersonalRecord(
        exerciseId: exerciseId ?? this.exerciseId,
        type: type ?? this.type,
        value: value ?? this.value,
        setLogId: setLogId ?? this.setLogId,
        achievedAt: achievedAt ?? this.achievedAt,
      );

  List<Object?> get _props => [exerciseId, type, value, setLogId, achievedAt];
  @override
  bool operator ==(Object other) => other is PersonalRecord && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}

/// Per-exercise user preferences (table `exercise_prefs`).
@immutable
class ExercisePrefs {
  const ExercisePrefs({
    required this.exerciseId,
    this.favorite = false,
    this.hidden = false,
    this.incrementKg,
    this.machineNote,
    this.lastPainAt,
  });

  /// Defaults for an exercise without a row.
  const ExercisePrefs.empty(this.exerciseId)
      : favorite = false,
        hidden = false,
        incrementKg = null,
        machineNote = null,
        lastPainAt = null;

  final String exerciseId;
  final bool favorite;

  /// "Not at this gym": never suggested again (Settings > Equipment can undo).
  final bool hidden;
  final double? incrementKg;

  /// "seat 4".
  final String? machineNote;
  final DateTime? lastPainAt;

  Json toMap() => {
        'exercise_id': exerciseId,
        'favorite': boolToInt(favorite),
        'hidden': boolToInt(hidden),
        'increment_kg': incrementKg,
        'machine_note': machineNote,
        'last_pain_at': instantToJsonOrNull(lastPainAt),
      };

  factory ExercisePrefs.fromMap(Json m) => ExercisePrefs(
        exerciseId: readString(m, 'exercise_id'),
        favorite: readBool(m, 'favorite', fallback: false),
        hidden: readBool(m, 'hidden', fallback: false),
        incrementKg: readDoubleOrNull(m, 'increment_kg'),
        machineNote: readStringOrNull(m, 'machine_note'),
        lastPainAt: readInstantOrNull(m, 'last_pain_at'),
      );

  Json toJson() => {
        'exerciseId': exerciseId,
        'favorite': favorite,
        'hidden': hidden,
        'incrementKg': incrementKg,
        'machineNote': machineNote,
        'lastPainAt': instantToJsonOrNull(lastPainAt),
      };

  factory ExercisePrefs.fromJson(Json j) => ExercisePrefs(
        exerciseId: readString(j, 'exerciseId'),
        favorite: readBool(j, 'favorite', fallback: false),
        hidden: readBool(j, 'hidden', fallback: false),
        incrementKg: readDoubleOrNull(j, 'incrementKg'),
        machineNote: readStringOrNull(j, 'machineNote'),
        lastPainAt: readInstantOrNull(j, 'lastPainAt'),
      );

  ExercisePrefs copyWith({
    String? exerciseId,
    bool? favorite,
    bool? hidden,
    double? Function()? incrementKg,
    String? Function()? machineNote,
    DateTime? Function()? lastPainAt,
  }) =>
      ExercisePrefs(
        exerciseId: exerciseId ?? this.exerciseId,
        favorite: favorite ?? this.favorite,
        hidden: hidden ?? this.hidden,
        incrementKg: incrementKg != null ? incrementKg() : this.incrementKg,
        machineNote: machineNote != null ? machineNote() : this.machineNote,
        lastPainAt: lastPainAt != null ? lastPainAt() : this.lastPainAt,
      );

  List<Object?> get _props => [exerciseId, favorite, hidden, incrementKg, machineNote, lastPainAt];
  @override
  bool operator ==(Object other) => other is ExercisePrefs && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}
