import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/data/models/models.dart';
import 'package:legon_lift/data/repositories/repositories.dart';
import 'package:legon_lift/features/backup/data_actions.dart';
import 'package:legon_lift/main.dart';
import 'package:legon_lift/state/profile_store.dart';
import 'package:legon_lift/state/program_store.dart';
import 'package:legon_lift/state/settings_store.dart';
import 'package:legon_lift/services/api.dart';
import 'package:legon_lift/state/types.dart';

import '../fakes/fakes.dart';

void main() {
  group('SettingsStore', () {
    test('loads defaults, saves and notifies', () async {
      final app = FakeApp();
      final store = await SettingsStore.load(app.settings);
      expect(store.settings, AppSettings.defaults(app.catalog.personalization.gym));

      var notified = 0;
      store.addListener(() => notified++);
      final next = store.settings.copyWith(sound: false);
      await store.update(next);
      await store.update(next); // unchanged: no write, no notification
      expect(notified, 1);
      expect(app.settings.settings, next);
    });

    test('reload picks up settings written underneath it (restore, reset)', () async {
      final app = FakeApp();
      final store = await SettingsStore.load(app.settings);
      var notified = 0;
      store.addListener(() => notified++);
      await store.reload();
      expect(notified, 0, reason: 'nothing changed');
      app.settings.settings = store.settings.copyWith(palette: PaletteId.voltTeal);
      await store.reload();
      expect(store.settings.palette, PaletteId.voltTeal);
      expect(notified, 1);
    });
  });

  group('ProfileStore', () {
    Future<(FakeApp, ProfileStore, ProgramStore, SettingsStore)> build({
      bool seeded = false,
      FakeApp? fakeApp,
      NotificationService? notifications,
    }) async {
      final app = fakeApp ?? (seeded ? FakeApp.seeded() : FakeApp());
      final settings = await SettingsStore.load(app.settings);
      final program = ProgramStore(catalog: app.catalog, programs: app.programs, sessions: app.sessions);
      final profile = ProfileStore(
        settingsRepository: app.settings,
        programs: app.programs,
        notifications: notifications ?? app.notifications,
        settings: settings,
        programStore: program,
        body: app.body,
        clock: app.clock,
      );
      await profile.load();
      await program.load();
      return (app, profile, program, settings);
    }

    test('starts empty and loads a saved profile', () async {
      final (_, empty, _, _) = await build();
      expect(empty.profile, isNull);
      final (_, saved, program, _) = await build(seeded: true);
      expect(saved.profile, SampleData.profile());
      expect(program.trainingWeek, 2, reason: '3 completed sessions of a 3-day program');
      expect(program.nextDay?.dayId, 'push');
    });

    test('completeOnboarding saves everything, activates the program and schedules reminders', () async {
      final (app, store, program, settings) = await build();
      final profile = UserProfile.defaults(app.clock.now()).copyWith(name: () => 'Ama', workoutWeekdays: [2, 4, 6]);
      final chosen = settings.settings.copyWith(reminderTime: () => '16:00', weighInTime: () => '06:30');
      await store.completeOnboarding(OnboardingResult(profile: profile, settings: chosen, templateId: 'ppl_3day'));

      expect(store.profile, profile);
      expect(app.settings.profile, profile);
      expect(settings.settings, chosen);
      expect(program.active?.templateId, 'ppl_3day');
      expect(program.nextDay?.dayId, 'push');
      expect(app.notifications.workoutWeekdays, [2, 4, 6]);
      expect(app.notifications.workoutTime, '16:00');
      expect(app.notifications.workoutBodies[2], contains('Pack 1 L of water'));
      expect(app.notifications.weighInTime, '06:30');
      expect(app.notifications.gymBagWeekdays, [2, 4, 6]);
    });

    test('completeOnboarding logs the starting weight once and activates the program once', () async {
      final (app, store, _, settings) = await build();
      final profile = UserProfile.defaults(app.clock.now()).copyWith(startWaistCm: () => 104);
      final r = OnboardingResult(profile: profile, settings: settings.settings, templateId: 'ppl_3day');
      await Future.wait([store.completeOnboarding(r), store.completeOnboarding(r)]);
      expect(app.programs.programs, hasLength(1), reason: 'a double tap is ignored');
      expect(app.body.entries.values.single, const BodyEntry(date: '2026-11-16', weightKg: 95, waistCm: 104));

      // Onboarding again (e.g. after restoring a backup without a profile) keeps the program
      // and an existing weigh-in.
      await app.body.upsert(const BodyEntry(date: '2026-11-16', weightKg: 94));
      await store.completeOnboarding(r);
      expect(app.programs.programs, hasLength(1));
      expect(app.body.entries['2026-11-16']!.weightKg, 94);
    });

    test('a notification failure never blocks onboarding', () async {
      final app = FakeApp();
      final (_, store, program, settings) = await build(fakeApp: app, notifications: _BrokenNotifications());
      await store.completeOnboarding(OnboardingResult(
        profile: UserProfile.defaults(app.clock.now()),
        settings: settings.settings.copyWith(reminderTime: () => '16:00'),
        templateId: 'ppl_3day',
      ));
      expect(store.profile, isNotNull);
      expect(program.active, isNotNull);
    });

    test('reminders name the program day due on each workout weekday', () async {
      final (app, store, program, settings) = await build(seeded: true);
      // Mon 17:00, Push is next, reminders at 16:00: today's reminder has passed, so Push is Wednesday.
      await store.syncReminders();
      expect(app.notifications.workoutTime, '16:00');
      expect(app.notifications.workoutBodies, {
        1: 'Legs day today. Pack 1 L of water.',
        3: 'Push day today. Pack 1 L of water.',
        5: 'Pull day today. Pack 1 L of water.',
      });

      // Before 16:00 today's reminder is still ahead, so Push is today.
      app.clock.set(DateTime(2026, 11, 16, 9));
      expect(store.workoutReminderBodies(store.profile!, settings.settings)[1], startsWith('Push day'));

      // After Push is done, the reminders move on when synced.
      app.clock.set(DateTime(2026, 11, 16, 19));
      await app.programs.advanceAfter(program.active!.id, 'push');
      await program.load();
      await store.syncReminders();
      expect(app.notifications.workoutBodies[3], 'Pull day today. Pack 1 L of water.');
    });

    test('syncReminders skips unchanged reminders and follows setting changes', () async {
      final (app, store, _, settings) = await build(seeded: true);
      await store.syncReminders();
      final cancels = app.notifications.cancelAllCount;
      await store.syncReminders();
      expect(app.notifications.cancelAllCount, cancels, reason: 'nothing changed');

      await settings.update(settings.settings.copyWith(weighInTime: () => '06:30', gymBagReminder: false));
      await store.syncReminders();
      expect(app.notifications.weighInTime, '06:30');
      expect(app.notifications.gymBagWeekdays, isEmpty);

      await settings.update(settings.settings.copyWith(reminderTime: () => null));
      await store.syncReminders();
      expect(app.notifications.workoutWeekdays, isEmpty);
      expect(app.notifications.weighInTime, '06:30');
    });

    test('changing workout days reschedules; other days counts get generic text', () async {
      final (app, store, _, _) = await build(seeded: true);
      await store.syncReminders();
      await store.save(store.profile!.copyWith(workoutWeekdays: [2, 4, 6, 7], daysPerWeek: 4));
      expect(app.notifications.workoutWeekdays, [2, 4, 6, 7]);
      expect(app.notifications.gymBagWeekdays, [2, 4, 6, 7]);
      expect(app.notifications.workoutBodies.values.toSet(), {'Workout day today. Pack 1 L of water.'});
    });

    test('without a profile, sync cancels what was scheduled', () async {
      final (app, store, _, _) = await build(seeded: true);
      await store.syncReminders();
      app.settings.profile = null;
      await store.load();
      await store.syncReminders();
      expect(app.notifications.workoutWeekdays, isEmpty);
    });
  });

  group('DataActions', () {
    test('restore merges, reloads the stores, and undo puts the data back', () async {
      final source = FakeApp.seeded();
      final backupBytes = await source.backup.exportJson();

      final app = FakeApp();
      final stores = await AppStores.create(app.deps);
      final actions = DataActions(
        backup: app.backup,
        autoBackup: stores.autoBackup,
        settings: app.settings,
        stores: stores,
        clock: app.clock,
      );
      expect(stores.profile.profile, isNull);

      final snapshot = await actions.restore(backupBytes, replace: false);
      expect(stores.profile.profile, SampleData.profile());
      expect(stores.program.active?.id, SampleData.programId);
      expect(stores.settings.settings.reminderTime, '16:00');
      expect(app.notifications.workoutWeekdays, [1, 3, 5]);

      await actions.undo(snapshot);
      expect(stores.profile.profile, isNull);
      expect(stores.program.active, isNull);
      expect(app.sessions.sessions, isEmpty);
      expect(app.notifications.workoutWeekdays, isEmpty);
    });

    test('resetAll saves a safety copy, then erases everything', () async {
      final app = FakeApp.seeded();
      final stores = await AppStores.create(app.deps);
      final actions = DataActions(
        backup: app.backup,
        autoBackup: stores.autoBackup,
        settings: app.settings,
        stores: stores,
        clock: app.clock,
      );
      await actions.resetAll();
      expect(app.backup.autoBackups, hasLength(1));
      expect(app.settings.profile, isNull);
      expect(app.programs.programs, isEmpty);
      expect(app.sessions.sessions, isEmpty);
      expect(app.body.entries, isEmpty);
      expect(app.exerciseStates.states, isEmpty);
      expect(stores.profile.profile, isNull);
      expect(stores.settings.settings, AppSettings.defaults(app.catalog.personalization.gym));
    });

    test('resetAll erases nothing when the safety copy fails', () async {
      final app = FakeApp.seeded();
      final stores = await AppStores.create(app.deps);
      final actions = DataActions(
        backup: app.backup,
        autoBackup: AutoBackupScheduler(backup: _NoDiskBackup(app), settings: app.settings),
        settings: app.settings,
        stores: stores,
        clock: app.clock,
      );
      await expectLater(actions.resetAll(), throwsA(isA<Exception>()));
      expect(app.backup.imports, 0);
      expect(app.settings.profile, isNotNull);
    });

    test('last export is remembered', () async {
      final app = FakeApp();
      final stores = await AppStores.create(app.deps);
      final actions = DataActions(
        backup: app.backup,
        autoBackup: stores.autoBackup,
        settings: app.settings,
        stores: stores,
        clock: app.clock,
      );
      expect(await actions.lastExport(), isNull);
      final (bytes, name) = await actions.export();
      expect(name, 'legon_lift_backup_20261116_1700.json');
      expect(bytes, isNotEmpty);
      await actions.markExported();
      expect(await actions.lastExport(), app.clock.now());
    });
  });

  group('SampleData', () {
    test('is a consistent 3-session week 1', () {
      final app = FakeApp.seeded();
      final sessions = app.sessions.sessions.values.toList();
      expect(sessions.map((s) => s.dayId), ['push', 'pull', 'legs']);
      expect(sessions.every((s) => s.status == SessionStatus.completed), isTrue);
      expect(sessions.every((s) => s.totalVolumeKg > 0), isTrue);
      for (final s in sessions) {
        for (final set in s.allSets) {
          expect(set.sessionId, s.id);
          expect(s.exercises.any((e) => e.id == set.sessionExerciseId && e.exerciseId == set.exerciseId), isTrue);
        }
      }
      final press = app.exerciseStates.states['machine_chest_press']!;
      expect(press.workingKg, 20);
      expect(press.lastRepRange, (8, 12));
      expect(app.body.entries, hasLength(7));
    });
  });
}

class _BrokenNotifications extends FakeNotificationService {
  @override
  Future<void> cancelAllReminders() => throw StateError('plugin not ready');
}

class _NoDiskBackup extends FakeBackupService {
  _NoDiskBackup(FakeApp app) : super(sessions: app.sessions, body: app.body, nutrition: app.nutrition);

  @override
  Future<String> autoBackup() async => throw Exception('disk full');
}
