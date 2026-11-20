import 'package:flutter/foundation.dart';

import '../../core/equality.dart';
import 'enums.dart';
import 'json_read.dart';

/// Gym defaults from `personalization.gym` (SPEC 2.3).
@immutable
class GymProfileDefaults {
  const GymProfileDefaults({
    required this.equipment,
    this.optionalEquipment = const [],
    this.equipmentLabels = const {},
    this.equipmentNotes = const {},
    required this.platesKg,
    required this.barKg,
    required this.smithBarKg,
    this.smithBarKnown = false,
    required this.legPressSledKg,
    this.legPressSledKnown = false,
    required this.dumbbellStepKg,
    required this.dumbbellMaxKg,
    required this.legCurlType,
  });

  /// The values shipped in personalization.json, for code paths that run without the catalog
  /// (tests, first frame).
  static const GymProfileDefaults legon = GymProfileDefaults(
    equipment: [
      Equipment.cable, Equipment.latPulldownMachine, Equipment.shoulderPressMachine, Equipment.chestPressMachine, //
      Equipment.bike, Equipment.treadmill, Equipment.barbell, Equipment.dumbbell, Equipment.legPress,
      Equipment.plates, Equipment.calfRaiseMachine, Equipment.legCurlMachine, Equipment.legExtensionMachine,
      Equipment.smithMachine, Equipment.bench, Equipment.bodyweight,
    ],
    optionalEquipment: [Equipment.ankleStrap],
    platesKg: [25, 20, 15, 10, 5, 2.5, 1.25],
    barKg: 20,
    smithBarKg: 10,
    legPressSledKg: 0,
    dumbbellStepKg: 2,
    dumbbellMaxKg: 40,
    legCurlType: LegCurlType.seated,
  );

  /// Ticked by default.
  final List<Equipment> equipment;

  /// Shown unticked (ankle strap).
  final List<Equipment> optionalEquipment;

  /// Keyed by [Equipment.wire].
  final Map<String, String> equipmentLabels, equipmentNotes;
  final List<double> platesKg;
  final double barKg, smithBarKg;
  final bool smithBarKnown;
  final double legPressSledKg;
  final bool legPressSledKnown;
  final double dumbbellStepKg, dumbbellMaxKg;
  final LegCurlType legCurlType;

  /// Display label for an equipment id, e.g. "Calf raise machine ('ankle machine')".
  String labelFor(Equipment e) => equipmentLabels[e.wire] ?? e.wire.replaceAll('_', ' ');

  /// Dumbbell weights from step to max in step increments (2, 4, ..., 40).
  List<double> get defaultDumbbellsKg {
    final out = <double>[];
    for (var w = dumbbellStepKg; w <= dumbbellMaxKg + 1e-9; w += dumbbellStepKg) {
      out.add(double.parse(w.toStringAsFixed(2)));
    }
    return out;
  }

  factory GymProfileDefaults.fromJson(Json j) => GymProfileDefaults(
        equipment: readEnumList(j, 'equipment', Equipment.fromWire),
        optionalEquipment: j['optionalEquipment'] == null ? const [] : readEnumList(j, 'optionalEquipment', Equipment.fromWire),
        equipmentLabels: (readMapOrNull(j, 'equipmentLabels') ?? const {}).map((k, v) => MapEntry(k, '$v')),
        equipmentNotes: (readMapOrNull(j, 'equipmentNotes') ?? const {}).map((k, v) => MapEntry(k, '$v')),
        platesKg: readDoubleList(j, 'platesKg'),
        barKg: readDouble(j, 'barKg'),
        smithBarKg: readDouble(j, 'smithBarKg'),
        smithBarKnown: readBool(j, 'smithBarKnown', fallback: false),
        legPressSledKg: readDouble(j, 'legPressSledKg'),
        legPressSledKnown: readBool(j, 'legPressSledKnown', fallback: false),
        dumbbellStepKg: readDouble(j, 'dumbbellStepKg'),
        dumbbellMaxKg: readDouble(j, 'dumbbellMaxKg'),
        legCurlType: LegCurlType.fromWire(readString(j, 'legCurlType')),
      );

  Json toJson() => {
        'equipment': [for (final e in equipment) e.wire],
        'optionalEquipment': [for (final e in optionalEquipment) e.wire],
        'equipmentLabels': equipmentLabels,
        'equipmentNotes': equipmentNotes,
        'platesKg': platesKg,
        'barKg': barKg,
        'smithBarKg': smithBarKg,
        'smithBarKnown': smithBarKnown,
        'legPressSledKg': legPressSledKg,
        'legPressSledKnown': legPressSledKnown,
        'dumbbellStepKg': dumbbellStepKg,
        'dumbbellMaxKg': dumbbellMaxKg,
        'legCurlType': legCurlType.wire,
      };

  GymProfileDefaults copyWith({
    List<Equipment>? equipment,
    List<Equipment>? optionalEquipment,
    Map<String, String>? equipmentLabels,
    Map<String, String>? equipmentNotes,
    List<double>? platesKg,
    double? barKg,
    double? smithBarKg,
    bool? smithBarKnown,
    double? legPressSledKg,
    bool? legPressSledKnown,
    double? dumbbellStepKg,
    double? dumbbellMaxKg,
    LegCurlType? legCurlType,
  }) =>
      GymProfileDefaults(
        equipment: equipment ?? this.equipment,
        optionalEquipment: optionalEquipment ?? this.optionalEquipment,
        equipmentLabels: equipmentLabels ?? this.equipmentLabels,
        equipmentNotes: equipmentNotes ?? this.equipmentNotes,
        platesKg: platesKg ?? this.platesKg,
        barKg: barKg ?? this.barKg,
        smithBarKg: smithBarKg ?? this.smithBarKg,
        smithBarKnown: smithBarKnown ?? this.smithBarKnown,
        legPressSledKg: legPressSledKg ?? this.legPressSledKg,
        legPressSledKnown: legPressSledKnown ?? this.legPressSledKnown,
        dumbbellStepKg: dumbbellStepKg ?? this.dumbbellStepKg,
        dumbbellMaxKg: dumbbellMaxKg ?? this.dumbbellMaxKg,
        legCurlType: legCurlType ?? this.legCurlType,
      );

  List<Object?> get _props => [
        equipment, optionalEquipment, equipmentLabels, equipmentNotes, platesKg, barKg, smithBarKg, //
        smithBarKnown, legPressSledKg, legPressSledKnown, dumbbellStepKg, dumbbellMaxKg, legCurlType,
      ];
  @override
  bool operator ==(Object other) => other is GymProfileDefaults && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}

/// A badge from `personalization.milestones` (rules evaluated in SPEC 10.3).
@immutable
class Milestone {
  const Milestone({required this.id, required this.category, required this.title, required this.desc, required this.rule});

  final String id, category, title, desc;
  final Map<String, Object?> rule;

  factory Milestone.fromJson(Json j) => Milestone(
        id: readString(j, 'id'),
        category: readString(j, 'category'),
        title: readString(j, 'title'),
        desc: readString(j, 'desc'),
        rule: readMap(j, 'rule').cast<String, Object?>(),
      );

  Json toJson() => {'id': id, 'category': category, 'title': title, 'desc': desc, 'rule': rule};

  Milestone copyWith({String? id, String? category, String? title, String? desc, Map<String, Object?>? rule}) => Milestone(
        id: id ?? this.id,
        category: category ?? this.category,
        title: title ?? this.title,
        desc: desc ?? this.desc,
        rule: rule ?? this.rule,
      );

  List<Object?> get _props => [id, category, title, desc, rule];
  @override
  bool operator ==(Object other) => other is Milestone && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}

/// A meal idea from `personalization.meal_ideas` (snake_case in JSON).
@immutable
class MealIdea {
  const MealIdea({
    required this.id,
    required this.name,
    required this.mealType,
    this.components = const [],
    required this.proteinG,
    required this.kcalApprox,
    required this.costTier,
    this.tips = '',
    this.tags = const [],
    this.contains = const [],
    this.componentRoles = const [],
  });

  final String id, name, mealType;
  final List<String> components;

  /// Role of each component for portion scaling: protein, carb, fat, veg, mixed or fixed
  /// (aligned with [components]; empty = scale nothing).
  final List<String> componentRoles;
  final int proteinG, kcalApprox;
  final String costTier, tips;
  final List<String> tags, contains;

  factory MealIdea.fromJson(Json j) => MealIdea(
        id: readString(j, 'id'),
        name: readString(j, 'name'),
        mealType: readString(j, 'meal_type'),
        components: readStringList(j, 'components', optional: true),
        proteinG: readInt(j, 'protein_g'),
        kcalApprox: readInt(j, 'kcal_approx'),
        costTier: readString(j, 'cost_tier'),
        tips: readStringOrNull(j, 'tips') ?? '',
        tags: readStringList(j, 'tags', optional: true),
        contains: readStringList(j, 'contains', optional: true),
        componentRoles: readStringList(j, 'component_roles', optional: true),
      );

  Json toJson() => {
        'id': id,
        'name': name,
        'meal_type': mealType,
        'components': components,
        'protein_g': proteinG,
        'kcal_approx': kcalApprox,
        'cost_tier': costTier,
        'tips': tips,
        'tags': tags,
        'contains': contains,
        'component_roles': componentRoles,
      };

  MealIdea copyWith({
    String? id,
    String? name,
    String? mealType,
    List<String>? components,
    int? proteinG,
    int? kcalApprox,
    String? costTier,
    String? tips,
    List<String>? tags,
    List<String>? contains,
    List<String>? componentRoles,
  }) =>
      MealIdea(
        id: id ?? this.id,
        name: name ?? this.name,
        mealType: mealType ?? this.mealType,
        components: components ?? this.components,
        proteinG: proteinG ?? this.proteinG,
        kcalApprox: kcalApprox ?? this.kcalApprox,
        costTier: costTier ?? this.costTier,
        tips: tips ?? this.tips,
        tags: tags ?? this.tags,
        contains: contains ?? this.contains,
        componentRoles: componentRoles ?? this.componentRoles,
      );

  List<Object?> get _props =>
      [id, name, mealType, components, proteinG, kcalApprox, costTier, tips, tags, contains, componentRoles];
  @override
  bool operator ==(Object other) => other is MealIdea && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}

/// One PAR-Q question (`safety.parq.questions`).
@immutable
class ParqQuestion {
  const ParqQuestion({required this.id, required this.text, this.note});

  final String id, text;
  final String? note;

  factory ParqQuestion.fromJson(Json j) =>
      ParqQuestion(id: readString(j, 'id'), text: readString(j, 'text'), note: readStringOrNull(j, 'note'));

  Json toJson() => {'id': id, 'text': text, if (note != null) 'note': note};

  ParqQuestion copyWith({String? id, String? text, String? Function()? note}) =>
      ParqQuestion(id: id ?? this.id, text: text ?? this.text, note: note != null ? note() : this.note);

  List<Object?> get _props => [id, text, note];
  @override
  bool operator ==(Object other) => other is ParqQuestion && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}

/// Typed views over `personalization.json`; everything else stays in [raw] (snake_case keys).
@immutable
class Personalization {
  const Personalization({
    required this.raw,
    required this.gym,
    this.formulas = const {},
    this.workedExample = const {},
    this.defaultProfile = const {},
    this.programSelection = const {},
    this.defaults = const {},
    this.milestones = const [],
    this.meals = const [],
    this.parq = const [],
    this.tips = const {},
    this.limitationRules = const {},
  });

  final Map<String, dynamic> raw;
  final GymProfileDefaults gym;
  final Map<String, dynamic> formulas, workedExample, defaultProfile, programSelection, defaults;
  final List<Milestone> milestones;
  final List<MealIdea> meals;

  /// The 7 PAR-Q questions. The 3 Ghana questions are in `raw['safety']['parq']['ghana_extra_questions']`.
  final List<ParqQuestion> parq;

  /// Tip lists by key (`rest_timer_tips`, `pre_workout`, ...).
  final Map<String, List<String>> tips;

  /// `limitation_rules`: limitation id -> `{avoid_ids, avoid_patterns, lock_unlocks?, cue}`.
  final Map<String, dynamic> limitationRules;

  /// The `safety` object (red flags, heat illness, emergency numbers ...).
  Map<String, dynamic> get safety => (raw['safety'] as Map?)?.cast<String, dynamic>() ?? const {};

  /// Chooses the program for (split, daysPerWeek) using `programSelection.table`; falls back to ppl_3day.
  String programIdFor(SplitKey split, int daysPerWeek) {
    final table = programSelection['table'];
    if (table is List) {
      for (final row in table.whereType<Map<dynamic, dynamic>>()) {
        final days = row['days_per_week'];
        if (row['split'] == split.wire && days is List && days.contains(daysPerWeek)) {
          final id = row['programId'];
          if (id is String) return id;
        }
      }
    }
    return 'ppl_3day';
  }

  factory Personalization.fromJson(Json j) {
    try {
      final safety = readMap(j, 'safety');
      final parq = readMap(safety, 'parq');
      final tipsRaw = readMap(j, 'tips');
      return Personalization(
        raw: j,
        gym: GymProfileDefaults.fromJson(readMap(j, 'gym')),
        formulas: readMap(j, 'formulas'),
        workedExample: readMap(j, 'worked_example'),
        defaultProfile: readMap(j, 'defaultProfile'),
        programSelection: readMap(j, 'programSelection'),
        defaults: readMap(j, 'defaults'),
        milestones: readObjectList(j, 'milestones', Milestone.fromJson),
        meals: readObjectList(j, 'meal_ideas', MealIdea.fromJson),
        parq: readObjectList(parq, 'questions', ParqQuestion.fromJson),
        tips: {for (final k in tipsRaw.keys) k: readStringList(tipsRaw, k)},
        limitationRules: readMapOrNull(j, 'limitation_rules') ?? const {},
      );
    } on FormatException catch (e) {
      throw FormatException('personalization.json: ${e.message}');
    }
  }

  /// The original document (typed views are derived from it).
  Json toJson() => raw;

  List<Object?> get _props => [raw];
  @override
  bool operator ==(Object other) => other is Personalization && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}
