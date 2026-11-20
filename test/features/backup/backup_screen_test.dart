import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/app/theme/app_theme.dart';
import 'package:legon_lift/app/theme/tokens.dart';
import 'package:legon_lift/features/backup/backup_screen.dart';
import 'package:legon_lift/main.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fakes.dart';
import 'fake_backup_files.dart';

void main() {
  Future<void> open(WidgetTester tester, FakeApp app, FakeBackupFiles files) async {
    tester.view.physicalSize = const Size(412, 892) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(await buildRoot(
      app.deps,
      child: MaterialApp(theme: AppTheme.build(legonNight), home: BackupScreen(files: files)),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets('share sends a dated backup file and remembers the export', (tester) async {
    final app = FakeApp.seeded();
    final files = FakeBackupFiles();
    await open(tester, app, files);
    expect(find.text('You have not saved a copy yet.'), findsOneWidget);

    await tap(tester, find.text('Share backup'));
    expect(files.shared, ['legon_lift_backup_20261116_1700.json']);
    final doc = jsonDecode(utf8.decode(files.lastBytes!)) as Map<String, dynamic>;
    expect(doc['format'], 'legon_lift_backup');
    expect(find.text('Backup shared.'), findsOneWidget);
    expect(find.textContaining('Last copy: Mon 16 Nov 2026, 17:00'), findsOneWidget);
  });

  testWidgets('a cancelled "Save to device" is not counted as a copy', (tester) async {
    final app = FakeApp.seeded();
    final files = FakeBackupFiles(saveSucceeds: false);
    await open(tester, app, files);
    await tap(tester, find.text('Save to device'));
    expect(files.saved, isEmpty);
    expect(app.settings.flags, isNot(contains('backup.last_export_ms')));
    expect(find.text('You have not saved a copy yet.'), findsOneWidget);
  });

  testWidgets('restore shows what is inside, merges, and can be undone', (tester) async {
    final source = FakeApp.seeded();
    final app = FakeApp();
    final files = FakeBackupFiles(toPick: await source.backup.exportJson());
    await open(tester, app, files);

    await tap(tester, find.text('Restore from a file'));
    expect(find.text('This backup holds'), findsOneWidget);
    expect(find.text('3 workouts'), findsOneWidget);
    expect(find.text('7 body weight entries'), findsOneWidget);
    expect(find.text('2 food days'), findsOneWidget);

    await tap(tester, find.text('Merge with my data'));
    expect(app.settings.profile, SampleData.profile());
    expect(app.sessions.sessions, hasLength(3));
    expect(find.text('Backup merged with your data.'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(app.settings.profile, isNull);
    expect(app.sessions.sessions, isEmpty);
    expect(find.text('Restore undone.'), findsOneWidget);
  });

  testWidgets('replace swaps the data for the backup', (tester) async {
    final source = FakeApp.seeded();
    final bytes = await source.backup.exportJson();
    final app = FakeApp.seeded();
    app.body.entries.clear();
    final files = FakeBackupFiles(toPick: bytes);
    await open(tester, app, files);

    await tap(tester, find.text('Restore from a file'));
    await tap(tester, find.text('Replace all my data'));
    expect(app.body.entries, hasLength(7));
    expect(find.text('Backup restored. Your data was replaced.'), findsOneWidget);
  });

  testWidgets('a file that is not a backup is refused without changes', (tester) async {
    final app = FakeApp.seeded();
    final files = FakeBackupFiles(toPick: Uint8List.fromList(utf8.encode('not json')));
    await open(tester, app, files);
    await tap(tester, find.text('Restore from a file'));
    expect(find.text('This file is not a Legon Lift backup.'), findsOneWidget);
    expect(find.text('This backup holds'), findsNothing);
    expect(app.backup.imports, 0);
  });

  testWidgets('cancelling the picker or the preview changes nothing', (tester) async {
    final app = FakeApp.seeded();
    final files = FakeBackupFiles();
    await open(tester, app, files);
    await tap(tester, find.text('Restore from a file'));
    expect(find.text('This backup holds'), findsNothing);

    files.toPick = await app.backup.exportJson();
    await tap(tester, find.text('Restore from a file'));
    expect(find.text('This backup holds'), findsOneWidget);
    await tester.tapAt(const Offset(200, 40)); // outside the sheet
    await tester.pumpAndSettle();
    expect(app.backup.imports, 0);
  });
}
