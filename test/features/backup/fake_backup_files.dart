import 'dart:typed_data';

import 'package:legon_lift/features/backup/backup_files.dart';

/// Records exports and hands back a scripted file for "Restore from a file".
class FakeBackupFiles extends BackupFiles {
  FakeBackupFiles({this.toPick, this.shareSucceeds = true, this.saveSucceeds = true});

  /// What the picker returns (null = the user cancelled).
  Uint8List? toPick;
  bool shareSucceeds, saveSucceeds;
  final List<String> shared = [], saved = [];
  Uint8List? lastBytes;

  @override
  Future<bool> share(Uint8List bytes, String fileName) async {
    lastBytes = bytes;
    if (shareSucceeds) shared.add(fileName);
    return shareSucceeds;
  }

  @override
  Future<bool> saveToDevice(Uint8List bytes, String fileName) async {
    lastBytes = bytes;
    if (saveSucceeds) saved.add(fileName);
    return saveSucceeds;
  }

  @override
  Future<Uint8List?> pick() async => toPick;
}
