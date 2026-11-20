import 'package:flutter/foundation.dart';

import '../../core/equality.dart';
import 'enums.dart';
import 'json_read.dart';

/// One exercise slot of a program day (SPEC 2.2 `Item`).
@immutable
class ProgramItem {
  const ProgramItem({
    required this.exerciseId,
    required this.sets,
    this.repRange,
    this.durationSeconds,
    this.rir,
    required this.restSeconds,
    required this.role,
    this.warmupSets = 0,
    this.weightIncrementKg,
    this.perSide = false,
    this.optional = false,
    this.test,
    this.substitutions = const [],
    this.notes = '',
  }) : assert(warmupSets == 'auto' || warmupSets == 0 || warmupSets == 1, 'warmupSets is "auto", 0 or 1');

  final String exerciseId;
  final int sets;
  final (int, int)? repRange;
  final int? durationSeconds;
  final int? rir;
  final int restSeconds;
  final ItemRole role;

  /// `'auto'`, `0` or `1` (SPEC 6.3). Use [warmupAuto] / [warmupSetCount] to read it.
  final Object warmupSets;
  final double? weightIncrementKg;
  final bool perSide, optional;

  /// `'rir1_rep_test'` for retest items, else null.
  final String? test;
  final List<String> substitutions;
  final String notes;

  bool get warmupAuto => warmupSets == 'auto';

  /// Number of warm-up sets for the duration model (SPEC 6.10): auto -> 2, 1 -> 1, 0 -> 0.
  int get warmupSetCount => warmupAuto ? 2 : warmupSets as int;

  bool get isRetest => test == 'rir1_rep_test';

  /// Identity used by program overrides.
  String slotKey() => '${role.name}:$exerciseId';

  factory ProgramItem.fromJson(Json j) {
    final w = j['warmupSets'];
    final Object warmup = switch (w) {
      'auto' => 'auto',
      0 || null => 0,
      1 => 1,
      _ => throw FormatException('Field "warmupSets": expected "auto", 0 or 1, got $w'),
    };
    return ProgramItem(
      exerciseId: readString(j, 'exerciseId'),
      sets: readInt(j, 'sets'),
      repRange: readRangeOrNull(j, 'repRange'),
      durationSeconds: readIntOrNull(j, 'durationSeconds'),
      rir: readIntOrNull(j, 'rir'),
      restSeconds: readInt(j, 'restSeconds'),
      role: ItemRole.fromWire(readString(j, 'role')),
      warmupSets: warmup,
      weightIncrementKg: readDoubleOrNull(j, 'weightIncrementKg'),
      perSide: readBool(j, 'perSide', fallback: false),
      optional: readBool(j, 'optional', fallback: false),
      test: readStringOrNull(j, 'test'),
      substitutions: readStringList(j, 'substitutions', optional: true),
      notes: readStringOrNull(j, 'notes') ?? '',
    );
  }

  Json toJson() => {
        'exerciseId': exerciseId,
        'sets': sets,
        'repRange': rangeToJson(repRange),
        'durationSeconds': durationSeconds,
        'rir': rir,
        'restSeconds': restSeconds,
        'role': role.wire,
        'warmupSets': warmupSets,
        'weightIncrementKg': weightIncrementKg,
        'perSide': perSide,
        'optional': optional,
        'test': test,
        'substitutions': substitutions,
        'notes': notes,
      };

  ProgramItem copyWith({
    String? exerciseId,
    int? sets,
    (int, int)? Function()? repRange,
    int? Function()? durationSeconds,
    int? Function()? rir,
    int? restSeconds,
    ItemRole? role,
    Object? warmupSets,
    double? Function()? weightIncrementKg,
    bool? perSide,
    bool? optional,
    String? Function()? test,
    List<String>? substitutions,
    String? notes,
  }) =>
      ProgramItem(
        exerciseId: exerciseId ?? this.exerciseId,
        sets: sets ?? this.sets,
        repRange: repRange != null ? repRange() : this.repRange,
        durationSeconds: durationSeconds != null ? durationSeconds() : this.durationSeconds,
        rir: rir != null ? rir() : this.rir,
        restSeconds: restSeconds ?? this.restSeconds,
        role: role ?? this.role,
        warmupSets: warmupSets ?? this.warmupSets,
        weightIncrementKg: weightIncrementKg != null ? weightIncrementKg() : this.weightIncrementKg,
        perSide: perSide ?? this.perSide,
        optional: optional ?? this.optional,
        test: test != null ? test() : this.test,
        substitutions: substitutions ?? this.substitutions,
        notes: notes ?? this.notes,
      );

  List<Object?> get _props => [
        exerciseId, sets, repRange, durationSeconds, rir, restSeconds, role, warmupSets, weightIncrementKg, //
        perSide, optional, test, substitutions, notes,
      ];
  @override
  bool operator ==(Object other) => other is ProgramItem && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);

  @override
  String toString() => 'ProgramItem(${slotKey()} ${sets}x$repRange)';
}

/// A block of a day: warm-up, main lifts, a superset pair, the finisher or the cool-down.
@immutable
class ProgramBlock {
  const ProgramBlock({
    required this.blockType,
    required this.name,
    this.optional = false,
    this.supersetGroup,
    this.restBetweenRoundsSeconds,
    required this.items,
  });

  final BlockType blockType;
  final String name;
  final bool optional;

  /// `"A"`, `"B"` or null.
  final String? supersetGroup;
  final int? restBetweenRoundsSeconds;
  final List<ProgramItem> items;

  factory ProgramBlock.fromJson(Json j) => ProgramBlock(
        blockType: BlockType.fromWire(readString(j, 'blockType')),
        name: readString(j, 'name'),
        optional: readBool(j, 'optional', fallback: false),
        supersetGroup: readStringOrNull(j, 'supersetGroup'),
        restBetweenRoundsSeconds: readIntOrNull(j, 'restBetweenRoundsSeconds'),
        items: readObjectList(j, 'items', ProgramItem.fromJson),
      );

  Json toJson() => {
        'blockType': blockType.wire,
        'name': name,
        'optional': optional,
        'supersetGroup': supersetGroup,
        'restBetweenRoundsSeconds': restBetweenRoundsSeconds,
        'items': [for (final i in items) i.toJson()],
      };

  ProgramBlock copyWith({
    BlockType? blockType,
    String? name,
    bool? optional,
    String? Function()? supersetGroup,
    int? Function()? restBetweenRoundsSeconds,
    List<ProgramItem>? items,
  }) =>
      ProgramBlock(
        blockType: blockType ?? this.blockType,
        name: name ?? this.name,
        optional: optional ?? this.optional,
        supersetGroup: supersetGroup != null ? supersetGroup() : this.supersetGroup,
        restBetweenRoundsSeconds:
            restBetweenRoundsSeconds != null ? restBetweenRoundsSeconds() : this.restBetweenRoundsSeconds,
        items: items ?? this.items,
      );

  List<Object?> get _props => [blockType, name, optional, supersetGroup, restBetweenRoundsSeconds, items];
  @override
  bool operator ==(Object other) => other is ProgramBlock && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}

/// Build-time duration estimates of a day, in minutes.
@immutable
class EstimatedMinutes {
  const EstimatedMinutes({required this.core, required this.withOptionalExercises, required this.withFinisher});

  final int core, withOptionalExercises, withFinisher;

  factory EstimatedMinutes.fromJson(Json j) => EstimatedMinutes(
        core: readInt(j, 'core'),
        withOptionalExercises: readInt(j, 'withOptionalExercises'),
        withFinisher: readInt(j, 'withFinisher'),
      );

  Json toJson() => {'core': core, 'withOptionalExercises': withOptionalExercises, 'withFinisher': withFinisher};

  EstimatedMinutes copyWith({int? core, int? withOptionalExercises, int? withFinisher}) => EstimatedMinutes(
        core: core ?? this.core,
        withOptionalExercises: withOptionalExercises ?? this.withOptionalExercises,
        withFinisher: withFinisher ?? this.withFinisher,
      );

  List<Object?> get _props => [core, withOptionalExercises, withFinisher];
  @override
  bool operator ==(Object other) => other is EstimatedMinutes && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}

/// One training day of a phase (push, pull, legs, ...).
@immutable
class ProgramDay {
  const ProgramDay({
    required this.dayId,
    required this.name,
    this.focus = const [],
    this.notes = '',
    this.estimatedMinutes = const EstimatedMinutes(core: 0, withOptionalExercises: 0, withFinisher: 0),
    required this.blocks,
  });

  final String dayId, name;

  /// Muscle wire names plus `"core"`.
  final List<String> focus;
  final String notes;
  final EstimatedMinutes estimatedMinutes;
  final List<ProgramBlock> blocks;

  /// All items in block order.
  Iterable<ProgramItem> get items => blocks.expand((b) => b.items);

  factory ProgramDay.fromJson(Json j) => ProgramDay(
        dayId: readString(j, 'dayId'),
        name: readString(j, 'name'),
        focus: readStringList(j, 'focus', optional: true),
        notes: readStringOrNull(j, 'notes') ?? '',
        estimatedMinutes: readMapOrNull(j, 'estimatedMinutes') == null
            ? const EstimatedMinutes(core: 0, withOptionalExercises: 0, withFinisher: 0)
            : EstimatedMinutes.fromJson(readMap(j, 'estimatedMinutes')),
        blocks: readObjectList(j, 'blocks', ProgramBlock.fromJson),
      );

  Json toJson() => {
        'dayId': dayId,
        'name': name,
        'focus': focus,
        'notes': notes,
        'estimatedMinutes': estimatedMinutes.toJson(),
        'blocks': [for (final b in blocks) b.toJson()],
      };

  ProgramDay copyWith({
    String? dayId,
    String? name,
    List<String>? focus,
    String? notes,
    EstimatedMinutes? estimatedMinutes,
    List<ProgramBlock>? blocks,
  }) =>
      ProgramDay(
        dayId: dayId ?? this.dayId,
        name: name ?? this.name,
        focus: focus ?? this.focus,
        notes: notes ?? this.notes,
        estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
        blocks: blocks ?? this.blocks,
      );

  List<Object?> get _props => [dayId, name, focus, notes, estimatedMinutes, blocks];
  @override
  bool operator ==(Object other) => other is ProgramDay && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}

/// A program phase (foundation, build, progress, deload, retest; or `custom`).
@immutable
class Phase {
  const Phase({
    required this.phaseId,
    required this.name,
    required this.weeks,
    this.goal = '',
    this.rirWeekOffsets = const {},
    this.rirFloorByRole,
    this.loadMultiplier = 1.0,
    this.unlocks = const {},
    required this.days,
  });

  final PhaseId phaseId;
  final String name;
  final List<int> weeks;
  final String goal;

  /// Training week -> RIR offset added to item RIR.
  final Map<int, int> rirWeekOffsets;
  final Map<ItemRole, int>? rirFloorByRole;
  final double loadMultiplier;

  /// `machines dumbbells cables smith_machine barbell_floor_lifts`.
  final Set<String> unlocks;

  /// Days in the program's `dayOrder` order.
  final List<ProgramDay> days;

  /// Every unlock key, used by custom programs.
  static const Set<String> allUnlocks = {'machines', 'dumbbells', 'cables', 'smith_machine', 'barbell_floor_lifts'};

  ProgramDay? day(String dayId) {
    for (final d in days) {
      if (d.dayId == dayId) return d;
    }
    return null;
  }

  factory Phase.fromJson(Json j) {
    final offsets = readMapOrNull(j, 'rirWeekOffsets') ?? const <String, dynamic>{};
    final floors = readMapOrNull(j, 'rirFloorByRole');
    return Phase(
      phaseId: PhaseId.fromWire(readString(j, 'phaseId')),
      name: readString(j, 'name'),
      weeks: readIntList(j, 'weeks'),
      goal: readStringOrNull(j, 'goal') ?? '',
      rirWeekOffsets: {
        for (final e in offsets.entries)
          int.tryParse(e.key) ?? (throw FormatException('rirWeekOffsets key "${e.key}" is not a week number')):
              readInt(offsets, e.key),
      },
      rirFloorByRole:
          floors == null ? null : {for (final e in floors.entries) ItemRole.fromWire(e.key): readInt(floors, e.key)},
      loadMultiplier: readDoubleOrNull(j, 'loadMultiplier') ?? 1.0,
      unlocks: readStringList(j, 'unlocks', optional: true).toSet(),
      days: readObjectList(j, 'days', ProgramDay.fromJson),
    );
  }

  Json toJson() => {
        'phaseId': phaseId.wire,
        'name': name,
        'weeks': weeks,
        'goal': goal,
        'rirWeekOffsets': {for (final e in rirWeekOffsets.entries) '${e.key}': e.value},
        'rirFloorByRole': rirFloorByRole == null ? null : {for (final e in rirFloorByRole!.entries) e.key.wire: e.value},
        'loadMultiplier': loadMultiplier,
        'unlocks': unlocks.toList(),
        'days': [for (final d in days) d.toJson()],
      };

  Phase copyWith({
    PhaseId? phaseId,
    String? name,
    List<int>? weeks,
    String? goal,
    Map<int, int>? rirWeekOffsets,
    Map<ItemRole, int>? Function()? rirFloorByRole,
    double? loadMultiplier,
    Set<String>? unlocks,
    List<ProgramDay>? days,
  }) =>
      Phase(
        phaseId: phaseId ?? this.phaseId,
        name: name ?? this.name,
        weeks: weeks ?? this.weeks,
        goal: goal ?? this.goal,
        rirWeekOffsets: rirWeekOffsets ?? this.rirWeekOffsets,
        rirFloorByRole: rirFloorByRole != null ? rirFloorByRole() : this.rirFloorByRole,
        loadMultiplier: loadMultiplier ?? this.loadMultiplier,
        unlocks: unlocks ?? this.unlocks,
        days: days ?? this.days,
      );

  List<Object?> get _props => [phaseId, name, weeks, goal, rirWeekOffsets, rirFloorByRole, loadMultiplier, unlocks, days];
  @override
  bool operator ==(Object other) => other is Phase && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}

/// A training program: one of the 5 shipped templates or a user's custom program.
///
/// Custom programs: [totalWeeks] == null and exactly one Phase(phaseId: custom, weeks: [1],
/// unlocks: [Phase.allUnlocks]).
@immutable
class ProgramTemplate {
  const ProgramTemplate({
    required this.programId,
    required this.name,
    this.isDefault = false,
    required this.splitType,
    required this.splitKey,
    required this.daysPerWeek,
    required this.dayOrder,
    this.description = '',
    this.recommendedWeekdays = const [1, 3, 5],
    this.totalWeeks,
    this.cycleRestartWeek = 1,
    required this.phases,
  });

  final String programId, name;
  final bool isDefault;
  final String splitType;
  final SplitKey splitKey;
  final int daysPerWeek;
  final List<String> dayOrder;
  final String description;

  /// 1 = Monday.
  final List<int> recommendedWeekdays;
  final int? totalWeeks;
  final int cycleRestartWeek;
  final List<Phase> phases;

  bool get isCustom => totalWeeks == null;

  factory ProgramTemplate.fromJson(Json j) {
    final id = j['programId'];
    try {
      return ProgramTemplate(
        programId: readString(j, 'programId'),
        name: readString(j, 'name'),
        isDefault: readBool(j, 'default', fallback: false),
        splitType: readStringOrNull(j, 'splitType') ?? 'custom',
        splitKey: SplitKey.fromWire(readString(j, 'splitKey')),
        daysPerWeek: readInt(j, 'daysPerWeek'),
        dayOrder: readStringList(j, 'dayOrder'),
        description: readStringOrNull(j, 'description') ?? '',
        recommendedWeekdays: readIntList(j, 'recommendedWeekdays', optional: true),
        totalWeeks: readIntOrNull(j, 'totalWeeks'),
        cycleRestartWeek: readIntOrNull(j, 'cycleRestartWeek') ?? 1,
        phases: readObjectList(j, 'phases', Phase.fromJson),
      );
    } on FormatException catch (e) {
      throw FormatException('Program "$id": ${e.message}');
    }
  }

  Json toJson() => {
        'programId': programId,
        'name': name,
        'default': isDefault,
        'splitType': splitType,
        'splitKey': splitKey.wire,
        'daysPerWeek': daysPerWeek,
        'dayOrder': dayOrder,
        'description': description,
        'recommendedWeekdays': recommendedWeekdays,
        'totalWeeks': totalWeeks,
        'cycleRestartWeek': cycleRestartWeek,
        'phases': [for (final p in phases) p.toJson()],
      };

  ProgramTemplate copyWith({
    String? programId,
    String? name,
    bool? isDefault,
    String? splitType,
    SplitKey? splitKey,
    int? daysPerWeek,
    List<String>? dayOrder,
    String? description,
    List<int>? recommendedWeekdays,
    int? Function()? totalWeeks,
    int? cycleRestartWeek,
    List<Phase>? phases,
  }) =>
      ProgramTemplate(
        programId: programId ?? this.programId,
        name: name ?? this.name,
        isDefault: isDefault ?? this.isDefault,
        splitType: splitType ?? this.splitType,
        splitKey: splitKey ?? this.splitKey,
        daysPerWeek: daysPerWeek ?? this.daysPerWeek,
        dayOrder: dayOrder ?? this.dayOrder,
        description: description ?? this.description,
        recommendedWeekdays: recommendedWeekdays ?? this.recommendedWeekdays,
        totalWeeks: totalWeeks != null ? totalWeeks() : this.totalWeeks,
        cycleRestartWeek: cycleRestartWeek ?? this.cycleRestartWeek,
        phases: phases ?? this.phases,
      );

  List<Object?> get _props => [
        programId, name, isDefault, splitType, splitKey, daysPerWeek, dayOrder, description, //
        recommendedWeekdays, totalWeeks, cycleRestartWeek, phases,
      ];
  @override
  bool operator ==(Object other) => other is ProgramTemplate && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);

  @override
  String toString() => 'ProgramTemplate($programId)';
}
