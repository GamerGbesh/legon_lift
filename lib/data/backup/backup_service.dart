import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/app_info.dart';
import '../../core/clock.dart';
import '../db/app_database.dart';
import '../db/migrations.dart';
import '../db/schema.dart';

/// Backup export / import (SPEC 9.2). JSON document with every table as row maps.
abstract class BackupService {
  /// The whole database as a backup document (UTF-8 JSON).
  Future<Uint8List> exportJson();

  /// Reads a backup without changing anything. Throws [BackupFormatException] when the file is
  /// not a Legon Lift backup or comes from a newer app.
  Future<ImportPreview> preview(Uint8List bytes);

  /// Imports a backup. [replace] = delete everything first; otherwise merge (insert or ignore by
  /// primary key; for `body_entries` / `nutrition_days` the newer `updated_at` wins).
  Future<void> import(Uint8List bytes, {required bool replace});

  /// Writes an automatic backup into `<documents>/backups` keeping the newest 4; returns its path.
  Future<String> autoBackup();
}

/// What a backup file contains (shown before Replace / Merge).
@immutable
class ImportPreview {
  const ImportPreview({
    required this.sessions,
    required this.sets,
    required this.bodyEntries,
    required this.nutritionDays,
    required this.exportedAt,
    required this.dbVersion,
    this.warnings = const [],
  });

  final int sessions, sets, bodyEntries, nutritionDays;
  final DateTime exportedAt;
  final int dbVersion;

  /// Plain-language notes ("2 exercises were renamed and will be mapped").
  final List<String> warnings;

  @override
  bool operator ==(Object other) =>
      other is ImportPreview &&
      other.sessions == sessions &&
      other.sets == sets &&
      other.bodyEntries == bodyEntries &&
      other.nutritionDays == nutritionDays &&
      other.exportedAt == exportedAt &&
      other.dbVersion == dbVersion &&
      listEquals(other.warnings, warnings);

  @override
  int get hashCode => Object.hash(sessions, sets, bodyEntries, nutritionDays, exportedAt, dbVersion, Object.hashAll(warnings));
}

/// The selected file is not a usable backup. [message] is shown to the user.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;

  @override
  String toString() => 'BackupFormatException: $message';
}

/// Backup document constants and helpers shared by the real service, the fake and the UI.
abstract final class BackupFormat {
  static const String format = 'legon_lift_backup';
  static const int version = 1;

  /// Folder under the app documents directory that holds the automatic backups.
  static const String autoBackupDir = 'backups';
  static const String filePrefix = 'legon_lift_backup_';
  static const String mimeType = 'application/json';

  /// `legon_lift_backup_yyyyMMdd_HHmm.json` (SPEC 9.2).
  static String fileNameFor(DateTime t) => '$filePrefix${DateFormat('yyyyMMdd_HHmm').format(t)}.json';

  /// A valid backup with no rows. Importing it with `replace: true` erases every table, which is
  /// how "Reset all data" works without widening the frozen [BackupService] interface.
  static Uint8List empty(DateTime exportedAt) => Uint8List.fromList(utf8.encode(jsonEncode({
        'format': format,
        'version': version,
        'dbVersion': kDbVersion,
        'exportedAt': exportedAt.millisecondsSinceEpoch,
        'appVersion': '',
        'tables': <String, Object?>{},
      })));

  /// The automatic backups in [documents]/backups, newest first (empty when the folder is missing).
  static Future<List<File>> autoBackupFiles(Directory documents) async {
    final dir = Directory(p.join(documents.path, autoBackupDir));
    if (!await dir.exists()) return const [];
    final files = <File>[
      await for (final e in dir.list())
        if (e is File && p.basename(e.path).startsWith(filePrefix) && e.path.endsWith('.json')) e,
    ];
    // The name embeds yyyyMMdd_HHmm, so name order is time order.
    return files..sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
  }
}

/// [BackupService] over the app database.
class SqfliteBackupService implements BackupService {
  SqfliteBackupService(
    this._db, {
    required this._documentsDir,
    this._idMigrations = const {},
    this._knownExerciseIds,
    this._appVersion = AppInfo.fullVersion,
    this._clock = const SystemClock(),
  });

  static const String format = BackupFormat.format;
  static const int version = BackupFormat.version;
  static const int keepAutoBackups = 4;

  final AppDatabase _db;
  final Future<Directory> Function() _documentsDir;
  final Map<String, String> _idMigrations;

  /// Exercise ids of the bundled catalog; when given, the preview warns about unknown ones.
  final Set<String>? _knownExerciseIds;
  final String _appVersion;
  final Clock _clock;

  Database get _d => _db.db;

  /// Columns holding exercise ids, per table (mapped through `idMigrations` on import).
  static const Map<String, List<String>> _exerciseIdColumns = {
    'program_overrides': ['exercise_id'],
    'session_exercises': ['exercise_id', 'original_exercise_id'],
    'set_logs': ['exercise_id'],
    'exercise_state': ['exercise_id'],
    'personal_records': ['exercise_id'],
    'exercise_prefs': ['exercise_id'],
    'cardio_logs': ['exercise_id'],
  };

  /// Tables merged by date where the row with the newer `updated_at` wins.
  static const Set<String> _newerWins = {'body_entries', 'nutrition_days'};

  /// `legon_lift_backup_yyyyMMdd_HHmm.json`.
  static String fileNameFor(DateTime t) => BackupFormat.fileNameFor(t);

  // -- export ----------------------------------------------------------------------------------

  @override
  Future<Uint8List> exportJson() async {
    final tables = await _d.transaction((txn) async => {for (final t in kTables) t: await txn.query(t)});
    final doc = {
      'format': format,
      'version': version,
      'dbVersion': kDbVersion,
      'exportedAt': _clock.now().millisecondsSinceEpoch,
      'appVersion': _appVersion,
      'tables': tables,
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(doc)));
  }

  // -- reading a document ----------------------------------------------------------------------

  /// A decoded, validated backup with its rows migrated forward and exercise ids mapped.
  ({BackupTables tables, int dbVersion, DateTime exportedAt, int renamed}) _read(Uint8List bytes) {
    final Object? doc;
    try {
      doc = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const BackupFormatException('This file is not a Legon Lift backup.');
    }
    if (doc is! Map || doc['format'] != format) {
      throw const BackupFormatException('This file is not a Legon Lift backup.');
    }
    final dbVersion = doc['dbVersion'];
    if (dbVersion is! int || dbVersion < 1) {
      throw const BackupFormatException('This backup is damaged: its version is missing.');
    }
    if (dbVersion > kDbVersion) {
      throw const BackupFormatException('This backup comes from a newer version of the app. Update the app first.');
    }
    final rawTables = doc['tables'];
    if (rawTables is! Map) throw const BackupFormatException('This backup has no data tables.');

    final tables = <String, List<Map<String, Object?>>>{};
    for (final t in kTables) {
      final rows = rawTables[t];
      if (rows == null) continue;
      if (rows is! List) throw BackupFormatException('Part of this backup ("$t") is damaged.');
      tables[t] = [
        for (final r in rows)
          if (r is Map) {for (final e in r.entries) '${e.key}': e.value}
          else throw BackupFormatException('Part of this backup ("$t") is damaged.'),
      ];
    }

    for (var v = dbVersion + 1; v <= kDbVersion; v++) {
      backupRowMigrations[v]?.call(tables);
    }

    var renamed = 0;
    for (final MapEntry(key: table, value: cols) in _exerciseIdColumns.entries) {
      for (final row in tables[table] ?? const <Map<String, Object?>>[]) {
        for (final col in cols) {
          final mapped = _idMigrations[row[col]];
          if (mapped != null) {
            row[col] = mapped;
            renamed++;
          }
        }
      }
    }

    final exported = doc['exportedAt'];
    return (
      tables: tables,
      dbVersion: dbVersion,
      exportedAt: DateTime.fromMillisecondsSinceEpoch(exported is int ? exported : 0, isUtc: true).toLocal(),
      renamed: renamed,
    );
  }

  @override
  Future<ImportPreview> preview(Uint8List bytes) async {
    final read = _read(bytes);
    final tables = read.tables;
    List<Map<String, Object?>> rows(String t) => tables[t] ?? const [];

    final known = _knownExerciseIds;
    final unknown = <String>{
      if (known != null)
        for (final MapEntry(key: table, value: cols) in _exerciseIdColumns.entries)
          for (final row in rows(table))
            for (final col in cols)
              if (row[col] case final String id when !known.contains(id)) id,
    };
    final hasProfile = rows('kv').any((r) => r['key'] == KvKeys.profile);

    return ImportPreview(
      sessions: rows('sessions').where((r) => r['status'] == 'completed').length,
      sets: rows('set_logs').length,
      bodyEntries: rows('body_entries').length,
      nutritionDays: rows('nutrition_days').length,
      exportedAt: read.exportedAt,
      dbVersion: read.dbVersion,
      warnings: [
        if (read.dbVersion < kDbVersion) 'This backup was made by an older version of the app. It will be updated as it is restored.',
        if (read.renamed > 0)
          '${read.renamed} ${read.renamed == 1 ? 'entry uses an old exercise name' : 'entries use old exercise names'}; '
              'they will be matched to the current exercises.',
        if (unknown.isNotEmpty)
          '${unknown.length} ${unknown.length == 1 ? 'exercise is' : 'exercises are'} not in this version of the app. '
              'Their history is kept, but they will not be suggested.',
        if (!hasProfile) 'This backup has no profile. If you replace your data, you will do the short setup again.',
      ],
    );
  }

  // -- import ----------------------------------------------------------------------------------

  @override
  Future<void> import(Uint8List bytes, {required bool replace}) async {
    final tables = _read(bytes).tables;
    try {
      await _d.transaction((txn) async {
        if (replace) {
          for (final t in kTables.reversed) {
            await txn.delete(t);
          }
        }
        final localHasActive = !replace &&
            (Sqflite.firstIntValue(await txn.rawQuery('SELECT COUNT(*) FROM programs WHERE is_active = 1')) ?? 0) > 0;

        for (final t in kTables) {
          final source = tables[t];
          if (source == null || source.isEmpty) continue;
          final columns = (await txn.rawQuery('PRAGMA table_info($t)')).map((r) => r['name']! as String).toSet();
          final batch = txn.batch();
          for (final original in source) {
            // Unknown keys (from a damaged or hand-edited file) are dropped rather than failing.
            final row = {for (final e in original.entries) if (columns.contains(e.key)) e.key: e.value};
            if (t == 'programs' && localHasActive) row['is_active'] = 0; // keep exactly one active program
            if (!replace && _newerWins.contains(t)) {
              final existing = await txn.query(t, columns: ['updated_at'], where: 'date = ?', whereArgs: [row['date']]);
              if (existing.isNotEmpty) {
                final mine = existing.first['updated_at'] as int? ?? 0;
                final theirs = row['updated_at'] is int ? row['updated_at']! as int : 0;
                if (theirs > mine) batch.insert(t, row, conflictAlgorithm: ConflictAlgorithm.replace);
                continue;
              }
            }
            batch.insert(t, row, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
          await batch.commit(noResult: true);
        }
      });
    } on DatabaseException catch (e) {
      debugPrint('Backup import failed: $e');
      throw const BackupFormatException('Some of the data in this backup is damaged, so nothing was changed.');
    }
  }

  // -- automatic backups -----------------------------------------------------------------------

  @override
  Future<String> autoBackup() async {
    final documents = await _documentsDir();
    final dir = Directory(p.join(documents.path, BackupFormat.autoBackupDir));
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, fileNameFor(_clock.now())));
    // Write to a temp file first so a crash mid-write never leaves a half backup behind.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes(await exportJson(), flush: true);
    await tmp.rename(file.path);
    final backups = await BackupFormat.autoBackupFiles(documents);
    for (final old in backups.skip(keepAutoBackups)) {
      await old.delete();
    }
    return file.path;
  }
}
