// Owner: WS1. Platform file access for backups (share sheet, "Save to device", file picker).
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/backup/backup_service.dart';

/// Moving backup files in and out of the app. Tests swap in a fake.
abstract class BackupFiles {
  const BackupFiles();

  /// Opens the share sheet with the backup attached. True when the user picked a target.
  Future<bool> share(Uint8List bytes, String fileName);

  /// "Save to device" (system save dialog). True when saved, false when cancelled.
  Future<bool> saveToDevice(Uint8List bytes, String fileName);

  /// Lets the user choose a backup file. Null when cancelled.
  Future<Uint8List?> pick();
}

/// [BackupFiles] with share_plus and file_picker.
class PlatformBackupFiles extends BackupFiles {
  const PlatformBackupFiles();

  @override
  Future<bool> share(Uint8List bytes, String fileName) async {
    // A real file (not XFile.fromData) so the receiving app sees the proper file name.
    final dir = Directory(p.join((await getTemporaryDirectory()).path, 'share'));
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    final result = await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: BackupFormat.mimeType, name: fileName)],
      subject: 'Legon Lift backup',
      title: 'Save your Legon Lift backup',
    ));
    return result.status != ShareResultStatus.dismissed;
  }

  @override
  Future<bool> saveToDevice(Uint8List bytes, String fileName) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: BackupFormat.mimeType,
      dialogTitle: 'Save backup',
    );
    return uri != null;
  }

  @override
  Future<Uint8List?> pick() async {
    // FileType.any: many Android file managers do not tag .json files, so an extension filter
    // would hide real backups. The content is checked by BackupService.preview instead.
    final file = await FilePicker.pickFile(dialogTitle: 'Choose a Legon Lift backup');
    return file?.readAsBytes();
  }
}
