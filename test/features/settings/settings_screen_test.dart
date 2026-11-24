import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/app/routes.dart';
import 'package:legon_lift/app/theme/app_theme.dart';
import 'package:legon_lift/app/theme/tokens.dart';
import 'package:legon_lift/data/models/models.dart';
import 'package:legon_lift/features/backup/backup_screen.dart';
import 'package:legon_lift/features/settings/equipment_screen.dart';
import 'package:legon_lift/features/settings/settings_screen.dart';
import 'package:legon_lift/main.dart';
import 'package:legon_lift/state/profile_store.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../fakes/fakes.dart';
import '../backup/fake_backup_files.dart';

/// A stand-in for the app gate: "Onboarding" without a profile, else a home page that opens
/// Settings (so these tests do not depend on other workstreams' screens).
class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final onboarded = context.select<ProfileStore, bool>((s) => s.profile != null);
    return Scaffold(
      body: Center(
        child: onboarded
            ? TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
                child: const Text('Open settings'),
              )
            : const Text('Onboarding'),
      ),
    );
  }
}

void main() {
  Future<FakeApp> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 892) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final app = FakeApp.seeded();
    await tester.pumpWidget(await buildRoot(
      app.deps,
      child: MaterialApp(
        theme: AppTheme.build(legonNight),
        home: const _Gate(),
        routes: {Routes.backup: (_) => BackupScreen(files: FakeBackupFiles())},
      ),
    ));
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    return app;
  }

  /// Scrolls the (lazy) settings list until [f] is built, then brings it on screen.
  Future<void> reveal(WidgetTester tester, Finder f) async {
    final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    Future<void> sweep() async {
      while (f.evaluate().isEmpty && position.pixels < position.maxScrollExtent) {
        position.jumpTo((position.pixels + 300).clamp(0, position.maxScrollExtent));
        await tester.pump();
      }
    }

    await sweep();
    if (f.evaluate().isEmpty) {
      position.jumpTo(0);
      await tester.pump();
      await sweep();
    }
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    await reveal(tester, f);
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets('switches save at once', (tester) async {
    final app = await open(tester);
    await tap(tester, find.text('Beeps'));
    expect(app.settings.settings!.sound, isFalse);
    await tap(tester, find.text('Larger text'));
    expect(app.settings.settings!.largeText, isTrue);
    await tap(tester, find.text('Never'));
    expect(app.settings.settings!.rirPrompt, RirPrompt.never);
  });

  testWidgets('sets per exercise starts at 3 and moves by one', (tester) async {
    final app = await open(tester);
    await tap(tester, find.byTooltip('More').first);
    expect(app.settings.settings!.setsPerExercise, 4);
  });

  testWidgets('rest steppers move in 15 s steps', (tester) async {
    final app = await open(tester);
    await reveal(tester, find.text('Rest after big lifts'));
    final stepper = find.ancestor(of: find.text('Rest after big lifts'), matching: find.byType(Column)).first;
    final more = find.descendant(of: stepper, matching: find.byTooltip('More'));
    await tap(tester, more);
    expect(app.settings.settings!.restCompoundSec, 135);
    expect(find.text('2:15'), findsOneWidget);
  });

  testWidgets('units and workout days update the profile and the reminders', (tester) async {
    final app = await open(tester);
    await tap(tester, find.text('lb'));
    expect(app.settings.profile!.useLb, isTrue);

    await tap(tester, find.text('Tu'));
    expect(app.settings.profile!.workoutWeekdays, [1, 2, 3, 5]);
    expect(app.settings.profile!.daysPerWeek, 4);
    expect(app.notifications.workoutWeekdays, [1, 2, 3, 5]);
  });

  testWidgets('turning on the weigh-in reminder asks for permission and schedules it', (tester) async {
    final app = await open(tester);
    final row = find.widgetWithText(SwitchListTile, 'Weigh-in reminder');
    await tap(tester, row);
    expect(app.restAlarm.permissionRequests, 1);
    expect(app.settings.settings!.weighInTime, '06:30');
    expect(app.notifications.weighInTime, '06:30');
    expect(find.text('At 6:30 AM'), findsOneWidget);

    await tap(tester, row);
    expect(app.settings.settings!.weighInTime, isNull);
    expect(app.notifications.weighInTime, isNull);
  });

  testWidgets('equipment opens its own page and saves changes', (tester) async {
    final app = await open(tester);
    await tap(tester, find.text('Gym equipment'));
    expect(find.byType(EquipmentScreen), findsOneWidget);
    await tap(tester, find.widgetWithText(SwitchListTile, app.catalog.personalization.gym.labelFor(Equipment.dumbbell)));
    expect(app.settings.settings!.equipment.has(Equipment.dumbbell), isFalse);

    await tap(tester, find.text('Back to UG gym defaults'));
    expect(app.settings.settings!.equipment.has(Equipment.dumbbell), isTrue);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(app.settings.settings!.equipment.has(Equipment.dumbbell), isFalse);
  });

  testWidgets('palette and theme', (tester) async {
    final app = await open(tester);
    await tap(tester, find.text('Kente Energy'));
    expect(app.settings.settings!.palette, PaletteId.kenteEnergy);
    await tap(tester, find.text('Light'));
    expect(app.settings.settings!.themeMode, ThemeModePref.light);
  });

  testWidgets('backup link opens the backup screen', (tester) async {
    await open(tester);
    await tap(tester, find.text('Backup and restore'));
    expect(find.byType(BackupScreen), findsOneWidget);
  });

  testWidgets('reset needs the typed word, saves a safety copy and returns to onboarding', (tester) async {
    final app = await open(tester);
    await tap(tester, find.text('Reset all data'));
    expect(find.text('Erase everything?'), findsOneWidget);

    final erase = find.widgetWithText(TextButton, 'Erase everything');
    expect(tester.widget<TextButton>(erase).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'reset');
    await tester.pump();
    expect(tester.widget<TextButton>(erase).onPressed, isNotNull);
    await tester.tap(erase);
    await tester.pumpAndSettle();

    expect(app.backup.autoBackups, hasLength(1));
    expect(app.settings.profile, isNull);
    expect(app.sessions.sessions, isEmpty);
    expect(find.text('Onboarding'), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.textContaining('All data erased'), findsOneWidget);
  });

  testWidgets('dismissing the reset sheet keeps everything', (tester) async {
    final app = await open(tester);
    await tap(tester, find.text('Reset all data'));
    await tester.tap(find.text('Keep my data'));
    await tester.pumpAndSettle();
    expect(app.settings.profile, isNotNull);
    expect(app.backup.imports, 0);
  });
}
