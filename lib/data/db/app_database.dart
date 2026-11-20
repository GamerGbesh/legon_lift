import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'migrations.dart' as m;
import 'schema.dart';

/// Owner of the single sqflite [Database]. Only repositories (lib/data/**) touch it; the UI never
/// imports sqflite (SPEC 3).
class AppDatabase {
  AppDatabase._(this.db);

  /// The open database.
  final Database db;

  /// Opens (and creates or migrates) the app database.
  ///
  /// [path] overrides the default `<databases>/legon_lift.db` (tests pass `inMemoryDatabasePath`
  /// or a temp file); [factory] overrides the platform factory (tests pass `databaseFactoryFfi`).
  /// [version] and [migrations] exist so tests can exercise the upgrade path.
  static Future<AppDatabase> open({
    String? path,
    DatabaseFactory? factory,
    @visibleForTesting int version = kDbVersion,
    @visibleForTesting Map<int, List<String>> migrations = m.migrations,
  }) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), kDbName);

    Future<void> runSteps(DatabaseExecutor db, int from, int to) async {
      for (var v = from + 1; v <= to; v++) {
        for (final sql in migrations[v] ?? const <String>[]) {
          await db.execute(sql);
        }
      }
    }

    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          for (final sql in kSchemaV1) {
            await db.execute(sql);
          }
          await runSteps(db, 1, version);
        },
        onUpgrade: (db, oldVersion, newVersion) => runSteps(db, oldVersion, newVersion),
      ),
    );
    return AppDatabase._(db);
  }

  /// Column names of [table], in schema order.
  Future<List<String>> columns(String table) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return [for (final r in rows) r['name']! as String];
  }

  Future<void> close() => db.close();
}
