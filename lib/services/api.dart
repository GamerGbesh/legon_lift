/// Service interfaces (SPEC 7.3). Frozen after Phase 0: change by RFC only.
/// Implementations: `lib/services/*_service.dart` (WS3); fakes: `test/fakes/fake_services.dart`.
library;

import '../data/models/models.dart';

/// The background rest-timer notification (SPEC 9.3).
abstract class RestAlarm {
  /// Schedules "Rest over" at [at] (replaces any previous rest alarm).
  Future<void> schedule(DateTime at, {required String title, required String body});
  Future<void> cancel();

  /// Asks for notification permission (first rest timer only). True when granted.
  Future<bool> ensurePermission();
}

/// Reminder notifications (SPEC 9.3).
abstract class NotificationService {
  /// Creates the channels; never prompts for permission.
  Future<void> init();

  /// Weekly reminders on [weekdays] (1 = Monday) at [hhmm]; [body] gives the text per weekday.
  Future<void> scheduleWorkoutReminders(List<int> weekdays, String hhmm, String Function(int weekday) body);
  Future<void> scheduleWeighIn(String hhmm);

  /// "Pack your gym bag" at 20:00 the evening before each workout weekday.
  Future<void> scheduleGymBag(List<int> workoutWeekdays);
  Future<void> cancelAllReminders();
}

/// Short sounds that duck music instead of stopping it (SPEC 11.6).
abstract class SoundService {
  Future<void> beep();
  Future<void> restDone();
}

abstract class HapticsService {
  /// 10 s left in a rest.
  Future<void> light();

  /// Rest over: three heavy pulses 150 ms apart.
  Future<void> heavyTriple();
}

/// Keeps the screen on in the player.
abstract class WakelockService {
  Future<void> enable();
  Future<void> disable();
}

/// Opens things outside the app (the only network use: the user-initiated video button).
abstract class LauncherService {
  /// Opens the pinned video, or a YouTube search for "`<name>` proper form". False if nothing opened.
  Future<bool> openVideo(Exercise ex);

  /// Opens the dialer with [number] (`tel:`).
  Future<bool> call(String number);
}
