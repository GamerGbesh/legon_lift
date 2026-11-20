import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/equality.dart';
import 'json_read.dart';
import 'program_template.dart';

/// The user's running program (table `programs`). [templateId] points at a shipped template, or
/// [customTemplate] holds a custom program.
///
/// Nullable fields in [copyWith] take a closure so they can be cleared.
@immutable
class ActiveProgram {
  const ActiveProgram({
    required this.id,
    this.templateId,
    this.customTemplate,
    required this.name,
    required this.dayOrder,
    this.nextDayIndex = 0,
    required this.startedAt,
    this.cycle = 1,
    this.startWeek = 1,
    this.reactiveDeloadRemaining = 0,
    this.isActive = true,
  });

  final String id;
  final String? templateId;
  final ProgramTemplate? customTemplate;
  final String name;
  final List<String> dayOrder;
  final int nextDayIndex;
  final DateTime startedAt;
  final int cycle;
  final int startWeek;
  final int reactiveDeloadRemaining;
  final bool isActive;

  bool get isCustom => customTemplate != null;

  /// The day the rotation points at.
  String get nextDayId => dayOrder[nextDayIndex.clamp(0, dayOrder.length - 1)];

  /// SQLite row (without `updated_at`, which the repository stamps).
  Json toMap() => {
        'id': id,
        'template_id': templateId,
        'name': name,
        'custom_json': customTemplate == null ? null : jsonEncode(customTemplate!.toJson()),
        'day_order_json': jsonEncode(dayOrder),
        'next_day_index': nextDayIndex,
        'started_at': instantToJson(startedAt),
        'start_week': startWeek,
        'cycle': cycle,
        'reactive_deload_remaining': reactiveDeloadRemaining,
        'is_active': boolToInt(isActive),
      };

  factory ActiveProgram.fromMap(Json m) {
    final custom = readStringOrNull(m, 'custom_json');
    return ActiveProgram(
      id: readString(m, 'id'),
      templateId: readStringOrNull(m, 'template_id'),
      customTemplate: custom == null ? null : ProgramTemplate.fromJson((jsonDecode(custom) as Map).cast<String, dynamic>()),
      name: readString(m, 'name'),
      dayOrder: (jsonDecode(readString(m, 'day_order_json')) as List).cast<String>(),
      nextDayIndex: readInt(m, 'next_day_index'),
      startedAt: readInstant(m, 'started_at'),
      startWeek: readInt(m, 'start_week'),
      cycle: readInt(m, 'cycle'),
      reactiveDeloadRemaining: readInt(m, 'reactive_deload_remaining'),
      isActive: readBool(m, 'is_active'),
    );
  }

  Json toJson() => {
        'id': id,
        'templateId': templateId,
        'customTemplate': customTemplate?.toJson(),
        'name': name,
        'dayOrder': dayOrder,
        'nextDayIndex': nextDayIndex,
        'startedAt': instantToJson(startedAt),
        'cycle': cycle,
        'startWeek': startWeek,
        'reactiveDeloadRemaining': reactiveDeloadRemaining,
        'isActive': isActive,
      };

  factory ActiveProgram.fromJson(Json j) => ActiveProgram(
        id: readString(j, 'id'),
        templateId: readStringOrNull(j, 'templateId'),
        customTemplate: readMapOrNull(j, 'customTemplate') == null
            ? null
            : ProgramTemplate.fromJson(readMap(j, 'customTemplate')),
        name: readString(j, 'name'),
        dayOrder: readStringList(j, 'dayOrder'),
        nextDayIndex: readInt(j, 'nextDayIndex'),
        startedAt: readInstant(j, 'startedAt'),
        cycle: readInt(j, 'cycle'),
        startWeek: readInt(j, 'startWeek'),
        reactiveDeloadRemaining: readInt(j, 'reactiveDeloadRemaining'),
        isActive: readBool(j, 'isActive'),
      );

  ActiveProgram copyWith({
    String? id,
    String? Function()? templateId,
    ProgramTemplate? Function()? customTemplate,
    String? name,
    List<String>? dayOrder,
    int? nextDayIndex,
    DateTime? startedAt,
    int? cycle,
    int? startWeek,
    int? reactiveDeloadRemaining,
    bool? isActive,
  }) =>
      ActiveProgram(
        id: id ?? this.id,
        templateId: templateId != null ? templateId() : this.templateId,
        customTemplate: customTemplate != null ? customTemplate() : this.customTemplate,
        name: name ?? this.name,
        dayOrder: dayOrder ?? this.dayOrder,
        nextDayIndex: nextDayIndex ?? this.nextDayIndex,
        startedAt: startedAt ?? this.startedAt,
        cycle: cycle ?? this.cycle,
        startWeek: startWeek ?? this.startWeek,
        reactiveDeloadRemaining: reactiveDeloadRemaining ?? this.reactiveDeloadRemaining,
        isActive: isActive ?? this.isActive,
      );

  List<Object?> get _props => [
        id, templateId, customTemplate, name, dayOrder, nextDayIndex, startedAt, cycle, startWeek, //
        reactiveDeloadRemaining, isActive,
      ];
  @override
  bool operator ==(Object other) => other is ActiveProgram && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}

/// A per-slot change to a template program ("Replace in my program", optional item on/off).
/// Applies to the slot in every phase. Table `program_overrides`.
@immutable
class ProgramOverride {
  const ProgramOverride({
    required this.programId,
    required this.dayId,
    required this.slotKey,
    required this.exerciseId,
    this.optionalEnabled,
  });

  final String programId, dayId;

  /// [ProgramItem.slotKey] of the template slot (`role:exerciseId`).
  final String slotKey;

  /// Exercise to use in the slot (the slot's own exercise when only [optionalEnabled] changes).
  final String exerciseId;

  /// Optional item switched on (true) / off (false); null = template default.
  final bool? optionalEnabled;

  Json toMap() => {
        'program_id': programId,
        'day_id': dayId,
        'slot_key': slotKey,
        'exercise_id': exerciseId,
        'optional_enabled': optionalEnabled == null ? null : boolToInt(optionalEnabled!),
      };

  factory ProgramOverride.fromMap(Json m) {
    final slot = readString(m, 'slot_key');
    return ProgramOverride(
      programId: readString(m, 'program_id'),
      dayId: readString(m, 'day_id'),
      slotKey: slot,
      exerciseId: readStringOrNull(m, 'exercise_id') ?? slot.substring(slot.indexOf(':') + 1),
      optionalEnabled: readBoolOrNull(m, 'optional_enabled'),
    );
  }

  Json toJson() => {
        'programId': programId,
        'dayId': dayId,
        'slotKey': slotKey,
        'exerciseId': exerciseId,
        'optionalEnabled': optionalEnabled,
      };

  factory ProgramOverride.fromJson(Json j) => ProgramOverride(
        programId: readString(j, 'programId'),
        dayId: readString(j, 'dayId'),
        slotKey: readString(j, 'slotKey'),
        exerciseId: readString(j, 'exerciseId'),
        optionalEnabled: readBoolOrNull(j, 'optionalEnabled'),
      );

  ProgramOverride copyWith({
    String? programId,
    String? dayId,
    String? slotKey,
    String? exerciseId,
    bool? Function()? optionalEnabled,
  }) =>
      ProgramOverride(
        programId: programId ?? this.programId,
        dayId: dayId ?? this.dayId,
        slotKey: slotKey ?? this.slotKey,
        exerciseId: exerciseId ?? this.exerciseId,
        optionalEnabled: optionalEnabled != null ? optionalEnabled() : this.optionalEnabled,
      );

  List<Object?> get _props => [programId, dayId, slotKey, exerciseId, optionalEnabled];
  @override
  bool operator ==(Object other) => other is ProgramOverride && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}
