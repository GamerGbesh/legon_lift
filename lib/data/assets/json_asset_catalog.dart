import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/json_read.dart';
import '../models/models.dart';
import 'asset_catalog.dart';

/// Thrown when a bundled data file does not match the expected schema.
class AssetCatalogException implements Exception {
  AssetCatalogException(this.file, this.message);

  final String file;
  final String message;

  @override
  String toString() => 'AssetCatalogException: $file: $message';
}

/// [AssetCatalog] backed by `assets/data/{exercises,programs,personalization}.json`.
class JsonAssetCatalog implements AssetCatalog {
  JsonAssetCatalog._({
    required List<Exercise> exercises,
    required List<ProgramTemplate> templates,
    required this.personalization,
    required Map<String, String> idMigrations,
    required this.defaultProgramId,
  })  : exercises = List.unmodifiable(exercises),
        templates = List.unmodifiable(templates),
        idMigrations = Map.unmodifiable(idMigrations),
        _byId = {for (final e in exercises) e.id: e},
        _templatesById = {for (final t in templates) t.programId: t};

  static const String exercisesAsset = 'assets/data/exercises.json';
  static const String programsAsset = 'assets/data/programs.json';
  static const String personalizationAsset = 'assets/data/personalization.json';

  /// Files larger than this are decoded on a background isolate (SPEC 3.3).
  static const int _isolateDecodeThreshold = 200 * 1024;

  /// Loads and validates the three files from [bundle] (use `rootBundle` in the app).
  static Future<JsonAssetCatalog> load(AssetBundle bundle) async {
    final texts = await Future.wait([
      bundle.loadString(exercisesAsset, cache: false),
      bundle.loadString(programsAsset, cache: false),
      bundle.loadString(personalizationAsset, cache: false),
    ]);
    final decoded = await Future.wait([
      _decode(texts[0]),
      _decode(texts[1]),
      _decode(texts[2]),
    ]);
    return JsonAssetCatalog.fromDecoded(
      exercisesJson: decoded[0],
      programsJson: decoded[1],
      personalizationJson: decoded[2],
    );
  }

  static Future<Object?> _decode(String text) =>
      text.length > _isolateDecodeThreshold ? compute(jsonDecode, text) : Future.value(jsonDecode(text));

  /// Builds the catalog from already-decoded JSON (tests use this with the real files).
  /// Throws [AssetCatalogException] naming the file and field on any schema error.
  factory JsonAssetCatalog.fromDecoded({
    required Object? exercisesJson,
    required Object? programsJson,
    required Object? personalizationJson,
  }) {
    final exercises = _parse(exercisesAsset, () {
      if (exercisesJson is! List) throw const FormatException('top level must be an array');
      final list = <Exercise>[];
      final seen = <String>{};
      for (final (i, e) in exercisesJson.indexed) {
        if (e is! Map) throw FormatException('[$i] is not an object');
        final ex = Exercise.fromJson(e.cast<String, dynamic>());
        if (!seen.add(ex.id)) throw FormatException('duplicate exercise id "${ex.id}"');
        list.add(ex);
      }
      return list;
    });

    final (templates, migrations, defaultId) = _parse(programsAsset, () {
      if (programsJson is! Map) throw const FormatException('top level must be an object');
      final root = programsJson.cast<String, dynamic>();
      final version = root['schemaVersion'];
      if (version != 1) throw FormatException('unsupported schemaVersion $version (expected 1)');
      final templates = readObjectList(root, 'programs', ProgramTemplate.fromJson);
      final migrations = (readMapOrNull(root, 'idMigrations') ?? const {}).map((k, v) => MapEntry(k, '$v'));
      final defaultId = readStringOrNull(root, 'defaultProgramId') ?? templates.first.programId;
      return (templates, migrations, defaultId);
    });

    final personalization = _parse(personalizationAsset, () {
      if (personalizationJson is! Map) throw const FormatException('top level must be an object');
      final root = personalizationJson.cast<String, dynamic>();
      final version = root['schemaVersion'];
      if (version != 1) throw FormatException('unsupported schemaVersion $version (expected 1)');
      return Personalization.fromJson(root);
    });

    // Cross-file check: every program item must name a library exercise.
    final ids = {for (final e in exercises) e.id};
    for (final t in templates) {
      for (final phase in t.phases) {
        for (final day in phase.days) {
          for (final item in day.items) {
            if (!ids.contains(item.exerciseId)) {
              throw AssetCatalogException(programsAsset,
                  '${t.programId}/${phase.phaseId.wire}/${day.dayId}: unknown exercise "${item.exerciseId}"');
            }
          }
        }
      }
    }
    if (!templates.any((t) => t.programId == defaultId)) {
      throw AssetCatalogException(programsAsset, 'defaultProgramId "$defaultId" is not a program');
    }

    return JsonAssetCatalog._(
      exercises: exercises,
      templates: templates,
      personalization: personalization,
      idMigrations: migrations,
      defaultProgramId: defaultId,
    );
  }

  static T _parse<T>(String file, T Function() body) {
    try {
      return body();
    } on FormatException catch (e) {
      throw AssetCatalogException(file, e.message);
    } on TypeError catch (e) {
      throw AssetCatalogException(file, 'unexpected value type ($e)');
    }
  }

  final Map<String, Exercise> _byId;
  final Map<String, ProgramTemplate> _templatesById;

  /// `programs.json` `defaultProgramId` (ppl_3day).
  final String defaultProgramId;

  @override
  final List<Exercise> exercises;

  @override
  final List<ProgramTemplate> templates;

  @override
  final Personalization personalization;

  @override
  final Map<String, String> idMigrations;

  @override
  Exercise? tryExercise(String id) => _byId[id] ?? _byId[idMigrations[id]];

  @override
  Exercise exercise(String id) => tryExercise(id) ?? (throw StateError('Unknown exercise id "$id"'));

  @override
  ProgramTemplate template(String programId) =>
      _templatesById[programId] ?? (throw StateError('Unknown program id "$programId"'));
}
