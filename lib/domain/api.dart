/// Domain API (SPEC 5.3 domain types and 7.2). Frozen after Phase 0: change by RFC only.
///
/// This file holds the domain value types and re-exports every domain file, so features import
/// just `package:legon_lift/domain/api.dart`. Function implementations live in the owner files
/// (WS2: training engine; WS6: nutrition, milestones, adherence, check-in).
library;

import 'package:flutter/foundation.dart';

import '../core/equality.dart';
import '../data/assets/asset_catalog.dart';
import '../data/models/json_read.dart';
import '../data/models/models.dart';

export 'adherence.dart';
export 'checkin_advisor.dart';
export 'deload_advisor.dart';
export 'duration_estimator.dart';
export 'find_weight.dart';
export 'load_rounding.dart';
export 'milestone_evaluator.dart';
export 'nutrition_calculator.dart';
export 'one_rep_max.dart';
export 'plate_calculator.dart';
export 'pr_detector.dart';
export 'progression_engine.dart';
export 'schedule.dart';
export 'session_builder.dart';
export 'stats.dart';
export 'swap_suggester.dart';
export 'warmup_planner.dart';

// ---------------------------------------------------------------------------------------------
// Prescriptions and session plans (persisted as JSON inside sessions.plan_json / target_json)
// ---------------------------------------------------------------------------------------------

/// One planned set. For `Tracking.time` items [reps] is 0 and [durationSec] is set.
@immutable
class PlannedSet {
  const PlannedSet({required this.kind, required this.weightKg, required this.reps, this.durationSec, this.targetRir});

  final SetKind kind;

  /// Weight semantics of SPEC 0.4 (one dumbbell, total bar, added plates, pin).
  final double weightKg;
  final int reps;
  final int? durationSec;
  final int? targetRir;

  Json toJson() => {
        'kind': kind.wire,
        'weightKg': weightKg,
        'reps': reps,
        'durationSec': durationSec,
        'targetRir': targetRir,
      };

  factory PlannedSet.fromJson(Json j) => PlannedSet(
        kind: SetKind.fromWire(readString(j, 'kind')),
        weightKg: readDouble(j, 'weightKg'),
        reps: readInt(j, 'reps'),
        durationSec: readIntOrNull(j, 'durationSec'),
        targetRir: readIntOrNull(j, 'targetRir'),
      );

  PlannedSet copyWith({
    SetKind? kind,
    double? weightKg,
    int? reps,
    int? Function()? durationSec,
    int? Function()? targetRir,
  }) =>
      PlannedSet(
        kind: kind ?? this.kind,
        weightKg: weightKg ?? this.weightKg,
        reps: reps ?? this.reps,
        durationSec: durationSec != null ? durationSec() : this.durationSec,
        targetRir: targetRir != null ? targetRir() : this.targetRir,
      );

  List<Object?> get _props => [kind, weightKg, reps, durationSec, targetRir];
  @override
  bool operator ==(Object other) => other is PlannedSet && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);

  @override
  String toString() => 'PlannedSet(${kind.wire} ${weightKg}x$reps${durationSec == null ? '' : ' ${durationSec}s'})';
}

/// What to do for one exercise today (SPEC 6.5 `prescribe`).
@immutable
class Prescription {
  const Prescription({
    required this.exerciseId,
    this.warmups = const [],
    required this.working,
    required this.restSec,
    this.targetRir,
    this.trend = Trend.same,
    this.reason = '',
    this.findWeight = false,
    this.incrementKg = 2.5,
  });

  final String exerciseId;
  final List<PlannedSet> warmups;
  final List<PlannedSet> working;
  final int restSec;
  final int? targetRir;
  final Trend trend;

  /// Plain-language reason ("First time: we'll find your weight").
  final String reason;

  /// True when this exercise starts with the "find your weight" ramp (SPEC 6.2).
  final bool findWeight;
  final double incrementKg;

  Json toJson() => {
        'exerciseId': exerciseId,
        'warmups': [for (final s in warmups) s.toJson()],
        'working': [for (final s in working) s.toJson()],
        'restSec': restSec,
        'targetRir': targetRir,
        'trend': trend.wire,
        'reason': reason,
        'findWeight': findWeight,
        'incrementKg': incrementKg,
      };

  factory Prescription.fromJson(Json j) => Prescription(
        exerciseId: readString(j, 'exerciseId'),
        warmups: readObjectList(j, 'warmups', PlannedSet.fromJson),
        working: readObjectList(j, 'working', PlannedSet.fromJson),
        restSec: readInt(j, 'restSec'),
        targetRir: readIntOrNull(j, 'targetRir'),
        trend: Trend.fromWire(readString(j, 'trend')),
        reason: readStringOrNull(j, 'reason') ?? '',
        findWeight: readBool(j, 'findWeight', fallback: false),
        incrementKg: readDoubleOrNull(j, 'incrementKg') ?? 2.5,
      );

  Prescription copyWith({
    String? exerciseId,
    List<PlannedSet>? warmups,
    List<PlannedSet>? working,
    int? restSec,
    int? Function()? targetRir,
    Trend? trend,
    String? reason,
    bool? findWeight,
    double? incrementKg,
  }) =>
      Prescription(
        exerciseId: exerciseId ?? this.exerciseId,
        warmups: warmups ?? this.warmups,
        working: working ?? this.working,
        restSec: restSec ?? this.restSec,
        targetRir: targetRir != null ? targetRir() : this.targetRir,
        trend: trend ?? this.trend,
        reason: reason ?? this.reason,
        findWeight: findWeight ?? this.findWeight,
        incrementKg: incrementKg ?? this.incrementKg,
      );

  List<Object?> get _props => [exerciseId, warmups, working, restSec, targetRir, trend, reason, findWeight, incrementKg];
  @override
  bool operator ==(Object other) => other is Prescription && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}

/// One step of the player's flat step list (SPEC 4.4 / 6.8). [index] is the position in
/// [SessionPlan.steps]. JSON carries a `type` discriminator.
@immutable
sealed class SessionStep {
  const SessionStep({required this.index});

  final int index;

  Json toJson();

  /// Exercise ids this step touches, in order.
  List<String> get exerciseIds;

  factory SessionStep.fromJson(Json j) {
    final type = readString(j, 'type');
    final index = readInt(j, 'index');
    return switch (type) {
      'warmupCardio' => WarmupCardioStep(index: index, item: ProgramItem.fromJson(readMap(j, 'item'))),
      'mobility' => MobilityStep(index: index, items: readObjectList(j, 'items', ProgramItem.fromJson)),
      'exercise' => ExerciseStep.fromJson(j),
      'superset' => SupersetStep(
          index: index,
          group: readString(j, 'group'),
          members: readObjectList(j, 'members', ExerciseStep.fromJson),
          roundRestSec: readInt(j, 'roundRestSec'),
        ),
      'finisher' => FinisherStep(
          index: index,
          item: ProgramItem.fromJson(readMap(j, 'item')),
          durationSec: readInt(j, 'durationSec'),
        ),
      'extras' => ExtrasStep(index: index, extras: readObjectList(j, 'extras', ExerciseStep.fromJson)),
      'cooldown' => CooldownStep(index: index, items: readObjectList(j, 'items', ProgramItem.fromJson)),
      _ => throw FormatException('Unknown SessionStep type "$type"'),
    };
  }

  /// Same step at another position.
  SessionStep withIndex(int index);
}

/// Warm-up cardio (bike or treadmill, timed).
final class WarmupCardioStep extends SessionStep {
  const WarmupCardioStep({required super.index, required this.item});

  final ProgramItem item;

  @override
  List<String> get exerciseIds => [item.exerciseId];

  @override
  Json toJson() => {'type': 'warmupCardio', 'index': index, 'item': item.toJson()};

  @override
  WarmupCardioStep withIndex(int index) => WarmupCardioStep(index: index, item: item);

  @override
  bool operator ==(Object other) => other is WarmupCardioStep && other.index == index && other.item == item;
  @override
  int get hashCode => Object.hash('warmupCardio', index, item);
}

/// Warm-up drills checklist.
final class MobilityStep extends SessionStep {
  const MobilityStep({required super.index, required this.items});

  final List<ProgramItem> items;

  @override
  List<String> get exerciseIds => [for (final i in items) i.exerciseId];

  @override
  Json toJson() => {'type': 'mobility', 'index': index, 'items': [for (final i in items) i.toJson()]};

  @override
  MobilityStep withIndex(int index) => MobilityStep(index: index, items: items);

  @override
  bool operator ==(Object other) => other is MobilityStep && other.index == index && propsEqual(items, other.items);
  @override
  int get hashCode => Object.hash('mobility', index, propsHash(items));
}

/// A main exercise with its prescription.
final class ExerciseStep extends SessionStep {
  const ExerciseStep({required super.index, required this.item, required this.rx, required this.slotKey});

  /// The program item, with `exerciseId` already resolved (override, limitation or equipment swap).
  final ProgramItem item;
  final Prescription rx;

  /// The template slot this step fills ([ProgramItem.slotKey] of the original item).
  final String slotKey;

  @override
  List<String> get exerciseIds => [item.exerciseId];

  factory ExerciseStep.fromJson(Json j) => ExerciseStep(
        index: readInt(j, 'index'),
        item: ProgramItem.fromJson(readMap(j, 'item')),
        rx: Prescription.fromJson(readMap(j, 'rx')),
        slotKey: readString(j, 'slotKey'),
      );

  @override
  Json toJson() => {'type': 'exercise', 'index': index, 'item': item.toJson(), 'rx': rx.toJson(), 'slotKey': slotKey};

  @override
  ExerciseStep withIndex(int index) => ExerciseStep(index: index, item: item, rx: rx, slotKey: slotKey);

  ExerciseStep copyWith({int? index, ProgramItem? item, Prescription? rx, String? slotKey}) => ExerciseStep(
        index: index ?? this.index,
        item: item ?? this.item,
        rx: rx ?? this.rx,
        slotKey: slotKey ?? this.slotKey,
      );

  @override
  bool operator ==(Object other) =>
      other is ExerciseStep && other.index == index && other.item == item && other.rx == rx && other.slotKey == slotKey;
  @override
  int get hashCode => Object.hash('exercise', index, item, rx, slotKey);
}

/// A superset ("pair: alternate these two"): A1, B1, rest, A2, B2 ...
final class SupersetStep extends SessionStep {
  const SupersetStep({required super.index, required this.group, required this.members, required this.roundRestSec});

  final String group;
  final List<ExerciseStep> members;
  final int roundRestSec;

  @override
  List<String> get exerciseIds => [for (final m in members) m.item.exerciseId];

  @override
  Json toJson() => {
        'type': 'superset',
        'index': index,
        'group': group,
        'members': [for (final m in members) m.toJson()],
        'roundRestSec': roundRestSec,
      };

  @override
  SupersetStep withIndex(int index) => SupersetStep(index: index, group: group, members: members, roundRestSec: roundRestSec);

  @override
  bool operator ==(Object other) =>
      other is SupersetStep &&
      other.index == index &&
      other.group == group &&
      other.roundRestSec == roundRestSec &&
      propsEqual(members, other.members);
  @override
  int get hashCode => Object.hash('superset', index, group, roundRestSec, propsHash(members));
}

/// The cardio finisher (timed).
final class FinisherStep extends SessionStep {
  const FinisherStep({required super.index, required this.item, required this.durationSec});

  final ProgramItem item;
  final int durationSec;

  @override
  List<String> get exerciseIds => [item.exerciseId];

  @override
  Json toJson() => {'type': 'finisher', 'index': index, 'item': item.toJson(), 'durationSec': durationSec};

  @override
  FinisherStep withIndex(int index) => FinisherStep(index: index, item: item, durationSec: durationSec);

  @override
  bool operator ==(Object other) =>
      other is FinisherStep && other.index == index && other.item == item && other.durationSec == durationSec;
  @override
  int get hashCode => Object.hash('finisher', index, item, durationSec);
}

/// "Extras if you have time" (SPEC 6.8): placed after the main work, before finisher/cool-down.
final class ExtrasStep extends SessionStep {
  const ExtrasStep({required super.index, required this.extras});

  final List<ExerciseStep> extras;

  @override
  List<String> get exerciseIds => [for (final e in extras) e.item.exerciseId];

  @override
  Json toJson() => {'type': 'extras', 'index': index, 'extras': [for (final e in extras) e.toJson()]};

  @override
  ExtrasStep withIndex(int index) => ExtrasStep(index: index, extras: extras);

  @override
  bool operator ==(Object other) => other is ExtrasStep && other.index == index && propsEqual(extras, other.extras);
  @override
  int get hashCode => Object.hash('extras', index, propsHash(extras));
}

/// Cool-down walk and stretches.
final class CooldownStep extends SessionStep {
  const CooldownStep({required super.index, required this.items});

  final List<ProgramItem> items;

  @override
  List<String> get exerciseIds => [for (final i in items) i.exerciseId];

  @override
  Json toJson() => {'type': 'cooldown', 'index': index, 'items': [for (final i in items) i.toJson()]};

  @override
  CooldownStep withIndex(int index) => CooldownStep(index: index, items: items);

  @override
  bool operator ==(Object other) => other is CooldownStep && other.index == index && propsEqual(items, other.items);
  @override
  int get hashCode => Object.hash('cooldown', index, propsHash(items));
}

/// The full plan of one session, built by `buildSession` and snapshotted into `sessions.plan_json`.
@immutable
class SessionPlan {
  const SessionPlan({
    required this.programId,
    this.templateId,
    required this.phaseId,
    required this.trainingWeek,
    required this.dayId,
    required this.dayName,
    this.isDeload = false,
    this.hotDay = false,
    this.includesFinisher = false,
    required this.estimatedMinutes,
    required this.steps,
    this.notices = const [],
  });

  final String programId;
  final String? templateId;
  final PhaseId phaseId;
  final int trainingWeek;
  final String dayId, dayName;
  final bool isDeload, hotDay, includesFinisher;
  final int estimatedMinutes;
  final List<SessionStep> steps;

  /// Plain-language notices shown before the session ("Welcome back: a bit lighter today").
  final List<String> notices;

  /// Every [ExerciseStep] in order, including superset members and extras.
  Iterable<ExerciseStep> get exerciseSteps sync* {
    for (final s in steps) {
      switch (s) {
        case ExerciseStep():
          yield s;
        case SupersetStep(:final members):
          yield* members;
        case ExtrasStep(:final extras):
          yield* extras;
        default:
          break;
      }
    }
  }

  Json toJson() => {
        'programId': programId,
        'templateId': templateId,
        'phaseId': phaseId.wire,
        'trainingWeek': trainingWeek,
        'dayId': dayId,
        'dayName': dayName,
        'isDeload': isDeload,
        'hotDay': hotDay,
        'includesFinisher': includesFinisher,
        'estimatedMinutes': estimatedMinutes,
        'steps': [for (final s in steps) s.toJson()],
        'notices': notices,
      };

  factory SessionPlan.fromJson(Json j) => SessionPlan(
        programId: readString(j, 'programId'),
        templateId: readStringOrNull(j, 'templateId'),
        phaseId: PhaseId.fromWire(readString(j, 'phaseId')),
        trainingWeek: readInt(j, 'trainingWeek'),
        dayId: readString(j, 'dayId'),
        dayName: readString(j, 'dayName'),
        isDeload: readBool(j, 'isDeload', fallback: false),
        hotDay: readBool(j, 'hotDay', fallback: false),
        includesFinisher: readBool(j, 'includesFinisher', fallback: false),
        estimatedMinutes: readInt(j, 'estimatedMinutes'),
        steps: readObjectList(j, 'steps', SessionStep.fromJson),
        notices: readStringList(j, 'notices', optional: true),
      );

  SessionPlan copyWith({
    String? programId,
    String? Function()? templateId,
    PhaseId? phaseId,
    int? trainingWeek,
    String? dayId,
    String? dayName,
    bool? isDeload,
    bool? hotDay,
    bool? includesFinisher,
    int? estimatedMinutes,
    List<SessionStep>? steps,
    List<String>? notices,
  }) =>
      SessionPlan(
        programId: programId ?? this.programId,
        templateId: templateId != null ? templateId() : this.templateId,
        phaseId: phaseId ?? this.phaseId,
        trainingWeek: trainingWeek ?? this.trainingWeek,
        dayId: dayId ?? this.dayId,
        dayName: dayName ?? this.dayName,
        isDeload: isDeload ?? this.isDeload,
        hotDay: hotDay ?? this.hotDay,
        includesFinisher: includesFinisher ?? this.includesFinisher,
        estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
        steps: steps ?? this.steps,
        notices: notices ?? this.notices,
      );

  List<Object?> get _props => [
        programId, templateId, phaseId, trainingWeek, dayId, dayName, isDeload, hotDay, includesFinisher, //
        estimatedMinutes, steps, notices,
      ];
  @override
  bool operator ==(Object other) => other is SessionPlan && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}

// ---------------------------------------------------------------------------------------------
// Find your weight, warm-ups, plates, swaps
// ---------------------------------------------------------------------------------------------

/// Live "find your weight" ramp state, persisted in [PlayerCursor.findWeight] (SPEC 6.2).
@immutable
class FindWeightState {
  const FindWeightState({
    required this.currentKg,
    this.previousKg,
    required this.step,
    required this.targetReps,
    required this.targetRir,
  });

  final double currentKg;
  final double? previousKg;

  /// 1..4.
  final int step;
  final int targetReps;
  final int targetRir;

  Json toJson() => {
        'currentKg': currentKg,
        'previousKg': previousKg,
        'step': step,
        'targetReps': targetReps,
        'targetRir': targetRir,
      };

  factory FindWeightState.fromJson(Json j) => FindWeightState(
        currentKg: readDouble(j, 'currentKg'),
        previousKg: readDoubleOrNull(j, 'previousKg'),
        step: readInt(j, 'step'),
        targetReps: readInt(j, 'targetReps'),
        targetRir: readInt(j, 'targetRir'),
      );

  FindWeightState copyWith({
    double? currentKg,
    double? Function()? previousKg,
    int? step,
    int? targetReps,
    int? targetRir,
  }) =>
      FindWeightState(
        currentKg: currentKg ?? this.currentKg,
        previousKg: previousKg != null ? previousKg() : this.previousKg,
        step: step ?? this.step,
        targetReps: targetReps ?? this.targetReps,
        targetRir: targetRir ?? this.targetRir,
      );

  List<Object?> get _props => [currentKg, previousKg, step, targetReps, targetRir];
  @override
  bool operator ==(Object other) => other is FindWeightState && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);

  @override
  String toString() => 'FindWeightState(step $step at $currentKg, target $targetReps @ $targetRir)';
}

/// Outcome of one ramp set.
@immutable
sealed class RampResult {
  const RampResult();
}

/// Ramp again at [nextKg].
final class RampNext extends RampResult {
  const RampNext(this.nextKg);
  final double nextKg;

  @override
  bool operator ==(Object other) => other is RampNext && other.nextKg == nextKg;
  @override
  int get hashCode => Object.hash('next', nextKg);
  @override
  String toString() => 'RampNext($nextKg)';
}

/// Ramp finished: do the working sets at [workingKg].
final class RampDone extends RampResult {
  const RampDone(this.workingKg);
  final double workingKg;

  @override
  bool operator ==(Object other) => other is RampDone && other.workingKg == workingKg;
  @override
  int get hashCode => Object.hash('done', workingKg);
  @override
  String toString() => 'RampDone($workingKg)';
}

/// A warm-up set before the working sets (SPEC 6.3).
@immutable
class WarmupSet {
  const WarmupSet(this.weightKg, this.reps);

  final double weightKg;
  final int reps;

  @override
  bool operator ==(Object other) => other is WarmupSet && other.weightKg == weightKg && other.reps == reps;
  @override
  int get hashCode => Object.hash(weightKg, reps);
  @override
  String toString() => 'WarmupSet(${weightKg}x$reps)';
}

/// Plate calculator answer. [perSide] is the plate list for ONE side, heaviest first.
@immutable
class PlateResult {
  const PlateResult({required this.totalKg, required this.perSide, required this.exact, this.lowerKg, this.higherKg});

  /// The load actually loaded (equal to the target when [exact]).
  final double totalKg;
  final List<double> perSide;
  final bool exact;

  /// Nearest achievable totals below / above the target when not [exact].
  final double? lowerKg, higherKg;

  List<Object?> get _props => [totalKg, perSide, exact, lowerKg, higherKg];
  @override
  bool operator ==(Object other) => other is PlateResult && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
  @override
  String toString() => 'PlateResult($totalKg, each side $perSide, exact: $exact)';
}

/// An alternative offered by the swap sheet.
@immutable
class SwapOption {
  const SwapOption({required this.exercise, required this.why, required this.hasHistory});

  final Exercise exercise;

  /// "Same muscles · Cable machine".
  final String why;
  final bool hasHistory;

  @override
  bool operator ==(Object other) =>
      other is SwapOption && other.exercise.id == exercise.id && other.why == why && other.hasHistory == hasHistory;
  @override
  int get hashCode => Object.hash(exercise.id, why, hasHistory);
}

/// Reactive deload suggestion (SPEC 6.12).
@immutable
class DeloadAdvice {
  const DeloadAdvice({required this.suggest, this.reasons = const []});

  static const DeloadAdvice none = DeloadAdvice(suggest: false);

  final bool suggest;

  /// Plain-language reasons for the Today card.
  final List<String> reasons;

  @override
  bool operator ==(Object other) => other is DeloadAdvice && other.suggest == suggest && propsEqual(reasons, other.reasons);
  @override
  int get hashCode => Object.hash(suggest, propsHash(reasons));
}

/// Daily targets (SPEC 10.1).
@immutable
class NutritionTargets {
  const NutritionTargets({
    required this.bmi,
    required this.bmrKcal,
    required this.tdeeKcal,
    required this.calorieTargetKcal,
    required this.proteinMinG,
    required this.proteinTargetG,
    required this.proteinMaxG,
    required this.proteinPointsTarget,
    required this.proteinPointsGoodDay,
    required this.waterRestMl,
    required this.waterTrainingMl,
    required this.stepsTarget,
    required this.referenceWeightKg,
    required this.ratePctPerWeek,
  });

  final double bmi;
  final int bmrKcal, tdeeKcal, calorieTargetKcal, proteinMinG, proteinTargetG, proteinMaxG, proteinPointsTarget,
      proteinPointsGoodDay, waterRestMl, waterTrainingMl, stepsTarget;
  final double referenceWeightKg;

  /// Target loss rate range, % of body weight per week.
  final (double, double) ratePctPerWeek;

  List<Object?> get _props => [
        bmi, bmrKcal, tdeeKcal, calorieTargetKcal, proteinMinG, proteinTargetG, proteinMaxG, proteinPointsTarget, //
        proteinPointsGoodDay, waterRestMl, waterTrainingMl, stepsTarget, referenceWeightKg, ratePctPerWeek,
      ];
  @override
  bool operator ==(Object other) => other is NutritionTargets && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}

// ---------------------------------------------------------------------------------------------
// Extra value types of SPEC 7.2
// ---------------------------------------------------------------------------------------------

/// Return-after-a-break adjustments (SPEC 6.8 gap rule).
@immutable
class GapRule {
  const GapRule(this.loadMultiplier, this.rirBonus, this.forceFindWeightPrimary, this.treatAsDeload, this.notice);

  static const GapRule none = GapRule(1.0, 0, false, false, null);

  final double loadMultiplier;
  final int rirBonus;
  final bool forceFindWeightPrimary, treatAsDeload;
  final String? notice;

  /// Whether an item with [role] must ramp ("find your weight") again.
  bool forceFindWeight(ItemRole role) => forceFindWeightPrimary && role == ItemRole.primary;

  List<Object?> get _props => [loadMultiplier, rirBonus, forceFindWeightPrimary, treatAsDeload, notice];
  @override
  bool operator ==(Object other) => other is GapRule && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
  @override
  String toString() => 'GapRule(x$loadMultiplier, rir+$rirBonus, ramp:$forceFindWeightPrimary, deload:$treatAsDeload)';
}

/// In-session suggestion after a working set (SPEC 6.4). [automatic] hints are applied by the
/// player (lighter next set); others are one-tap chips.
@immutable
class InSessionHint {
  const InSessionHint({required this.message, this.suggestedKg, this.automatic = false});

  final String message;
  final double? suggestedKg;
  final bool automatic;

  @override
  bool operator ==(Object other) =>
      other is InSessionHint && other.message == message && other.suggestedKg == suggestedKg && other.automatic == automatic;
  @override
  int get hashCode => Object.hash(message, suggestedKg, automatic);
}

/// Everything `buildSession` needs (SPEC 6.8).
@immutable
class BuildSessionInput {
  const BuildSessionInput({
    required this.template,
    required this.active,
    this.overrides = const [],
    this.dayId,
    required this.catalog,
    this.states = const {},
    this.prefs = const {},
    required this.completedNonDeload,
    this.lastCompletedAt,
    required this.settings,
    required this.profile,
    required this.now,
    this.hotDay = false,
    this.recentIllness = false,
    this.cardioOff = false,
    this.limitationRules = const {},
  });

  final ProgramTemplate template;
  final ActiveProgram active;
  final List<ProgramOverride> overrides;

  /// Day to build; null = the rotation pointer.
  final String? dayId;
  final AssetCatalog catalog;
  final Map<String, ExerciseState> states;
  final Map<String, ExercisePrefs> prefs;
  final int completedNonDeload;
  final DateTime? lastCompletedAt;
  final AppSettings settings;
  final UserProfile profile;
  final DateTime now;
  final bool hotDay, recentIllness, cardioOff;
  final Map<String, dynamic> limitationRules;
}

/// Inputs of the reactive deload advisor (SPEC 6.12).
@immutable
class DeloadInput {
  const DeloadInput({
    required this.recentSessions,
    required this.states,
    required this.trainingWeek,
    this.lastDeloadAt,
    this.lastDismissedAt,
    required this.now,
  });

  /// Completed sessions, newest first.
  final List<Session> recentSessions;
  final Map<String, ExerciseState> states;
  final int trainingWeek;
  final DateTime? lastDeloadAt;
  final DateTime? lastDismissedAt;
  final DateTime now;
}

/// One ISO week (Mon start) of training (SPEC 6.11).
@immutable
class WeeklyStats {
  const WeeklyStats({required this.sessions, required this.workingSets, required this.volumeKg, this.hardSets = const {}});

  static const WeeklyStats empty = WeeklyStats(sessions: 0, workingSets: 0, volumeKg: 0);

  final int sessions, workingSets;
  final double volumeKg;

  /// Hard sets per muscle (primary 1.0, secondary 0.5).
  final Map<Muscle, double> hardSets;

  List<Object?> get _props => [sessions, workingSets, volumeKg, hardSets];
  @override
  bool operator ==(Object other) => other is WeeklyStats && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}

/// Inputs of the weekly calorie check-in (SPEC 10.2).
@immutable
class CheckinInput {
  const CheckinInput({
    required this.body,
    required this.nutrition,
    required this.adjustments,
    required this.anchorStates,
    required this.profile,
    required this.p,
    required this.now,
  });

  final List<BodyEntry> body;
  final List<NutritionDay> nutrition;
  final List<CalorieAdjustment> adjustments;
  final Map<String, ExerciseState> anchorStates;
  final UserProfile profile;
  final Personalization p;
  final DateTime now;
}

/// Weekly check-in result; [canApply] shows the "Apply" button.
@immutable
class CheckinAdvice {
  const CheckinAdvice({
    required this.ruleId,
    required this.message,
    this.deltaKcal = 0,
    this.deltaSteps = 0,
    this.canApply = false,
  });

  final String ruleId, message;
  final int deltaKcal;
  final int deltaSteps;
  final bool canApply;

  List<Object?> get _props => [ruleId, message, deltaKcal, deltaSteps, canApply];
  @override
  bool operator ==(Object other) => other is CheckinAdvice && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}

/// Inputs of the milestone evaluator (SPEC 10.3).
@immutable
class MilestoneInput {
  const MilestoneInput({
    required this.sessions,
    required this.workingSets,
    required this.body,
    required this.nutrition,
    required this.cardio,
    required this.pauses,
    required this.states,
    this.newPrs = const [],
    required this.profile,
    required this.eq,
    required this.catalog,
    required this.now,
  });

  final List<Session> sessions;
  final List<SetLog> workingSets;
  final List<BodyEntry> body;
  final List<NutritionDay> nutrition;
  final List<CardioLog> cardio;
  final List<Pause> pauses;
  final Map<String, ExerciseState> states;
  final List<PersonalRecord> newPrs;
  final UserProfile profile;
  final EquipmentProfile eq;
  final AssetCatalog catalog;
  final DateTime now;
}

/// Weekly streak (SPEC 10.4).
@immutable
class StreakInfo {
  const StreakInfo({
    required this.weeks,
    required this.graceTokens,
    required this.thisWeekCounted,
    required this.sessionsThisWeek,
    required this.targetThisWeek,
  });

  final int weeks;
  final int graceTokens;
  final bool thisWeekCounted;
  final int sessionsThisWeek, targetThisWeek;

  List<Object?> get _props => [weeks, graceTokens, thisWeekCounted, sessionsThisWeek, targetThisWeek];
  @override
  bool operator ==(Object other) => other is StreakInfo && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}
