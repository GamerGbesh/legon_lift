// Test harness for the session player. It deliberately avoids `FakeApp` / `SampleData` (they
// import `main.dart`, i.e. the whole app), so the player tests only compile what they use.
import 'package:legon_lift/data/models/models.dart';
import 'package:legon_lift/domain/api.dart';
import 'package:legon_lift/state/milestone_store.dart';
import 'package:legon_lift/state/profile_store.dart';
import 'package:legon_lift/state/program_store.dart';
import 'package:legon_lift/state/session_player_controller.dart';
import 'package:legon_lift/state/settings_store.dart';

import '../../fakes/fake_clock.dart';
import '../../fakes/fake_repositories.dart';
import '../../fakes/fake_services.dart';
import '../../fakes/test_catalog.dart';

/// Every fake the player needs, onboarded on `ppl_3day` (default user, week 1).
class PlayerFakes {
  PlayerFakes() {
    settings = FakeSettingsRepository(defaults: AppSettings.defaults(catalog.personalization.gym))
      ..profile = UserProfile.defaults(DateTime(2026, 11, 8, 20));
    programs = FakeProgramRepository(catalog, clock: clock);
    sessions = FakeSessionRepository(clock: clock, catalog: catalog);
    final t = catalog.template(templateId);
    programs.programs.add(ActiveProgram(
      id: programId,
      templateId: templateId,
      name: t.name,
      dayOrder: List.of(t.dayOrder),
      startedAt: DateTime(2026, 11, 8, 20),
    ));
  }

  static const String programId = 'test-program';
  static const String templateId = 'ppl_3day';

  final catalog = loadTestCatalog();
  final clock = FakeClock();
  late final FakeSettingsRepository settings;
  late final FakeProgramRepository programs;
  late final FakeSessionRepository sessions;
  final exerciseStates = FakeExerciseStateRepository();
  final body = FakeBodyRepository();
  final nutrition = FakeNutritionRepository();
  final activity = FakeActivityRepository();
  final milestones = FakeMilestoneRepository();
  final restAlarm = FakeRestAlarm();
  final notifications = FakeNotificationService();
  final sound = SilentSound();
  final haptics = NoopHaptics();
  final wakelock = NoopWakelock();
  final launcher = FakeLauncher();

  /// The week-1 plan of [dayId] (non-optional items, no finisher). Primaries find their weight.
  SessionPlan plan(String dayId) {
    final t = catalog.template(templateId);
    final phase = t.phases.first;
    final day = phase.day(dayId)!;
    final steps = <SessionStep>[];
    ExerciseStep exStep(int index, ProgramItem item) {
      final ex = catalog.exercise(item.exerciseId);
      final w = ex.isLoaded ? (ex.startingWeightKg?.low ?? 10) : 0.0;
      return ExerciseStep(
        index: index,
        item: item,
        slotKey: item.slotKey(),
        rx: Prescription(
          exerciseId: ex.id,
          working: [
            for (var i = 0; i < item.sets; i++)
              PlannedSet(
                kind: SetKind.working,
                weightKg: w,
                reps: ex.tracking == Tracking.time ? 0 : (item.repRange?.$1 ?? 10),
                durationSec: item.durationSeconds,
                targetRir: item.rir,
              ),
          ],
          restSec: item.restSeconds,
          targetRir: item.rir,
          trend: Trend.calibrate,
          findWeight: ex.isLoaded && item.role == ItemRole.primary,
          incrementKg: item.weightIncrementKg ?? ex.weightIncrementKg ?? 2.5,
        ),
      );
    }

    for (final block in day.blocks) {
      final items = block.items.where((i) => !i.optional).toList();
      if (items.isEmpty) continue;
      switch (block.blockType) {
        case BlockType.warmup:
          steps.add(WarmupCardioStep(index: steps.length, item: items.first));
          if (items.length > 1) steps.add(MobilityStep(index: steps.length, items: items.sublist(1)));
        case BlockType.main:
          for (final item in items) {
            steps.add(exStep(steps.length, item));
          }
        case BlockType.superset:
          final index = steps.length;
          steps.add(SupersetStep(
            index: index,
            group: block.supersetGroup ?? 'A',
            members: [for (final item in items) exStep(index, item)],
            roundRestSec: block.restBetweenRoundsSeconds ?? 60,
          ));
        case BlockType.finisher:
          break;
        case BlockType.cooldown:
          steps.add(CooldownStep(index: steps.length, items: block.items));
      }
    }
    return SessionPlan(
      programId: programId,
      templateId: templateId,
      phaseId: phase.phaseId,
      trainingWeek: 1,
      dayId: day.dayId,
      dayName: day.name,
      estimatedMinutes: day.estimatedMinutes.core,
      steps: steps,
    );
  }
}

/// A session in progress plus the stores the controller needs.
class PlayerHarness {
  PlayerHarness._(this.app, this.settings, this.milestones, this.programStore, this.sessionId);

  final PlayerFakes app;
  final SettingsStore settings;
  final MilestoneStore milestones;
  final ProgramStore programStore;
  final String sessionId;
  final List<SessionPlayerController> _controllers = [];

  /// Starts a session of [dayId] (the week-1 plan, optionally edited by [plan]).
  static Future<PlayerHarness> start({
    String dayId = 'push',
    SessionPlan Function(SessionPlan plan, PlayerFakes app)? plan,
    AppSettings Function(AppSettings s)? settings,
    PlayerFakes? fakes,
  }) async {
    final app = fakes ?? PlayerFakes();
    if (settings != null) app.settings.settings = settings(await app.settings.loadSettings());
    final store = await SettingsStore.load(app.settings);
    final programStore = ProgramStore(catalog: app.catalog, programs: app.programs, sessions: app.sessions);
    final profile = ProfileStore(
      settingsRepository: app.settings,
      programs: app.programs,
      notifications: app.notifications,
      settings: store,
      programStore: programStore,
    );
    await profile.load();
    await programStore.load();
    final milestones = MilestoneStore(
      milestones: app.milestones,
      catalog: app.catalog,
      sessions: app.sessions,
      body: app.body,
      nutrition: app.nutrition,
      activity: app.activity,
      states: app.exerciseStates,
      settings: store,
      profile: profile,
      clock: app.clock,
    );
    var p = app.plan(dayId);
    if (plan != null) p = plan(p, app);
    final session = await app.sessions.start(p, readiness: ReadinessCheck.none);
    return PlayerHarness._(app, store, milestones, programStore, session.id);
  }

  /// A new controller for the session (a fresh one simulates an app kill and relaunch).
  Future<SessionPlayerController> open() async {
    final c = create();
    await c.load();
    return c;
  }

  SessionPlayerController create() {
    final c = SessionPlayerController(
      sessionId: sessionId,
      catalog: app.catalog,
      sessions: app.sessions,
      states: app.exerciseStates,
      programs: app.programs,
      settings: settings,
      milestones: milestones,
      restAlarm: app.restAlarm,
      sound: app.sound,
      haptics: app.haptics,
      wakelock: app.wakelock,
      clock: app.clock,
    );
    _controllers.add(c);
    return c;
  }

  Session get session => app.sessions.sessions[sessionId]!;

  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    _controllers.clear();
  }
}

/// Plan edits used by the tests.
abstract final class Plans {
  /// Only the main exercise steps (no warm-up, no cool-down), none in find-your-weight mode.
  static SessionPlan mainOnly(SessionPlan p, PlayerFakes app) => p.copyWith(steps: [
        for (final (i, s) in p.steps.whereType<ExerciseStep>().indexed)
          s.copyWith(index: i, rx: s.rx.copyWith(findWeight: false, trend: Trend.same)),
      ]);

  /// The first [n] main exercises only; the first one finds its weight when [findWeight].
  static SessionPlan Function(SessionPlan, PlayerFakes) firstMain(int n, {bool findWeight = false}) =>
      (p, app) => p.copyWith(steps: [
            for (final (i, s) in p.steps.whereType<ExerciseStep>().take(n).indexed)
              s.copyWith(index: i, rx: s.rx.copyWith(findWeight: findWeight && i == 0)),
          ]);

  /// A pair of the day's 4th and 5th exercises as one superset.
  static SessionPlan pair(SessionPlan p, PlayerFakes app) {
    final ex = p.steps.whereType<ExerciseStep>().toList();
    return p.copyWith(steps: [
      SupersetStep(
        index: 0,
        group: 'A',
        members: [
          for (final e in [ex[3], ex[4]]) e.copyWith(index: 0, rx: e.rx.copyWith(findWeight: false)),
        ],
        roundRestSec: 60,
      ),
    ]);
  }
}
