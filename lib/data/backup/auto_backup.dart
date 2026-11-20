import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/clock.dart';
import '../repositories/settings_repository.dart';
import 'backup_service.dart';

/// One automatic backup file on the device.
@immutable
class AutoBackupFile {
  const AutoBackupFile({required this.path, required this.modified, required this.sizeBytes});

  final String path;
  final DateTime modified;
  final int sizeBytes;

  String get name => p.basename(path);

  Future<Uint8List> read() => File(path).readAsBytes();
}

/// Runs the weekly automatic backup (SPEC 9.2) and lists the saved copies.
///
/// The time of the last weekly run is kept in kv (`flags.backup.auto_last_ms`) so it travels with
/// the data. Safety copies made before a restore or a reset ([saveSafetyCopy]) do not move the
/// weekly schedule.
class AutoBackupScheduler {
  AutoBackupScheduler({
    required this._backup,
    required this._settings,
    this._clock = const SystemClock(),
    this._documentsDir,
  });

  /// Flag key (under `flags.`) holding the epoch milliseconds of the last weekly backup.
  static const String lastRunFlag = 'backup.auto_last_ms';
  static const Duration interval = Duration(days: 7);

  final BackupService _backup;
  final SettingsRepository _settings;
  final Clock _clock;
  final Future<Directory> Function()? _documentsDir;
  Future<String?>? _running;

  /// When the last weekly backup ran, or null if never.
  Future<DateTime?> lastRun() async {
    final ms = int.tryParse(await _settings.getFlag(lastRunFlag) ?? '');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// True when the user has data (finished onboarding) and the last weekly backup is 7+ days old.
  Future<bool> isDue() async {
    if (await _settings.loadProfile() == null) return false;
    final last = await lastRun();
    return last == null || !_clock.now().isBefore(last.add(interval));
  }

  /// Writes the weekly backup if it is due. Returns its path, or null when not due or when it
  /// failed (a failed automatic backup must never disturb the user; it is retried next launch).
  Future<String?> runIfDue() => _running ??= _runIfDue().whenComplete(() => _running = null);

  Future<String?> _runIfDue() async {
    try {
      if (!await isDue()) return null;
      final path = await _backup.autoBackup();
      await _settings.setFlag(lastRunFlag, '${_clock.now().millisecondsSinceEpoch}');
      return path;
    } on Object catch (e, st) {
      debugPrint('Automatic backup failed: $e\n$st');
      return null;
    }
  }

  /// Writes a backup now (before a restore or a reset), without moving the weekly schedule.
  Future<String> saveSafetyCopy() => _backup.autoBackup();

  /// The saved automatic backups, newest first. Empty when the folder is unknown or missing.
  Future<List<AutoBackupFile>> list() async {
    final docs = _documentsDir;
    if (docs == null) return const [];
    try {
      final out = <AutoBackupFile>[];
      for (final f in await BackupFormat.autoBackupFiles(await docs())) {
        final stat = await f.stat();
        out.add(AutoBackupFile(path: f.path, modified: stat.modified, sizeBytes: stat.size));
      }
      return out;
    } on FileSystemException catch (e) {
      debugPrint('Could not list automatic backups: $e');
      return const [];
    }
  }
}
