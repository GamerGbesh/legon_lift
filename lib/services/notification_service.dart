// Owner: WS3. Notification channels and reminders (SPEC 9.3).
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'api.dart';

/// Channel ids, notification ids and the shared notification details (SPEC 9.3).
abstract final class LegonNotifications {
  static const String restChannelId = 'rest_timer';
  static const String remindersChannelId = 'reminders';

  /// Small icon (the launcher icon until a dedicated status-bar icon exists).
  static const String icon = '@mipmap/ic_launcher';

  /// "Rest over" (scheduled) and the ongoing live countdown shown when exact alarms are not allowed.
  static const int restOverId = 1;
  static const int restCountdownId = 2;

  /// Reminder ids: workout 100 + weekday, weigh-in 200, gym bag 300 + weekday (1 = Monday).
  static const int workoutBaseId = 100;
  static const int weighInId = 200;
  static const int gymBagBaseId = 300;

  /// The `res/raw` sound of the rest channel (copied from assets/sounds/rest_done.ogg, SPEC 1.2).
  static const String restSound = 'rest_done';

  static final Int64List restVibration = Int64List.fromList([0, 300, 150, 300, 150, 300]);

  static AndroidNotificationChannel get restChannel => AndroidNotificationChannel(
        restChannelId,
        'Rest timer',
        description: 'Tells you when your rest between sets is over.',
        importance: Importance.high,
        sound: const RawResourceAndroidNotificationSound(restSound),
        vibrationPattern: restVibration,
      );

  static const AndroidNotificationChannel remindersChannel = AndroidNotificationChannel(
    remindersChannelId,
    'Reminders',
    description: 'Workout days, weigh-ins and packing your gym bag.',
  );

  /// The plugin; a process-wide singleton (its factory always returns the same instance).
  static FlutterLocalNotificationsPlugin get plugin => FlutterLocalNotificationsPlugin();

  /// The Android implementation, or null on other platforms (tests, desktop).
  static AndroidFlutterLocalNotificationsPlugin? get android =>
      plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// [local] as an absolute instant in UTC (SPEC 9.3: schedule in `tz.UTC`).
  static tz.TZDateTime utc(DateTime local) => tz.TZDateTime.from(local.toUtc(), tz.UTC);
}

/// [NotificationService] using flutter_local_notifications (channels `rest_timer`, `reminders`).
///
/// Every platform call is guarded: a missing plugin (tests) or a refused permission never
/// breaks the caller; reminders are a convenience.
class LocalNotificationService implements NotificationService {
  const LocalNotificationService({
    this.gymBagItems = const ['towel', '1-1.5 L water bottle', 'phone charged', 'earphones', 'gym shoes'],
  });

  /// Items listed in the gym-bag reminder (`personalization.adherence.gym_bag_reminder.items`).
  final List<String> gymBagItems;

  static const NotificationDetails _reminderDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      LegonNotifications.remindersChannelId,
      'Reminders',
      channelDescription: 'Workout days, weigh-ins and packing your gym bag.',
      icon: LegonNotifications.icon,
    ),
  );

  @override
  Future<void> init() async {
    final android = LegonNotifications.android;
    if (android == null) return;
    await _guard(() async {
      await LegonNotifications.plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings(LegonNotifications.icon)),
      );
      await android.createNotificationChannel(LegonNotifications.restChannel);
      await android.createNotificationChannel(LegonNotifications.remindersChannel);
    });
  }

  @override
  Future<void> scheduleWorkoutReminders(List<int> weekdays, String hhmm, String Function(int weekday) body) async {
    final time = parseHhmm(hhmm);
    if (time == null || LegonNotifications.android == null) return;
    await _cancelIds([for (var d = 1; d <= 7; d++) LegonNotifications.workoutBaseId + d]);
    for (final weekday in weekdays.toSet()) {
      if (weekday < 1 || weekday > 7) continue;
      await _weekly(
        id: LegonNotifications.workoutBaseId + weekday,
        weekday: weekday,
        hour: time.$1,
        minute: time.$2,
        title: 'Workout day',
        body: body(weekday),
      );
    }
  }

  @override
  Future<void> scheduleWeighIn(String hhmm) async {
    final time = parseHhmm(hhmm);
    if (time == null || LegonNotifications.android == null) return;
    final now = DateTime.now();
    await _guard(() => LegonNotifications.plugin.zonedSchedule(
          id: LegonNotifications.weighInId,
          scheduledDate: LegonNotifications.utc(nextDaily(now, time.$1, time.$2)),
          notificationDetails: _reminderDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: 'Morning weigh-in',
          body: 'Weigh in after the toilet, before eating or drinking. Only the 7-day average matters.',
          matchDateTimeComponents: DateTimeComponents.time,
        ));
  }

  @override
  Future<void> scheduleGymBag(List<int> workoutWeekdays) async {
    if (LegonNotifications.android == null) return;
    await _cancelIds([for (var d = 1; d <= 7; d++) LegonNotifications.gymBagBaseId + d]);
    for (final workout in workoutWeekdays.toSet()) {
      if (workout < 1 || workout > 7) continue;
      final evening = workout == 1 ? 7 : workout - 1;
      await _weekly(
        id: LegonNotifications.gymBagBaseId + evening,
        weekday: evening,
        hour: 20,
        minute: 0,
        title: 'Workout tomorrow',
        body: 'Pack your gym bag: ${gymBagItems.join(', ')}.',
      );
    }
  }

  @override
  Future<void> cancelAllReminders() => _cancelIds([
        for (var d = 1; d <= 7; d++) LegonNotifications.workoutBaseId + d,
        LegonNotifications.weighInId,
        for (var d = 1; d <= 7; d++) LegonNotifications.gymBagBaseId + d,
      ]);

  Future<void> _weekly({
    required int id,
    required int weekday,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) =>
      _guard(() => LegonNotifications.plugin.zonedSchedule(
            id: id,
            scheduledDate: LegonNotifications.utc(nextWeekly(DateTime.now(), weekday, hour, minute)),
            notificationDetails: _reminderDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            title: title,
            body: body,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          ));

  Future<void> _cancelIds(List<int> ids) async {
    if (LegonNotifications.android == null) return;
    for (final id in ids) {
      await _guard(() => LegonNotifications.plugin.cancel(id: id));
    }
  }

  /// "16:30" -> (16, 30); null when malformed.
  @visibleForTesting
  static (int, int)? parseHhmm(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
    return (h, m);
  }

  /// The next local [hour]:[minute] strictly after [now].
  @visibleForTesting
  static DateTime nextDaily(DateTime now, int hour, int minute) {
    var at = DateTime(now.year, now.month, now.day, hour, minute);
    if (!at.isAfter(now)) at = DateTime(now.year, now.month, now.day + 1, hour, minute);
    return at;
  }

  /// The next local [weekday] (1 = Monday) at [hour]:[minute] strictly after [now].
  @visibleForTesting
  static DateTime nextWeekly(DateTime now, int weekday, int hour, int minute) {
    final days = (weekday - now.weekday) % 7;
    var at = DateTime(now.year, now.month, now.day + days, hour, minute);
    if (!at.isAfter(now)) at = DateTime(now.year, now.month, now.day + days + 7, hour, minute);
    return at;
  }
}

/// Runs a platform call, swallowing plugin errors (missing plugin, refused permission).
Future<void> _guard(Future<void> Function() call) async {
  try {
    await call();
  } on PlatformException catch (e) {
    debugPrint('Notification call failed: ${e.code} ${e.message}');
  } on MissingPluginException {
    // Not running on a device (tests, desktop).
  } on ArgumentError catch (e) {
    debugPrint('Notification call rejected: $e');
  }
}
