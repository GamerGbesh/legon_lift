import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/data/repositories/repositories.dart';

import '../fakes/fakes.dart';

class _FailingBackup extends FakeBackupService {
  _FailingBackup(FakeApp app) : super(sessions: app.sessions, body: app.body, nutrition: app.nutrition);

  @override
  Future<String> autoBackup() => throw const FileSystemException('disk full');
}

void main() {
  group('AutoBackupScheduler', () {
    late FakeApp app;
    late AutoBackupScheduler scheduler;

    setUp(() {
      app = FakeApp();
      scheduler = AutoBackupScheduler(backup: app.backup, settings: app.settings, clock: app.clock);
    });

    test('does nothing before onboarding (no data to save)', () async {
      expect(await scheduler.isDue(), isFalse);
      expect(await scheduler.runIfDue(), isNull);
      expect(app.backup.autoBackups, isEmpty);
    });

    test('runs weekly: first launch, then again only after 7 days', () async {
      app.settings.profile = SampleData.profile();

      expect(await scheduler.runIfDue(), isNotNull);
      expect(app.backup.autoBackups, ['legon_lift_backup_20261116_1700.json']);
      expect(await scheduler.lastRun(), app.clock.now());

      app.clock.advance(const Duration(days: 6, hours: 23));
      expect(await scheduler.runIfDue(), isNull);

      app.clock.advance(const Duration(hours: 1));
      expect(await scheduler.runIfDue(), isNotNull);
      expect(app.backup.autoBackups, hasLength(2));
    });

    test('concurrent calls (launch + resume) write one backup', () async {
      app.settings.profile = SampleData.profile();
      await Future.wait([scheduler.runIfDue(), scheduler.runIfDue()]);
      expect(app.backup.autoBackups, hasLength(1));
    });

    test('a safety copy does not move the weekly schedule', () async {
      app.settings.profile = SampleData.profile();
      await scheduler.saveSafetyCopy();
      expect(app.backup.autoBackups, hasLength(1));
      expect(await scheduler.lastRun(), isNull);
      expect(await scheduler.isDue(), isTrue);
    });

    test('a failure is swallowed and retried next time', () async {
      app.settings.profile = SampleData.profile();
      final failing = AutoBackupScheduler(backup: _FailingBackup(app), settings: app.settings, clock: app.clock);
      expect(await failing.runIfDue(), isNull);
      expect(await failing.lastRun(), isNull);
      expect(await failing.isDue(), isTrue);
    });

    test('lists the saved files newest first', () async {
      expect(await scheduler.list(), isEmpty, reason: 'no documents folder in tests');

      final docs = await Directory.systemTemp.createTemp('legon_lift_auto');
      addTearDown(() => docs.delete(recursive: true));
      final dir = Directory('${docs.path}/${BackupFormat.autoBackupDir}')..createSync();
      for (final name in ['legon_lift_backup_20261102_0900.json', 'legon_lift_backup_20261109_0900.json', 'notes.txt']) {
        File('${dir.path}/$name').writeAsBytesSync(Uint8List(2048));
      }
      final withDocs = AutoBackupScheduler(
        backup: app.backup,
        settings: app.settings,
        clock: app.clock,
        documentsDir: () async => docs,
      );
      final files = await withDocs.list();
      expect(files.map((f) => f.name), ['legon_lift_backup_20261109_0900.json', 'legon_lift_backup_20261102_0900.json']);
      expect(files.first.sizeBytes, 2048);
      expect(await files.first.read(), hasLength(2048));
    });
  });
}
