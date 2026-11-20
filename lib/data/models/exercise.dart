import 'package:flutter/foundation.dart';

import '../../core/equality.dart';
import 'enums.dart';
import 'json_read.dart';

/// Conservative beginner starting load range, in the weight semantics of SPEC 0.4.
@immutable
class StartingWeight {
  const StartingWeight({required this.low, required this.high, required this.note});

  final double low, high;
  final String note;

  factory StartingWeight.fromJson(Json j) =>
      StartingWeight(low: readDouble(j, 'low'), high: readDouble(j, 'high'), note: readString(j, 'note'));

  Json toJson() => {'low': low, 'high': high, 'note': note};

  StartingWeight copyWith({double? low, double? high, String? note}) =>
      StartingWeight(low: low ?? this.low, high: high ?? this.high, note: note ?? this.note);

  List<Object?> get _props => [low, high, note];
  @override
  bool operator ==(Object other) => other is StartingWeight && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}

/// Pinned YouTube video (oEmbed-verified at build time).
@immutable
class ExerciseVideo {
  const ExerciseVideo({required this.url, required this.title, required this.channel, required this.verified});

  final String url, title, channel;
  final bool verified;

  factory ExerciseVideo.fromJson(Json j) => ExerciseVideo(
        url: readString(j, 'url'),
        title: readString(j, 'title'),
        channel: readString(j, 'channel'),
        verified: readBool(j, 'verified'),
      );

  Json toJson() => {'url': url, 'title': title, 'channel': channel, 'verified': verified};

  ExerciseVideo copyWith({String? url, String? title, String? channel, bool? verified}) => ExerciseVideo(
        url: url ?? this.url,
        title: title ?? this.title,
        channel: channel ?? this.channel,
        verified: verified ?? this.verified,
      );

  List<Object?> get _props => [url, title, channel, verified];
  @override
  bool operator ==(Object other) => other is ExerciseVideo && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}

/// One record of `assets/data/exercises.json` (SPEC 2.1).
///
/// Nullable fields in [copyWith] take a closure so they can be cleared: `copyWith(video: () => null)`.
@immutable
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    this.aliases = const [],
    required this.category,
    required this.primaryMuscles,
    this.secondaryMuscles = const [],
    required this.equipment,
    required this.mechanic,
    required this.difficulty,
    required this.unilateral,
    required this.loadType,
    this.weightIncrementKg,
    this.startingWeightKg,
    required this.defaultSets,
    this.repRange,
    required this.restSeconds,
    this.durationSeconds,
    this.setup = const [],
    this.cues = const [],
    this.mistakes = const [],
    this.breathing = '',
    this.safety = '',
    this.substitutions = const [],
    this.freeExerciseDbId,
    this.images = const [],
    this.video,
    this.sources = const [],
    required this.movementPattern,
    required this.tracking,
    this.dumbbellCount,
    this.localImages = const [],
  });

  final String id, name;
  final List<String> aliases;
  final ExerciseCategory category;
  final List<Muscle> primaryMuscles, secondaryMuscles;
  final List<Equipment> equipment;
  final Mechanic mechanic;
  final int difficulty;
  final bool unilateral;
  final LoadType loadType;
  final double? weightIncrementKg;
  final StartingWeight? startingWeightKg;
  final int defaultSets;
  final (int, int)? repRange;
  final int restSeconds;
  final int? durationSeconds;
  final List<String> setup, cues, mistakes;
  final String breathing, safety;
  final List<String> substitutions;
  final String? freeExerciseDbId;

  /// Remote originals (build-time only, never fetched by the app).
  final List<String> images;
  final ExerciseVideo? video;
  final List<String> sources;
  final MovementPattern movementPattern;
  final Tracking tracking;
  final int? dumbbellCount;

  /// Bundled asset keys (`assets/exercises/<id>_<n>.jpg`); may be empty.
  final List<String> localImages;

  bool get isLoaded => tracking == Tracking.weightReps;
  bool get needsBarMath => loadType == LoadType.smith || loadType == LoadType.barbell;
  String get unlockKey => switch (loadType) {
        LoadType.smith => 'smith_machine',
        LoadType.barbell => 'barbell_floor_lifts',
        _ => 'always',
      };

  factory Exercise.fromJson(Json j) {
    final id = j['id'];
    try {
      return Exercise(
        id: readString(j, 'id'),
        name: readString(j, 'name'),
        aliases: readStringList(j, 'aliases', optional: true),
        category: ExerciseCategory.fromWire(readString(j, 'category')),
        primaryMuscles: readEnumList(j, 'primaryMuscles', Muscle.fromWire),
        secondaryMuscles: readEnumList(j, 'secondaryMuscles', Muscle.fromWire),
        equipment: readEnumList(j, 'equipment', Equipment.fromWire),
        mechanic: Mechanic.fromWire(readString(j, 'mechanic')),
        difficulty: readInt(j, 'difficulty'),
        unilateral: readBool(j, 'unilateral'),
        loadType: LoadType.fromWire(readString(j, 'loadType')),
        weightIncrementKg: readDoubleOrNull(j, 'weightIncrementKg'),
        startingWeightKg: readMapOrNull(j, 'startingWeightKg') == null
            ? null
            : StartingWeight.fromJson(readMap(j, 'startingWeightKg')),
        defaultSets: readInt(j, 'defaultSets'),
        repRange: readRangeOrNull(j, 'repRange'),
        restSeconds: readInt(j, 'restSeconds'),
        durationSeconds: readIntOrNull(j, 'durationSeconds'),
        setup: readStringList(j, 'setup', optional: true),
        cues: readStringList(j, 'cues', optional: true),
        mistakes: readStringList(j, 'mistakes', optional: true),
        breathing: readStringOrNull(j, 'breathing') ?? '',
        safety: readStringOrNull(j, 'safety') ?? '',
        substitutions: readStringList(j, 'substitutions', optional: true),
        freeExerciseDbId: readStringOrNull(j, 'freeExerciseDbId'),
        images: readStringList(j, 'images', optional: true),
        video: readMapOrNull(j, 'video') == null ? null : ExerciseVideo.fromJson(readMap(j, 'video')),
        sources: readStringList(j, 'sources', optional: true),
        movementPattern: MovementPattern.fromWire(readString(j, 'movementPattern')),
        tracking: Tracking.fromWire(readString(j, 'tracking')),
        dumbbellCount: readIntOrNull(j, 'dumbbellCount'),
        localImages: readStringList(j, 'localImages', optional: true),
      );
    } on FormatException catch (e) {
      throw FormatException('Exercise "$id": ${e.message}');
    }
  }

  /// Same field order as the asset file (SPEC 2.1).
  Json toJson() => {
        'id': id,
        'name': name,
        'aliases': aliases,
        'category': category.wire,
        'primaryMuscles': [for (final m in primaryMuscles) m.wire],
        'secondaryMuscles': [for (final m in secondaryMuscles) m.wire],
        'equipment': [for (final e in equipment) e.wire],
        'mechanic': mechanic.wire,
        'difficulty': difficulty,
        'unilateral': unilateral,
        'loadType': loadType.wire,
        'weightIncrementKg': weightIncrementKg,
        'startingWeightKg': startingWeightKg?.toJson(),
        'defaultSets': defaultSets,
        'repRange': rangeToJson(repRange),
        'restSeconds': restSeconds,
        'durationSeconds': durationSeconds,
        'setup': setup,
        'cues': cues,
        'mistakes': mistakes,
        'breathing': breathing,
        'safety': safety,
        'substitutions': substitutions,
        'freeExerciseDbId': freeExerciseDbId,
        'images': images,
        'video': video?.toJson(),
        'sources': sources,
        'movementPattern': movementPattern.wire,
        'tracking': tracking.wire,
        'dumbbellCount': dumbbellCount,
        'localImages': localImages,
      };

  Exercise copyWith({
    String? id,
    String? name,
    List<String>? aliases,
    ExerciseCategory? category,
    List<Muscle>? primaryMuscles,
    List<Muscle>? secondaryMuscles,
    List<Equipment>? equipment,
    Mechanic? mechanic,
    int? difficulty,
    bool? unilateral,
    LoadType? loadType,
    double? Function()? weightIncrementKg,
    StartingWeight? Function()? startingWeightKg,
    int? defaultSets,
    (int, int)? Function()? repRange,
    int? restSeconds,
    int? Function()? durationSeconds,
    List<String>? setup,
    List<String>? cues,
    List<String>? mistakes,
    String? breathing,
    String? safety,
    List<String>? substitutions,
    String? Function()? freeExerciseDbId,
    List<String>? images,
    ExerciseVideo? Function()? video,
    List<String>? sources,
    MovementPattern? movementPattern,
    Tracking? tracking,
    int? Function()? dumbbellCount,
    List<String>? localImages,
  }) =>
      Exercise(
        id: id ?? this.id,
        name: name ?? this.name,
        aliases: aliases ?? this.aliases,
        category: category ?? this.category,
        primaryMuscles: primaryMuscles ?? this.primaryMuscles,
        secondaryMuscles: secondaryMuscles ?? this.secondaryMuscles,
        equipment: equipment ?? this.equipment,
        mechanic: mechanic ?? this.mechanic,
        difficulty: difficulty ?? this.difficulty,
        unilateral: unilateral ?? this.unilateral,
        loadType: loadType ?? this.loadType,
        weightIncrementKg: weightIncrementKg != null ? weightIncrementKg() : this.weightIncrementKg,
        startingWeightKg: startingWeightKg != null ? startingWeightKg() : this.startingWeightKg,
        defaultSets: defaultSets ?? this.defaultSets,
        repRange: repRange != null ? repRange() : this.repRange,
        restSeconds: restSeconds ?? this.restSeconds,
        durationSeconds: durationSeconds != null ? durationSeconds() : this.durationSeconds,
        setup: setup ?? this.setup,
        cues: cues ?? this.cues,
        mistakes: mistakes ?? this.mistakes,
        breathing: breathing ?? this.breathing,
        safety: safety ?? this.safety,
        substitutions: substitutions ?? this.substitutions,
        freeExerciseDbId: freeExerciseDbId != null ? freeExerciseDbId() : this.freeExerciseDbId,
        images: images ?? this.images,
        video: video != null ? video() : this.video,
        sources: sources ?? this.sources,
        movementPattern: movementPattern ?? this.movementPattern,
        tracking: tracking ?? this.tracking,
        dumbbellCount: dumbbellCount != null ? dumbbellCount() : this.dumbbellCount,
        localImages: localImages ?? this.localImages,
      );

  List<Object?> get _props => [
        id, name, aliases, category, primaryMuscles, secondaryMuscles, equipment, mechanic, difficulty, //
        unilateral, loadType, weightIncrementKg, startingWeightKg, defaultSets, repRange, restSeconds,
        durationSeconds, setup, cues, mistakes, breathing, safety, substitutions, freeExerciseDbId, images,
        video, sources, movementPattern, tracking, dumbbellCount, localImages,
      ];
  @override
  bool operator ==(Object other) => other is Exercise && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);

  @override
  String toString() => 'Exercise($id)';
}
