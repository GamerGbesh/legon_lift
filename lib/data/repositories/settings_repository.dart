import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../db/schema.dart';
import '../models/models.dart';

/// Profile, settings and free-form flags (kv table; SPEC 7.1).
abstract class SettingsRepository {
  /// Saved settings, or the first-run defaults when nothing is saved yet.
  Future<AppSettings> loadSettings();
  Future<void> saveSettings(AppSettings s);

  /// Null until onboarding is completed.
  Future<UserProfile?> loadProfile();
  Future<void> saveProfile(UserProfile p);

  /// Flags such as one-time explainers (`flags.<key>` in kv). Null = not set.
  Future<String?> getFlag(String key);

  /// A null [value] removes the flag.
  Future<void> setFlag(String key, String? value);
}

/// [SettingsRepository] on the kv table.
class SqfliteSettingsRepository implements SettingsRepository {
  SqfliteSettingsRepository(this._db, {required this._defaults});

  final AppDatabase _db;
  final AppSettings _defaults;

  Database get _d => _db.db;

  Future<String?> _get(String key) async {
    final rows = await _d.query('kv', columns: ['value'], where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> _put(String key, String value) =>
      _d.insert('kv', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<AppSettings> loadSettings() async {
    final raw = await _get(KvKeys.settings);
    if (raw == null) return _defaults;
    return AppSettings.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
  }

  @override
  Future<void> saveSettings(AppSettings s) => _put(KvKeys.settings, jsonEncode(s.toJson()));

  @override
  Future<UserProfile?> loadProfile() async {
    final raw = await _get(KvKeys.profile);
    if (raw == null) return null;
    return UserProfile.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
  }

  @override
  Future<void> saveProfile(UserProfile p) => _put(KvKeys.profile, jsonEncode(p.toJson()));

  @override
  Future<String?> getFlag(String key) => _get('${KvKeys.flagPrefix}$key');

  @override
  Future<void> setFlag(String key, String? value) async {
    if (value == null) {
      await _d.delete('kv', where: 'key = ?', whereArgs: ['${KvKeys.flagPrefix}$key']);
    } else {
      await _put('${KvKeys.flagPrefix}$key', value);
    }
  }
}
