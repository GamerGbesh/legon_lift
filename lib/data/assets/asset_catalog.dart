import '../models/models.dart';

/// Read-only access to the bundled JSON data (SPEC 2), loaded once at startup and provided at
/// the root of the widget tree. Pure Dart so the domain layer can use it; the Flutter-asset
/// implementation is [JsonAssetCatalog] in `json_asset_catalog.dart`.
abstract class AssetCatalog {
  List<Exercise> get exercises;

  /// The exercise with [id] (old research ids are mapped through [idMigrations]).
  /// Throws a [StateError] when unknown.
  Exercise exercise(String id);
  Exercise? tryExercise(String id);

  List<ProgramTemplate> get templates;

  /// Throws a [StateError] when unknown.
  ProgramTemplate template(String programId);

  Personalization get personalization;

  /// Research-draft id -> library id (for imports of old backups).
  Map<String, String> get idMigrations;
}
