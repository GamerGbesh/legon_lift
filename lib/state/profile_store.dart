import 'package:flutter/foundation.dart';

import '../core/clock.dart';
import '../core/format.dart';
import '../data/models/models.dart';
import '../data/repositories/body_repository.dart';
import '../data/repositories/program_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../services/api.dart';
import 'program_store.dart';
import 'settings_store.dart';
import 'types.dart';

/// The user's profile, onboarding completion and reminder scheduling (SPEC 7.4). Owner: WS1.
class ProfileStore extends ChangeNotifier {
  ProfileStore({
    required SettingsRepository settingsRepository,
    required this._programs,
    required this._notifications,
    required this._settings,
    required this._programStore,
    this._body,
    this._clock = const SystemClock(),
    UserProfile? initial,
  })  : _repository = settingsRepository,
        _profile = initial;

  final SettingsRepository _repository;
  final ProgramRepository _programs;
  final NotificationService _notifications;
  final SettingsStore _settings;
  final ProgramStore _programStore;
  final BodyRepository? _body;
  final Clock _clock;
  UserProfile? _profile;
  bool _completing = false;

  /// What was last handed to the notification service, so unchanged reminders are not rescheduled.
  String? _scheduledSignature;

  /// Null until onboarding is completed (the app then shows `/onboarding`).
  UserProfile? get profile => _profile;

  /// Reads the saved profile.
  Future<void> load() async {
    _profile = await _repository.loadProfile();
    notifyListeners();
  }

  /// Saves the profile. Reminders follow when the workout days change.
  Future<void> save(UserProfile p) async {
    final before = _profile;
    await _repository.saveProfile(p);
    _profile = p;
    notifyListeners();
    if (before != null && !listEquals(before.workoutWeekdays, p.workoutWeekdays)) await syncReminders();
  }

  /// "Let's go" (SPEC 4.2 step 9): saves settings (incl. equipment), activates the program, logs
  /// the starting body weight, saves the profile and schedules reminders.
  ///
  /// The profile is saved last because a non-null profile switches the app from onboarding to
  /// the shell; everything the shell reads must exist by then. A second tap while this runs is
  /// ignored. Reminder problems never block onboarding.
  Future<void> completeOnboarding(OnboardingResult r) async {
    if (_completing) return;
    _completing = true;
    try {
      await _settings.update(r.settings);
      final active = await _programs.active();
      if (active == null || active.templateId != r.templateId) await _programs.activateTemplate(r.templateId);
      await _programStore.load();
      await _logStartingBody(r.profile);
      await _repository.saveProfile(r.profile);
      _profile = r.profile;
      notifyListeners();
      await syncReminders(force: true);
    } finally {
      _completing = false;
    }
  }

  /// The onboarding weight (and waist) as today's body entry, unless one is already logged.
  Future<void> _logStartingBody(UserProfile p) async {
    final body = _body;
    if (body == null) return;
    final today = Fmt.dateKey(_clock.now());
    if ((await body.range(today, today)).isNotEmpty) return;
    await body.upsert(BodyEntry(date: today, weightKg: p.weightKg, waistCm: p.startWaistCm));
  }

  /// (Re)schedules workout, weigh-in and gym-bag reminders from [p] and [s].
  Future<void> scheduleReminders(UserProfile p, AppSettings s) async {
    final bodies = workoutReminderBodies(p, s);
    await _notifications.cancelAllReminders();
    final time = s.reminderTime;
    if (time != null && bodies.isNotEmpty) {
      await _notifications.scheduleWorkoutReminders(
        bodies.keys.toList(),
        time,
        (weekday) => bodies[weekday] ?? _genericBody,
      );
    }
    final weighIn = s.weighInTime;
    if (weighIn != null) await _notifications.scheduleWeighIn(weighIn);
    if (s.gymBagReminder && p.workoutWeekdays.isNotEmpty) await _notifications.scheduleGymBag(_sortedDays(p));
    _scheduledSignature = _signature(p, s, bodies);
  }

  /// Brings the scheduled reminders in line with the current profile, settings and program.
  /// Does nothing when nothing changed since the last call (unless [force]). Called at launch,
  /// on resume, after onboarding and after reminder settings change. Never throws.
  Future<void> syncReminders({bool force = false}) async {
    try {
      final p = _profile;
      if (p == null) {
        if (force || _scheduledSignature != null) await _notifications.cancelAllReminders();
        _scheduledSignature = null;
        return;
      }
      final s = _settings.settings;
      if (!force && _signature(p, s, workoutReminderBodies(p, s)) == _scheduledSignature) return;
      await scheduleReminders(p, s);
    } on Object catch (e, st) {
      debugPrint('Could not schedule reminders: $e\n$st');
    }
  }

  static const String _genericBody = 'Workout day today. Pack 1 L of water.';

  static List<int> _sortedDays(UserProfile p) => p.workoutWeekdays.toSet().toList()..sort();

  String _signature(UserProfile p, AppSettings s, Map<int, String> bodies) => [
        s.reminderTime,
        s.weighInTime,
        s.gymBagReminder,
        for (final MapEntry(:key, :value) in bodies.entries) '$key=$value',
        _sortedDays(p).join(','),
      ].join('|');

  /// Reminder text per workout weekday ("Push day today. Pack 1 L of water.").
  ///
  /// When there is one workout weekday per program day (Mon/Wed/Fri for Push/Pull/Legs), the
  /// rotation is laid onto the coming weekdays starting from the next day due, so each weekly
  /// reminder names the right day as long as the user keeps to the plan. Otherwise the text is
  /// generic. Visible for tests.
  @visibleForTesting
  Map<int, String> workoutReminderBodies(UserProfile p, AppSettings s) {
    final days = _sortedDays(p);
    final generic = {for (final d in days) d: _genericBody};
    final active = _programStore.active;
    final template = _programStore.template;
    if (days.isEmpty || active == null || template == null || days.length != active.dayOrder.length) return generic;

    // The first workout weekday whose reminder is still ahead (today counts until its time).
    final now = _clock.now();
    final passedToday = s.reminderTime == null || !_isBefore(now, s.reminderTime!);
    var start = days.indexWhere((d) => d > now.weekday || (d == now.weekday && !passedToday));
    if (start < 0) start = 0;

    final out = <int, String>{};
    for (var j = 0; j < days.length; j++) {
      final weekday = days[(start + j) % days.length];
      final dayId = active.dayOrder[(active.nextDayIndex + j) % active.dayOrder.length];
      final name = _shortDayName(template, dayId);
      out[weekday] = name == null ? _genericBody : '$name day today. Pack 1 L of water.';
    }
    return {for (final d in days) d: out[d]!};
  }

  /// True when [now] is before the local time [hhmm] today.
  static bool _isBefore(DateTime now, String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts.first) ?? 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return now.hour * 60 + now.minute < h * 60 + m;
  }

  /// "Push (chest, shoulders, triceps)" -> "Push".
  static String? _shortDayName(ProgramTemplate t, String dayId) {
    for (final phase in t.phases) {
      final day = phase.day(dayId);
      if (day != null) return day.name.split(' (').first.trim();
    }
    return null;
  }
}
