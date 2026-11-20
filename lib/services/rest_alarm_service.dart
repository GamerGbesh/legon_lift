// Owner: WS3. The background "Rest over" notification (SPEC 9.3).
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api.dart';
import 'notification_service.dart';

/// [RestAlarm] using flutter_local_notifications `zonedSchedule` (channel `rest_timer`).
///
/// Exact alarms are used when the system allows them. Otherwise the alarm is inexact and an
/// ongoing notification with a count-down chronometer shows the live rest time in the shade.
class LocalNotificationRestAlarm implements RestAlarm {
  const LocalNotificationRestAlarm();

  static NotificationDetails _restDetails() => NotificationDetails(
        android: AndroidNotificationDetails(
          LegonNotifications.restChannelId,
          'Rest timer',
          channelDescription: 'Tells you when your rest between sets is over.',
          icon: LegonNotifications.icon,
          importance: Importance.high,
          priority: Priority.high,
          sound: const RawResourceAndroidNotificationSound(LegonNotifications.restSound),
          vibrationPattern: LegonNotifications.restVibration,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
        ),
      );

  static NotificationDetails _countdownDetails(DateTime endsAt) => NotificationDetails(
        android: AndroidNotificationDetails(
          LegonNotifications.countdownChannelId,
          'Rest countdown',
          channelDescription: 'Silent live countdown while you rest with the app in the background.',
          icon: LegonNotifications.icon,
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
          onlyAlertOnce: true,
          ongoing: true,
          autoCancel: false,
          usesChronometer: true,
          chronometerCountDown: true,
          when: endsAt.millisecondsSinceEpoch,
          visibility: NotificationVisibility.public,
        ),
      );

  @override
  Future<void> schedule(DateTime at, {required String title, required String body}) async {
    final android = LegonNotifications.android;
    if (android == null) return;
    await cancel();
    if (!at.isAfter(DateTime.now())) return;
    final exact = await _call(android.canScheduleExactNotifications) ?? false;
    await _call(() => LegonNotifications.plugin.zonedSchedule(
          id: LegonNotifications.restOverId,
          scheduledDate: LegonNotifications.utc(at),
          notificationDetails: _restDetails(),
          androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
          title: title,
          body: body,
        ));
    if (!exact) {
      await _call(() => LegonNotifications.plugin.show(
            id: LegonNotifications.restCountdownId,
            title: 'Resting',
            body: body.startsWith('Rest over: ') ? 'Next: ${body.substring(11)}' : body,
            notificationDetails: _countdownDetails(at),
          ));
    }
  }

  @override
  Future<void> cancel() async {
    if (LegonNotifications.android == null) return;
    await _call(() => LegonNotifications.plugin.cancel(id: LegonNotifications.restOverId));
    await _call(() => LegonNotifications.plugin.cancel(id: LegonNotifications.restCountdownId));
  }

  @override
  Future<bool> ensurePermission() async {
    final android = LegonNotifications.android;
    if (android == null) return true;
    return await _call(android.requestNotificationsPermission) ?? false;
  }
}

/// Runs a plugin call; platform failures are logged and turned into null.
Future<T?> _call<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on PlatformException catch (e) {
    debugPrint('Rest alarm call failed: ${e.code} ${e.message}');
  } on MissingPluginException {
    // Not on a device.
  } on ArgumentError catch (e) {
    debugPrint('Rest alarm call rejected: $e');
  }
  return null;
}
