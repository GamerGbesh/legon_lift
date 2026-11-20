/// Schema migrations (SPEC 9.1).
///
/// - [migrations]: `migrations[v]` holds the SQL that upgrades a database from version `v - 1` to
///   `v`. `AppDatabase` runs each step in order in `onUpgrade` (and after `kSchemaV1` in
///   `onCreate`, so a fresh install ends up with exactly the same schema as an upgraded one).
/// - [backupRowMigrations]: `backupRowMigrations[v]` rewrites the rows of a backup made at
///   database version `v - 1` so they fit version `v` (SPEC 9.2: "migrate rows forward").
///
/// Version 1 is created by `kSchemaV1`, so both maps are empty. Every schema change bumps
/// `kDbVersion` in `schema.dart`, adds its SQL here AND a row migration if old rows need it.
library;

/// Backup tables as row maps, keyed by table name.
typedef BackupTables = Map<String, List<Map<String, Object?>>>;

/// Rewrites backup rows in place for one version step.
typedef BackupRowMigration = void Function(BackupTables tables);

const Map<int, List<String>> migrations = {};

const Map<int, BackupRowMigration> backupRowMigrations = {};
