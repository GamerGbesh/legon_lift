// Owner: WS1. Bootstrap (SPEC 3.3): open the database and the asset catalog, build repositories,
// services and stores, then run the app.
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'app/app.dart';
import 'core/clock.dart';
import 'data/db/app_database.dart';
import 'data/models/models.dart';
import 'data/repositories/repositories.dart';
import 'services/api.dart';
import 'services/haptics_service.dart';
import 'services/launcher_service.dart';
import 'services/notification_service.dart';
import 'services/rest_alarm_service.dart';
import 'services/sound_service.dart';
import 'services/wakelock_service.dart';
import 'state/body_store.dart';
import 'state/history_store.dart';
import 'state/library_store.dart';
import 'state/milestone_store.dart';
import 'state/nutrition_store.dart';
import 'state/profile_store.dart';
import 'state/program_store.dart';
import 'state/settings_store.dart';
import 'state/today_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const clock = SystemClock();
  final (db, catalog) = await (AppDatabase.open(), JsonAssetCatalog.load(rootBundle)).wait;

  tz.initializeTimeZones();
  const notifications = LocalNotificationService();
  try {
    await notifications.init();
  } on Object catch (e, st) {
    // Reminders and the rest notification degrade; the app itself must still start.
    debugPrint('Notification setup failed: $e\n$st');
  }

  final deps = AppDependencies(
    catalog: catalog,
    settings: SqfliteSettingsRepository(db, defaults: AppSettings.defaults(catalog.personalization.gym)),
    programs: SqfliteProgramRepository(db, catalog, clock: clock),
    sessions: SqfliteSessionRepository(db, catalog, clock: clock),
    exerciseStates: SqfliteExerciseStateRepository(db),
    body: SqfliteBodyRepository(db, clock: clock),
    nutrition: SqfliteNutritionRepository(db, clock: clock),
    activity: SqfliteActivityRepository(db),
    milestones: SqfliteMilestoneRepository(db),
    backup: SqfliteBackupService(
      db,
      documentsDir: getApplicationDocumentsDirectory,
      idMigrations: catalog.idMigrations,
      knownExerciseIds: {for (final e in catalog.exercises) e.id},
      clock: clock,
    ),
    restAlarm: const LocalNotificationRestAlarm(),
    notifications: notifications,
    sound: AudioSoundService(),
    haptics: const DeviceHapticsService(),
    wakelock: const PlusWakelockService(),
    launcher: const UrlLauncherService(),
    clock: clock,
    documentsDir: getApplicationDocumentsDirectory,
  );

  final stores = await AppStores.create(deps);
  runApp(buildProviders(deps, stores));

  // Housekeeping after the first frame: weekly backup and reminder texts (which name the next
  // program day). Repeated whenever the app comes back to the foreground.
  Future<void> housekeeping() async {
    await stores.autoBackup.runIfDue();
    await stores.profile.syncReminders();
  }

  unawaited(housekeeping());
  // The listener registers itself with the binding, which keeps it alive for the app's lifetime.
  AppLifecycleListener(onResume: () => unawaited(housekeeping()));
}

/// Every repository and service the app needs. Tests build one from `test/fakes/`.
class AppDependencies {
  const AppDependencies({
    required this.catalog,
    required this.settings,
    required this.programs,
    required this.sessions,
    required this.exerciseStates,
    required this.body,
    required this.nutrition,
    required this.activity,
    required this.milestones,
    required this.backup,
    required this.restAlarm,
    required this.notifications,
    required this.sound,
    required this.haptics,
    required this.wakelock,
    required this.launcher,
    this.clock = const SystemClock(),
    this.documentsDir,
  });

  final AssetCatalog catalog;
  final SettingsRepository settings;
  final ProgramRepository programs;
  final SessionRepository sessions;
  final ExerciseStateRepository exerciseStates;
  final BodyRepository body;
  final NutritionRepository nutrition;
  final ActivityRepository activity;
  final MilestoneRepository milestones;
  final BackupService backup;
  final RestAlarm restAlarm;
  final NotificationService notifications;
  final SoundService sound;
  final HapticsService haptics;
  final WakelockService wakelock;
  final LauncherService launcher;
  final Clock clock;

  /// App documents folder (automatic backups live in `<documents>/backups`). Null in tests:
  /// the backup screen then lists no automatic backups.
  final Future<Directory> Function()? documentsDir;
}

/// The app-wide stores, created and loaded once at startup.
class AppStores {
  AppStores._({
    required this.settings,
    required this.profile,
    required this.program,
    required this.today,
    required this.history,
    required this.body,
    required this.library,
    required this.nutrition,
    required this.milestones,
    required this.autoBackup,
  });

  final SettingsStore settings;
  final ProfileStore profile;
  final ProgramStore program;
  final TodayStore today;
  final HistoryStore history;
  final BodyStore body;
  final LibraryStore library;
  final NutritionStore nutrition;
  final MilestoneStore milestones;
  final AutoBackupScheduler autoBackup;

  /// Builds every store from [d] and loads it.
  static Future<AppStores> create(AppDependencies d) async {
    final settingsStore = await SettingsStore.load(d.settings);
    final programStore = ProgramStore(catalog: d.catalog, programs: d.programs, sessions: d.sessions);
    final profileStore = ProfileStore(
      settingsRepository: d.settings,
      programs: d.programs,
      notifications: d.notifications,
      settings: settingsStore,
      programStore: programStore,
      body: d.body,
      clock: d.clock,
    );
    final milestoneStore = MilestoneStore(
      milestones: d.milestones,
      catalog: d.catalog,
      sessions: d.sessions,
      body: d.body,
      nutrition: d.nutrition,
      activity: d.activity,
      states: d.exerciseStates,
      settings: settingsStore,
      profile: profileStore,
      clock: d.clock,
    );
    final todayStore = TodayStore(
      catalog: d.catalog,
      sessions: d.sessions,
      programs: d.programs,
      states: d.exerciseStates,
      activity: d.activity,
      body: d.body,
      nutrition: d.nutrition,
      settings: settingsStore,
      profile: profileStore,
      program: programStore,
      milestones: milestoneStore,
      clock: d.clock,
    );
    final stores = AppStores._(
      settings: settingsStore,
      profile: profileStore,
      program: programStore,
      today: todayStore,
      history: HistoryStore(catalog: d.catalog, sessions: d.sessions, settings: settingsStore, clock: d.clock),
      body: BodyStore(body: d.body, clock: d.clock),
      library: LibraryStore(catalog: d.catalog, states: d.exerciseStates, settings: settingsStore),
      nutrition: NutritionStore(
        nutrition: d.nutrition,
        body: d.body,
        catalog: d.catalog,
        profile: profileStore,
        clock: d.clock,
      ),
      milestones: milestoneStore,
      autoBackup: AutoBackupScheduler(
        backup: d.backup,
        settings: d.settings,
        clock: d.clock,
        documentsDir: d.documentsDir,
      ),
    );
    await stores.reloadAll(settings: false);
    return stores;
  }

  /// Re-reads every store from the repositories, in dependency order. Used at startup and after
  /// a backup restore or "Reset all data" replaced the database underneath the stores.
  Future<void> reloadAll({bool settings = true}) async {
    if (settings) await this.settings.reload();
    await Future.wait([profile.load(), program.load()]);
    await Future.wait([milestones.load(), history.load(), body.load(), library.load(), nutrition.load()]);
    await today.refresh();
  }
}

/// The provider tree around [child]: [AssetCatalog], [Clock], every repository and service
/// interface, [AutoBackupScheduler], [AppStores] and the stores (ChangeNotifier).
/// `SessionPlayerController` is created per player route.
Widget buildProviders(AppDependencies d, AppStores s, {Widget child = const LegonLiftApp()}) {
  final List<SingleChildWidget> providers = [
    Provider<AssetCatalog>.value(value: d.catalog),
    Provider<Clock>.value(value: d.clock),
    Provider<SettingsRepository>.value(value: d.settings),
    Provider<ProgramRepository>.value(value: d.programs),
    Provider<SessionRepository>.value(value: d.sessions),
    Provider<ExerciseStateRepository>.value(value: d.exerciseStates),
    Provider<BodyRepository>.value(value: d.body),
    Provider<NutritionRepository>.value(value: d.nutrition),
    Provider<ActivityRepository>.value(value: d.activity),
    Provider<MilestoneRepository>.value(value: d.milestones),
    Provider<BackupService>.value(value: d.backup),
    Provider<RestAlarm>.value(value: d.restAlarm),
    Provider<NotificationService>.value(value: d.notifications),
    Provider<SoundService>.value(value: d.sound),
    Provider<HapticsService>.value(value: d.haptics),
    Provider<WakelockService>.value(value: d.wakelock),
    Provider<LauncherService>.value(value: d.launcher),
    Provider<AutoBackupScheduler>.value(value: s.autoBackup),
    Provider<AppStores>.value(value: s),
    ChangeNotifierProvider<SettingsStore>.value(value: s.settings),
    ChangeNotifierProvider<ProfileStore>.value(value: s.profile),
    ChangeNotifierProvider<ProgramStore>.value(value: s.program),
    ChangeNotifierProvider<TodayStore>.value(value: s.today),
    ChangeNotifierProvider<HistoryStore>.value(value: s.history),
    ChangeNotifierProvider<BodyStore>.value(value: s.body),
    ChangeNotifierProvider<LibraryStore>.value(value: s.library),
    ChangeNotifierProvider<NutritionStore>.value(value: s.nutrition),
    ChangeNotifierProvider<MilestoneStore>.value(value: s.milestones),
  ];
  return MultiProvider(providers: providers, child: child);
}

/// Creates and loads the stores, then returns the provider tree around [child] (tests:
/// `await tester.pumpWidget(await buildRoot(FakeApp().deps))`).
Future<Widget> buildRoot(AppDependencies d, {Widget child = const LegonLiftApp()}) async =>
    buildProviders(d, await AppStores.create(d), child: child);
