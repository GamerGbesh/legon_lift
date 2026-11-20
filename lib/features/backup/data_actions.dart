// Owner: WS1. Whole-database actions shared by the Backup and Settings screens: restore a backup
// (with undo), reset all data, and remember the last export.
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/clock.dart';
import '../../data/repositories/repositories.dart';
import '../../main.dart';

/// Restores and resets go through the [BackupService] and then reload every store, because
/// the database changed underneath them.
class DataActions {
  DataActions({
    required this._backup,
    required this._autoBackup,
    required this._settings,
    required this._stores,
    required this._clock,
  });

  /// Reads everything it needs from the provider tree (built by `buildProviders` in main.dart).
  factory DataActions.of(BuildContext context) => DataActions(
        backup: context.read<BackupService>(),
        autoBackup: context.read<AutoBackupScheduler>(),
        settings: context.read<SettingsRepository>(),
        stores: context.read<AppStores>(),
        clock: context.read<Clock>(),
      );

  /// Flag (under `flags.`) with the epoch milliseconds of the last share / save to device.
  static const String lastExportFlag = 'backup.last_export_ms';

  final BackupService _backup;
  final AutoBackupScheduler _autoBackup;
  final SettingsRepository _settings;
  final AppStores _stores;
  final Clock _clock;

  BackupService get backup => _backup;
  AutoBackupScheduler get autoBackup => _autoBackup;
  DateTime get now => _clock.now();

  /// A fresh backup document and its file name.
  Future<(Uint8List, String)> export() async => (await _backup.exportJson(), BackupFormat.fileNameFor(now));

  Future<void> markExported() => _settings.setFlag(lastExportFlag, '${now.millisecondsSinceEpoch}');

  Future<DateTime?> lastExport() async {
    final ms = int.tryParse(await _settings.getFlag(lastExportFlag) ?? '');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Imports [bytes] (Replace or Merge) and reloads the app. Returns a snapshot of the data as it
  /// was before, for "Undo" ([undo]).
  Future<Uint8List> restore(Uint8List bytes, {required bool replace}) async {
    final before = await _backup.exportJson();
    await _backup.import(bytes, replace: replace);
    await _reload();
    return before;
  }

  /// Puts back the data saved by [restore].
  Future<void> undo(Uint8List snapshot) async {
    await _backup.import(snapshot, replace: true);
    await _reload();
  }

  /// "Reset all data": saves a safety copy into the automatic backups, then erases every table.
  /// If the safety copy cannot be written, nothing is erased (the error propagates).
  Future<void> resetAll() async {
    await _autoBackup.saveSafetyCopy();
    await _backup.import(BackupFormat.empty(now), replace: true);
    await _reload();
  }

  Future<void> _reload() async {
    await _stores.reloadAll();
    await _stores.profile.syncReminders(force: true);
  }
}
