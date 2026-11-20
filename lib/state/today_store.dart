// Owner: WS4. Today tab: resume banner, next workout, week strip, streak and suggestion cards
// (SPEC 4.3, 7.4).
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/clock.dart';
import '../core/format.dart';
import '../core/ids.dart';
import '../data/models/models.dart';
import '../data/repositories/repositories.dart';
import '../domain/api.dart';
import 'milestone_store.dart';
import 'profile_store.dart';
import 'program_store.dart';
import 'settings_store.dart';
import 'types.dart';

/// One day of the Mon-Sun strip on Today.
@immutable
class WeekDayStatus {
  const WeekDayStatus({required this.date, required this.done, required this.planned, required this.isToday});

  final DateTime date;

  /// A workout was completed that day.
  final bool done;

  /// The day is one of the user's workout weekdays.
  final bool planned;
  final bool isToday;
}

/// Today tab: resume banner, next workout preview, streak and suggestion cards (SPEC 4.3).
///
/// Public API of SPEC 7.4 plus WS4 additions used by the Today screen: [loaded], [week],
/// [doneToday], [isWorkoutDay], [daysSinceLastWorkout], [nextWorkoutDate], [estimateMinutes],
/// [dismiss], [applyCheckin], [logCardio], [finishInProgress], [discardInProgress].
class TodayStore extends ChangeNotifier {
  /// [flags] persists card dismissals and once-a-day work (kv table); without it they last
  /// until the app restarts.
  TodayStore({
    required this._catalog,
    required this._sessions,
    required this._programs,
    required this._states,
    required this._activity,
    required this._body,
    required this._nutrition,
    required this._settings,
    required this._profile,
    required this._program,
    required this._milestones,
    required this._clock,
    this._flags,
  }) {
    _sub = _sessions.changes.listen((_) => unawaited(refresh()));
    _program.addListener(_onDependencyChanged);
    _profile.addListener(_onDependencyChanged);
    _settings.addListener(_onDependencyChanged);
  }

  final AssetCatalog _catalog;
  final SessionRepository _sessions;
  final ProgramRepository _programs;
  final ExerciseStateRepository _states;
  final ActivityRepository _activity;
  final BodyRepository _body;
  final NutritionRepository _nutrition;
  final SettingsStore _settings;
  final ProfileStore _profile;
  final ProgramStore _program;
  final MilestoneStore _milestones;
  final Clock _clock;
  final SettingsRepository? _flags;
  late final StreamSubscription<void> _sub;

  /// kv key holding `{cardKey: yyyy-MM-dd}` of dismissed cards.
  static const String dismissedFlag = 'today.dismissed';

  /// kv key holding the date milestones were last evaluated on app open.
  static const String milestonesCheckedFlag = 'today.milestones_checked';

  /// Hydration-friendly default times: "Hot today?" is on by default between these hours.
  static const int hotFromHour = 11, hotUntilHour = 17;

  Session? _inProgress;
  SessionPlan? _preview;
  Map<String, SessionPlan> _dayPlans = const {};
  StreakInfo _streak =
      const StreakInfo(weeks: 0, graceTokens: 0, thisWeekCounted: false, sessionsThisWeek: 0, targetThisWeek: 3);
  List<TodayCard> _cards = const [];
  List<WeekDayStatus> _week = const [];
  DateTime? _lastCompletedAt;
  bool _doneToday = false;
  bool _loaded = false;
  bool _disposed = false;
  Map<String, String>? _dismissed;

  Future<void>? _inFlight;
  bool _dirty = false;

  /// The unfinished session (resume banner), if any.
  Session? get inProgress => _inProgress;

  /// Next workout as it would be built now (hero card).
  SessionPlan? get preview => _preview;

  /// Every day of the program as it would be built now, by day id (Program tab and day editor
  /// show these counts and times so they match the Today card).
  Map<String, SessionPlan> get dayPlans => _dayPlans;
  StreakInfo get streak => _streak;
  List<TodayCard> get cards => _cards;

  /// True after the first [refresh] finished.
  bool get loaded => _loaded;

  /// Monday to Sunday of the current week.
  List<WeekDayStatus> get week => _week;

  /// A workout was completed today.
  bool get doneToday => _doneToday;

  /// Today is one of the user's workout weekdays.
  bool get isWorkoutDay => _profile.profile?.workoutWeekdays.contains(_clock.now().weekday) ?? true;

  /// Whole days since the last completed workout (null before the first one).
  int? get daysSinceLastWorkout {
    final last = _lastCompletedAt;
    if (last == null) return null;
    return _dayNumber(_clock.now()) - _dayNumber(last);
  }

  /// The next planned workout date after today (null without workout weekdays).
  DateTime? get nextWorkoutDate {
    final days = _profile.profile?.workoutWeekdays ?? const <int>[];
    if (days.isEmpty) return null;
    final today = _dateOnly(_clock.now());
    for (var i = 1; i <= 7; i++) {
      final d = today.add(Duration(days: i));
      if (days.contains(d.weekday)) return d;
    }
    return null;
  }

  /// "Hot today?" default for the pre-start sheet (SPEC 4.3): on between 11:00 and 17:00 when the
  /// hot-day setting is on.
  bool get hotDayDefault {
    final h = _clock.now().hour;
    return _settings.settings.hotDayAuto && h >= hotFromHour && h < hotUntilHour;
  }

  void _onDependencyChanged() => unawaited(refresh());

  /// Reloads everything. Calls made while a refresh runs are coalesced into one more pass.
  Future<void> refresh() {
    final running = _inFlight;
    if (running != null) {
      _dirty = true;
      return running;
    }
    final f = _refreshLoop();
    _inFlight = f;
    return f.whenComplete(() => _inFlight = null);
  }

  Future<void> _refreshLoop() async {
    do {
      _dirty = false;
      await _refreshOnce();
    } while (_dirty && !_disposed);
  }

  Future<void> _refreshOnce() async {
    final now = _clock.now();
    _dismissed ??= await _loadDismissed();
    _inProgress = await _sessions.findInProgress();
    final profile = _profile.profile;
    if (profile == null) {
      _preview = null;
      _dayPlans = const {};
      _cards = const [];
      _week = const [];
      _loaded = true;
      _notify();
      return;
    }

    final completed = await _sessions.listCompleted();
    _lastCompletedAt = await _sessions.lastCompletedAt();
    final todayKey = Fmt.dateKey(now);
    final doneDates = {for (final s in completed) Fmt.dateKey(s.startedAt)};
    _doneToday = doneDates.contains(todayKey);
    final monday = _dateOnly(now).subtract(Duration(days: now.weekday - 1));
    _week = [
      for (var i = 0; i < 7; i++)
        WeekDayStatus(
          date: monday.add(Duration(days: i)),
          done: doneDates.contains(Fmt.dateKey(monday.add(Duration(days: i)))),
          planned: profile.workoutWeekdays.contains(i + 1),
          isToday: i + 1 == now.weekday,
        ),
    ];
    _streak = weeklyStreak(completed, await _activity.pauses(), profile, now);

    final programIds = _programExerciseIds();
    final states = await _states.getAll(programIds);
    _preview = await _buildPlan(
      dayId: null,
      hotDay: false,
      recentIllness: false,
      cardioOff: false,
      states: states,
    );
    final plans = <String, SessionPlan>{};
    for (final d in _program.days) {
      final plan = await _buildPlan(
        dayId: d.dayId,
        hotDay: false,
        recentIllness: false,
        cardioOff: false,
        states: states,
      );
      if (plan != null) plans[d.dayId] = plan;
    }
    _dayPlans = plans;
    await _evaluateMilestonesOncePerDay(todayKey);
    _cards = await _buildCards(profile, now, completed, states);
    _loaded = true;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Set<String> _programExerciseIds() {
    final t = _program.template;
    if (t == null) return const {};
    return {
      for (final p in t.phases)
        for (final d in p.days) ...d.items.expand((i) => [i.exerciseId, ...i.substitutions]),
      for (final o in _program.overrides) o.exerciseId,
    };
  }

  Future<SessionPlan?> _buildPlan({
    required String? dayId,
    required bool hotDay,
    required bool recentIllness,
    required bool cardioOff,
    Map<String, ExerciseState>? states,
  }) async {
    final active = _program.active;
    final template = _program.template;
    final profile = _profile.profile;
    if (active == null || template == null || profile == null || active.dayOrder.isEmpty) return null;
    final input = BuildSessionInput(
      template: template,
      active: active,
      overrides: _program.overrides,
      dayId: dayId,
      catalog: _catalog,
      states: states ?? await _states.getAll(_programExerciseIds()),
      prefs: await _states.allPrefs(),
      completedNonDeload: _program.completedNonDeload,
      lastCompletedAt: await _sessions.lastCompletedAt(),
      settings: _settings.settings,
      profile: profile,
      now: _clock.now(),
      hotDay: hotDay,
      recentIllness: recentIllness,
      cardioOff: cardioOff,
      limitationRules: _catalog.personalization.limitationRules,
    );
    try {
      return buildSession(input);
    } on Object catch (e) {
      // A broken custom program must not take the whole Today tab down.
      debugPrint('TodayStore: could not build the session plan: $e');
      return null;
    }
  }

  /// Minutes today's session would take with the pre-start sheet choices.
  Future<int?> estimateMinutes({
    String? dayId,
    required bool hotDay,
    bool recentIllness = false,
    bool cardioOff = false,
  }) async {
    final plan = await _buildPlan(dayId: dayId, hotDay: hotDay, recentIllness: recentIllness, cardioOff: cardioOff);
    return plan?.estimatedMinutes;
  }

  /// Builds today's plan with the pre-start sheet choices, starts the session and returns its id.
  Future<String> startSession({
    String? dayId,
    required bool hotDay,
    required ReadinessCheck readiness,
    bool recentIllness = false,
    bool cardioOff = false,
  }) async {
    final plan = await _buildPlan(dayId: dayId, hotDay: hotDay, recentIllness: recentIllness, cardioOff: cardioOff);
    if (plan == null) throw StateError('No active program');
    final session = await _sessions.start(plan, readiness: readiness);
    _inProgress = session;
    _notify();
    return session.id;
  }

  /// "Finish and save" for a session left open (SPEC 4.3, 12 h rule): untouched exercises are
  /// skipped for lack of time, the session is completed, finished exercises progress and the
  /// rotation moves on.
  Future<void> finishInProgress() async {
    final s = _inProgress;
    if (s == null) return;
    for (final e in s.exercises) {
      final open = e.status == SessionExerciseStatus.pending || e.status == SessionExerciseStatus.active;
      if (open) {
        await _sessions.setExerciseStatus(
          e.id,
          e.workingSets.isEmpty ? SessionExerciseStatus.skipped : SessionExerciseStatus.done,
          reason: e.workingSets.isEmpty ? SkipReason.noTime : null,
        );
      }
    }
    final done = await _sessions.complete(s.id);
    await _progress(done);
    await _programs.advanceAfter(done.programId, done.dayId);
    final active = await _programs.active();
    if (done.isDeload && active != null && active.id == done.programId && active.reactiveDeloadRemaining > 0) {
      await _programs.save(active.copyWith(reactiveDeloadRemaining: active.reactiveDeloadRemaining - 1));
    }
    await _program.load();
    await _milestones.evaluateNow();
    await refresh();
  }

  /// Double progression for every exercise of [s] with working sets (SPEC 6.5).
  Future<void> _progress(Session s) async {
    final eq = _settings.settings.equipment;
    final items = {for (final step in s.plan.exerciseSteps) step.slotKey: step.item};
    for (final e in s.exercises) {
      final working = e.workingSets.toList();
      final ex = _catalog.tryExercise(e.exerciseId);
      final item = items[e.slotKey];
      if (working.isEmpty || ex == null || item == null || !ex.isLoaded) continue;
      final before = await _states.get(ex.id);
      final last = await _sessions.lastExposure(ex.id, excludingSessionId: s.id);
      final prefs = await _states.prefs(ex.id);
      await _states.put(afterSession(before, ex, item, e.target.targetRir, working, last, eq, prefs, _clock.now()));
    }
  }

  /// "Discard" for a session left open.
  Future<void> discardInProgress() async {
    final s = _inProgress;
    if (s == null) return;
    await _sessions.discard(s.id);
    _inProgress = null;
    await refresh();
  }

  /// Logs a rest-day cardio session (`cardio_logs`).
  Future<void> logCardio({required String exerciseId, required int minutes}) async {
    await _activity.addCardio(CardioLog(
      id: newId(),
      date: Fmt.dateKey(_clock.now()),
      exerciseId: exerciseId,
      durationSec: minutes * 60,
    ));
    await _milestones.evaluateNow();
    await refresh();
  }

  /// "Apply" on the weekly check-in card: stores the calorie adjustment (SPEC 10.2).
  Future<void> applyCheckin(CheckinAdvice advice) async {
    final now = _clock.now();
    await _nutrition.addCalorieAdjustment(CalorieAdjustment(
      id: newId(),
      date: Fmt.dateKey(now),
      ruleId: advice.ruleId,
      deltaKcal: advice.deltaKcal,
      deltaSteps: advice.deltaSteps == 0 ? null : advice.deltaSteps,
    ));
    await dismiss(CheckinCard(advice));
  }

  /// Hides [card] (the deload card for 7 days, the check-in card for this week, the others until
  /// their content changes).
  Future<void> dismiss(TodayCard card) async {
    final dismissed = _dismissed ??= await _loadDismissed();
    dismissed[_cardKey(card, _clock.now())] = Fmt.dateKey(_clock.now());
    await _flags?.setFlag(dismissedFlag, jsonEncode(dismissed));
    _cards = [for (final c in _cards) if (_cardKey(c, _clock.now()) != _cardKey(card, _clock.now())) c];
    _notify();
  }

  Future<Map<String, String>> _loadDismissed() async {
    final raw = await _flags?.getFlag(dismissedFlag);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map).map((k, v) => MapEntry('$k', '$v'));
    } on FormatException {
      return {};
    }
  }

  /// Identity of a card for dismissal. Weekly / per-item keys make a card come back when its
  /// content is new.
  static String _cardKey(TodayCard c, DateTime now) => switch (c) {
        DeloadCard() => 'deload',
        CheckinCard() => 'checkin:${Fmt.dateKey(_dateOnly(now).subtract(Duration(days: now.weekday - 1)))}',
        MilestoneCard(:final milestone) => 'milestone:${milestone.id}',
        VariationCard(:final exerciseId) => 'variation:$exerciseId',
        ParqRecheckCard() => 'parq',
        TipCard() => 'tip:${Fmt.dateKey(now)}',
      };

  /// Days since [key] was dismissed (null when it never was).
  int? _daysSinceDismissed(String key, DateTime now) {
    final d = _dismissed?[key];
    if (d == null) return null;
    final at = DateTime.tryParse(d);
    return at == null ? null : _dayNumber(now) - _dayNumber(at);
  }

  bool _hidden(TodayCard c, DateTime now, {int forDays = 100000}) {
    final days = _daysSinceDismissed(_cardKey(c, now), now);
    return days != null && days < forDays;
  }

  Future<void> _evaluateMilestonesOncePerDay(String todayKey) async {
    final flags = _flags;
    if (flags == null) return;
    if (await flags.getFlag(milestonesCheckedFlag) == todayKey) return;
    await flags.setFlag(milestonesCheckedFlag, todayKey);
    await _milestones.evaluateNow();
  }

  Future<List<TodayCard>> _buildCards(
    UserProfile profile,
    DateTime now,
    List<Session> completed,
    Map<String, ExerciseState> states,
  ) async {
    final cards = <TodayCard>[];
    final active = _program.active;

    // Easy week (reactive deload), SPEC 6.12; once dismissed, not again for 7 days.
    if (active != null && active.reactiveDeloadRemaining == 0 && _program.phase?.phaseId != PhaseId.deload) {
      final ofProgram = [for (final s in completed) if (s.programId == active.id) s];
      DateTime? lastDeload;
      for (final s in completed) {
        if (s.isDeload && (lastDeload == null || s.startedAt.isAfter(lastDeload))) lastDeload = s.startedAt;
      }
      final dismissedDays = _daysSinceDismissed('deload', now);
      final advice = adviseDeload(DeloadInput(
        recentSessions: ofProgram.length > 12 ? ofProgram.sublist(ofProgram.length - 12) : ofProgram,
        states: states,
        trainingWeek: _program.trainingWeek,
        lastDeloadAt: lastDeload,
        lastDismissedAt: dismissedDays == null ? null : now.subtract(Duration(days: dismissedDays)),
        now: now,
      ));
      final card = DeloadCard(reasons: advice.reasons);
      if (advice.suggest && !_hidden(card, now, forDays: 7)) cards.add(card);
    }

    // Weekly calorie check-in on the first workout weekday (SPEC 10.2).
    final firstWorkoutDay = profile.workoutWeekdays.isEmpty ? 1 : profile.workoutWeekdays.reduce(min);
    if (now.weekday == firstWorkoutDay) {
      final card = await _checkinCard(profile, now, states);
      if (card != null && !_hidden(card, now)) cards.add(card);
    }

    // Milestones just earned (this session / today's evaluation, or in the last 2 days).
    final p = _catalog.personalization;
    final recentIds = <String>{
      for (final m in _milestones.recent) m.id,
      for (final a in _milestones.awards)
        if (now.difference(a.awardedAt).inHours < 48) a.milestoneId,
    };
    for (final m in p.milestones) {
      final card = MilestoneCard(m);
      if (recentIds.contains(m.id) && !_hidden(card, now)) cards.add(card);
    }

    // "Try a variation?" after two resets on an exercise of the program; again after 30 days.
    for (final s in states.values) {
      final card = VariationCard(s.exerciseId);
      if (s.suggestSubstitution && !_hidden(card, now, forDays: 30)) cards.add(card);
    }

    // Yearly PAR-Q re-check (SPEC 4.11); snoozes for 7 days.
    final months = (p.safety['parq'] as Map?)?['re_ask_every_months'];
    final reAskDays = ((months is num ? months : 12) * 365 / 12).round();
    if (now.difference(profile.parqAnsweredAt).inDays >= reAskDays && !_hidden(const ParqRecheckCard(), now, forDays: 7)) {
      cards.add(const ParqRecheckCard());
    }

    final tip = _tipFor(profile, now);
    if (tip != null && !_hidden(TipCard(tip), now)) cards.add(TipCard(tip));
    return cards;
  }

  Future<CheckinCard?> _checkinCard(UserProfile profile, DateTime now, Map<String, ExerciseState> states) async {
    final p = _catalog.personalization;
    final from = Fmt.dateKey(now.subtract(const Duration(days: 35)));
    final to = Fmt.dateKey(now);
    final anchorIds = <String>{};
    final anchors = (p.raw['progress_tracking'] as Map?)?['strength_anchor_lifts'];
    if (anchors is List) {
      for (final a in anchors.whereType<Map<dynamic, dynamic>>()) {
        final ids = a['exercise_any'];
        if (ids is List) anchorIds.addAll(ids.whereType<String>());
      }
    }
    final anchorStates = await _states.getAll(anchorIds);
    final advice = weeklyCheckin(CheckinInput(
      body: await _body.range(from, to),
      nutrition: await _nutrition.range(from, to),
      adjustments: await _nutrition.adjustments(),
      anchorStates: anchorStates,
      profile: profile,
      p: p,
      now: now,
    ));
    if (advice.ruleId == 'not_enough_data' || advice.message.isEmpty) return null;
    return CheckinCard(advice);
  }

  /// Daily tip (SPEC 4.3, `tips_rotation`): the tip lists that fit today (training day, rest day,
  /// after a break, done today) are pooled and walked in a shuffled order that changes every
  /// cycle, so the same tip does not come back for at least a week.
  String? _tipFor(UserProfile profile, DateTime now) {
    final tips = _catalog.personalization.tips;
    final since = daysSinceLastWorkout;
    final List<String> keys;
    if (since != null && since >= 5 && !_doneToday) {
      keys = ['missed_session', 'pre_workout'];
    } else if (_doneToday) {
      keys = ['post_workout', 'soreness', 'daily_nutrition', 'sleep'];
    } else if (profile.workoutWeekdays.contains(now.weekday)) {
      keys = ['pre_workout', 'warm_up', 'gym_etiquette', 'during_workout_heat', 'safety'];
    } else {
      keys = ['daily_nutrition', 'hydration', 'sleep', 'soreness', 'budget', 'weigh_in', 'plateau'];
    }
    final pool = [for (final k in keys) ...?tips[k]];
    if (pool.isEmpty) return null;
    final day = _dayNumber(now);
    final cycle = day ~/ pool.length;
    final order = List<int>.generate(pool.length, (i) => i)..shuffle(Random(cycle));
    return pool[order[day % pool.length]];
  }

  static DateTime _dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

  /// Days since the epoch for a local calendar date (DST-safe).
  static int _dayNumber(DateTime t) => DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/ 86400000;

  @override
  void dispose() {
    _disposed = true;
    _program.removeListener(_onDependencyChanged);
    _profile.removeListener(_onDependencyChanged);
    _settings.removeListener(_onDependencyChanged);
    unawaited(_sub.cancel());
    super.dispose();
  }
}
