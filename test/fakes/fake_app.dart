import 'package:legon_lift/data/assets/asset_catalog.dart';
import 'package:legon_lift/data/models/models.dart';
import 'package:legon_lift/main.dart';

import 'fake_clock.dart';
import 'fake_repositories.dart';
import 'fake_services.dart';
import 'sample_data.dart';
import 'test_catalog.dart';

/// Every fake wired together, with handles for assertions. `deps` plugs into `buildRoot`.
///
/// ```dart
/// final app = FakeApp.seeded();          // 3-session sample history, onboarded
/// await tester.pumpWidget(await buildRoot(app.deps));
/// ```
class FakeApp {
  FakeApp({AssetCatalog? catalog, FakeClock? clock})
      : catalog = catalog ?? loadTestCatalog(),
        clock = clock ?? FakeClock() {
    settings = FakeSettingsRepository(defaults: AppSettings.defaults(this.catalog.personalization.gym));
    programs = FakeProgramRepository(this.catalog, clock: this.clock);
    sessions = FakeSessionRepository(clock: this.clock, catalog: this.catalog);
    backup = FakeBackupService(
      sessions: sessions,
      body: body,
      nutrition: nutrition,
      settings: settings,
      programs: programs,
      exerciseStates: exerciseStates,
      activity: activity,
      milestones: milestones,
      clock: this.clock,
    );
  }

  /// Onboarded user with the sample history of [SampleData] (Push, Pull, Legs in week 1).
  factory FakeApp.seeded({AssetCatalog? catalog, FakeClock? clock}) {
    final app = FakeApp(catalog: catalog, clock: clock);
    SampleData.seed(app);
    return app;
  }

  final AssetCatalog catalog;
  final FakeClock clock;
  late final FakeSettingsRepository settings;
  late final FakeProgramRepository programs;
  late final FakeSessionRepository sessions;
  final FakeExerciseStateRepository exerciseStates = FakeExerciseStateRepository();
  final FakeBodyRepository body = FakeBodyRepository();
  final FakeNutritionRepository nutrition = FakeNutritionRepository();
  final FakeActivityRepository activity = FakeActivityRepository();
  final FakeMilestoneRepository milestones = FakeMilestoneRepository();
  late final FakeBackupService backup;
  final FakeRestAlarm restAlarm = FakeRestAlarm();
  final FakeNotificationService notifications = FakeNotificationService();
  final SilentSound sound = SilentSound();
  final NoopHaptics haptics = NoopHaptics();
  final NoopWakelock wakelock = NoopWakelock();
  final FakeLauncher launcher = FakeLauncher();

  AppDependencies get deps => AppDependencies(
        catalog: catalog,
        settings: settings,
        programs: programs,
        sessions: sessions,
        exerciseStates: exerciseStates,
        body: body,
        nutrition: nutrition,
        activity: activity,
        milestones: milestones,
        backup: backup,
        restAlarm: restAlarm,
        notifications: notifications,
        sound: sound,
        haptics: haptics,
        wakelock: wakelock,
        launcher: launcher,
        clock: clock,
      );
}
