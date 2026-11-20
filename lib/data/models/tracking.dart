import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/equality.dart';
import 'json_read.dart';

/// Body weight / waist for one calendar date (`yyyy-MM-dd`, one entry per date; table `body_entries`).
@immutable
class BodyEntry {
  const BodyEntry({required this.date, this.weightKg, this.waistCm, this.note});

  final String date;
  final double? weightKg, waistCm;
  final String? note;

  /// Row without `updated_at` (stamped by the repository).
  Json toMap() => {'date': date, 'weight_kg': weightKg, 'waist_cm': waistCm, 'note': note};

  factory BodyEntry.fromMap(Json m) => BodyEntry(
        date: readString(m, 'date'),
        weightKg: readDoubleOrNull(m, 'weight_kg'),
        waistCm: readDoubleOrNull(m, 'waist_cm'),
        note: readStringOrNull(m, 'note'),
      );

  Json toJson() => {'date': date, 'weightKg': weightKg, 'waistCm': waistCm, 'note': note};

  factory BodyEntry.fromJson(Json j) => BodyEntry(
        date: readString(j, 'date'),
        weightKg: readDoubleOrNull(j, 'weightKg'),
        waistCm: readDoubleOrNull(j, 'waistCm'),
        note: readStringOrNull(j, 'note'),
      );

  BodyEntry copyWith({
    String? date,
    double? Function()? weightKg,
    double? Function()? waistCm,
    String? Function()? note,
  }) =>
      BodyEntry(
        date: date ?? this.date,
        weightKg: weightKg != null ? weightKg() : this.weightKg,
        waistCm: waistCm != null ? waistCm() : this.waistCm,
        note: note != null ? note() : this.note,
      );

  List<Object?> get _props => [date, weightKg, waistCm, note];
  @override
  bool operator ==(Object other) => other is BodyEntry && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}

/// Daily nutrition checklist (table `nutrition_days`). Not a food log.
@immutable
class NutritionDay {
  const NutritionDay({
    required this.date,
    this.proteinPoints = 0,
    this.waterSachets = 0,
    this.vegFruit = false,
    this.stepsHit = false,
    this.sleepOk = false,
    this.noSugaryDrinks = false,
    this.steps,
  });

  /// An untouched day.
  const NutritionDay.empty(this.date)
      : proteinPoints = 0,
        waterSachets = 0,
        vegFruit = false,
        stepsHit = false,
        sleepOk = false,
        noSugaryDrinks = false,
        steps = null;

  final String date;

  /// Points of 20 g protein, in 0.5 steps.
  final double proteinPoints;

  /// 500 ml sachets.
  final double waterSachets;
  final bool vegFruit, stepsHit, sleepOk, noSugaryDrinks;
  final int? steps;

  /// Row without `updated_at` (stamped by the repository).
  Json toMap() => {
        'date': date,
        'protein_points': proteinPoints,
        'water_sachets': waterSachets,
        'veg_fruit': boolToInt(vegFruit),
        'steps_hit': boolToInt(stepsHit),
        'steps': steps,
        'sleep_ok': boolToInt(sleepOk),
        'no_sugary_drinks': boolToInt(noSugaryDrinks),
      };

  factory NutritionDay.fromMap(Json m) => NutritionDay(
        date: readString(m, 'date'),
        proteinPoints: readDoubleOrNull(m, 'protein_points') ?? 0,
        waterSachets: readDoubleOrNull(m, 'water_sachets') ?? 0,
        vegFruit: readBool(m, 'veg_fruit', fallback: false),
        stepsHit: readBool(m, 'steps_hit', fallback: false),
        steps: readIntOrNull(m, 'steps'),
        sleepOk: readBool(m, 'sleep_ok', fallback: false),
        noSugaryDrinks: readBool(m, 'no_sugary_drinks', fallback: false),
      );

  Json toJson() => {
        'date': date,
        'proteinPoints': proteinPoints,
        'waterSachets': waterSachets,
        'vegFruit': vegFruit,
        'stepsHit': stepsHit,
        'sleepOk': sleepOk,
        'noSugaryDrinks': noSugaryDrinks,
        'steps': steps,
      };

  factory NutritionDay.fromJson(Json j) => NutritionDay(
        date: readString(j, 'date'),
        proteinPoints: readDoubleOrNull(j, 'proteinPoints') ?? 0,
        waterSachets: readDoubleOrNull(j, 'waterSachets') ?? 0,
        vegFruit: readBool(j, 'vegFruit', fallback: false),
        stepsHit: readBool(j, 'stepsHit', fallback: false),
        sleepOk: readBool(j, 'sleepOk', fallback: false),
        noSugaryDrinks: readBool(j, 'noSugaryDrinks', fallback: false),
        steps: readIntOrNull(j, 'steps'),
      );

  NutritionDay copyWith({
    String? date,
    double? proteinPoints,
    double? waterSachets,
    bool? vegFruit,
    bool? stepsHit,
    bool? sleepOk,
    bool? noSugaryDrinks,
    int? Function()? steps,
  }) =>
      NutritionDay(
        date: date ?? this.date,
        proteinPoints: proteinPoints ?? this.proteinPoints,
        waterSachets: waterSachets ?? this.waterSachets,
        vegFruit: vegFruit ?? this.vegFruit,
        stepsHit: stepsHit ?? this.stepsHit,
        sleepOk: sleepOk ?? this.sleepOk,
        noSugaryDrinks: noSugaryDrinks ?? this.noSugaryDrinks,
        steps: steps != null ? steps() : this.steps,
      );

  List<Object?> get _props => [date, proteinPoints, waterSachets, vegFruit, stepsHit, sleepOk, noSugaryDrinks, steps];
  @override
  bool operator ==(Object other) => other is NutritionDay && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}

/// Rest-day cardio ("Log cardio" on Today; table `cardio_logs`).
@immutable
class CardioLog {
  const CardioLog({required this.id, required this.date, required this.exerciseId, required this.durationSec, this.note});

  final String id, date, exerciseId;
  final int durationSec;
  final String? note;

  Json toMap() => {'id': id, 'date': date, 'exercise_id': exerciseId, 'duration_sec': durationSec, 'note': note};

  factory CardioLog.fromMap(Json m) => CardioLog(
        id: readString(m, 'id'),
        date: readString(m, 'date'),
        exerciseId: readString(m, 'exercise_id'),
        durationSec: readInt(m, 'duration_sec'),
        note: readStringOrNull(m, 'note'),
      );

  Json toJson() => {'id': id, 'date': date, 'exerciseId': exerciseId, 'durationSec': durationSec, 'note': note};

  factory CardioLog.fromJson(Json j) => CardioLog(
        id: readString(j, 'id'),
        date: readString(j, 'date'),
        exerciseId: readString(j, 'exerciseId'),
        durationSec: readInt(j, 'durationSec'),
        note: readStringOrNull(j, 'note'),
      );

  CardioLog copyWith({String? id, String? date, String? exerciseId, int? durationSec, String? Function()? note}) => CardioLog(
        id: id ?? this.id,
        date: date ?? this.date,
        exerciseId: exerciseId ?? this.exerciseId,
        durationSec: durationSec ?? this.durationSec,
        note: note != null ? note() : this.note,
      );

  List<Object?> get _props => [id, date, exerciseId, durationSec, note];
  @override
  bool operator ==(Object other) => other is CardioLog && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}

/// An earned badge (table `milestone_awards`).
@immutable
class MilestoneAward {
  const MilestoneAward({required this.milestoneId, required this.awardedAt, this.context = const {}});

  final String milestoneId;
  final DateTime awardedAt;

  /// What triggered it (session id, exercise, value ...), JSON-safe values only.
  final Map<String, Object?> context;

  Json toMap() => {
        'milestone_id': milestoneId,
        'awarded_at': instantToJson(awardedAt),
        'context_json': context.isEmpty ? null : jsonEncode(context),
      };

  factory MilestoneAward.fromMap(Json m) {
    final ctx = readStringOrNull(m, 'context_json');
    return MilestoneAward(
      milestoneId: readString(m, 'milestone_id'),
      awardedAt: readInstant(m, 'awarded_at'),
      context: ctx == null ? const {} : (jsonDecode(ctx) as Map).cast<String, Object?>(),
    );
  }

  Json toJson() => {'milestoneId': milestoneId, 'awardedAt': instantToJson(awardedAt), 'context': context};

  factory MilestoneAward.fromJson(Json j) => MilestoneAward(
        milestoneId: readString(j, 'milestoneId'),
        awardedAt: readInstant(j, 'awardedAt'),
        context: (readMapOrNull(j, 'context') ?? const {}).cast<String, Object?>(),
      );

  MilestoneAward copyWith({String? milestoneId, DateTime? awardedAt, Map<String, Object?>? context}) => MilestoneAward(
        milestoneId: milestoneId ?? this.milestoneId,
        awardedAt: awardedAt ?? this.awardedAt,
        context: context ?? this.context,
      );

  List<Object?> get _props => [milestoneId, awardedAt, context];
  @override
  bool operator ==(Object other) => other is MilestoneAward && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}

/// Pause mode or a tag period (exams, Ramadan ...), table `pauses`. Dates are `yyyy-MM-dd`.
@immutable
class Pause {
  const Pause({required this.id, required this.kind, required this.reason, required this.startDate, this.endDate});

  static const String kindPause = 'pause';
  static const String kindTag = 'tag';

  final String id;

  /// [kindPause] or [kindTag].
  final String kind;
  final String reason;
  final String startDate;

  /// Null while still running.
  final String? endDate;

  Json toMap() => {'id': id, 'kind': kind, 'reason': reason, 'start_date': startDate, 'end_date': endDate};

  factory Pause.fromMap(Json m) => Pause(
        id: readString(m, 'id'),
        kind: readString(m, 'kind'),
        reason: readString(m, 'reason'),
        startDate: readString(m, 'start_date'),
        endDate: readStringOrNull(m, 'end_date'),
      );

  Json toJson() => {'id': id, 'kind': kind, 'reason': reason, 'startDate': startDate, 'endDate': endDate};

  factory Pause.fromJson(Json j) => Pause(
        id: readString(j, 'id'),
        kind: readString(j, 'kind'),
        reason: readString(j, 'reason'),
        startDate: readString(j, 'startDate'),
        endDate: readStringOrNull(j, 'endDate'),
      );

  Pause copyWith({String? id, String? kind, String? reason, String? startDate, String? Function()? endDate}) => Pause(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        reason: reason ?? this.reason,
        startDate: startDate ?? this.startDate,
        endDate: endDate != null ? endDate() : this.endDate,
      );

  List<Object?> get _props => [id, kind, reason, startDate, endDate];
  @override
  bool operator ==(Object other) => other is Pause && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}

/// An applied weekly check-in change (table `calorie_adjustments`, SPEC 10.2).
@immutable
class CalorieAdjustment {
  const CalorieAdjustment({required this.id, required this.date, required this.ruleId, required this.deltaKcal, this.deltaSteps});

  final String id, date, ruleId;
  final int deltaKcal;
  final int? deltaSteps;

  Json toMap() => {'id': id, 'date': date, 'rule_id': ruleId, 'delta_kcal': deltaKcal, 'delta_steps': deltaSteps};

  factory CalorieAdjustment.fromMap(Json m) => CalorieAdjustment(
        id: readString(m, 'id'),
        date: readString(m, 'date'),
        ruleId: readString(m, 'rule_id'),
        deltaKcal: readIntOrNull(m, 'delta_kcal') ?? 0,
        deltaSteps: readIntOrNull(m, 'delta_steps'),
      );

  Json toJson() => {'id': id, 'date': date, 'ruleId': ruleId, 'deltaKcal': deltaKcal, 'deltaSteps': deltaSteps};

  factory CalorieAdjustment.fromJson(Json j) => CalorieAdjustment(
        id: readString(j, 'id'),
        date: readString(j, 'date'),
        ruleId: readString(j, 'ruleId'),
        deltaKcal: readInt(j, 'deltaKcal'),
        deltaSteps: readIntOrNull(j, 'deltaSteps'),
      );

  CalorieAdjustment copyWith({String? id, String? date, String? ruleId, int? deltaKcal, int? Function()? deltaSteps}) =>
      CalorieAdjustment(
        id: id ?? this.id,
        date: date ?? this.date,
        ruleId: ruleId ?? this.ruleId,
        deltaKcal: deltaKcal ?? this.deltaKcal,
        deltaSteps: deltaSteps != null ? deltaSteps() : this.deltaSteps,
      );

  List<Object?> get _props => [id, date, ruleId, deltaKcal, deltaSteps];
  @override
  bool operator ==(Object other) => other is CalorieAdjustment && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}
