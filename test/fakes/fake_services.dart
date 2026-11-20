import 'package:legon_lift/data/models/models.dart';
import 'package:legon_lift/services/api.dart';

/// Records the scheduled rest alarm instead of showing a notification.
class FakeRestAlarm implements RestAlarm {
  FakeRestAlarm({this.permissionGranted = true});

  bool permissionGranted;
  DateTime? scheduledAt;
  String? title, body;
  int scheduleCount = 0, cancelCount = 0, permissionRequests = 0;

  bool get isScheduled => scheduledAt != null;

  @override
  Future<void> schedule(DateTime at, {required String title, required String body}) async {
    scheduledAt = at;
    this.title = title;
    this.body = body;
    scheduleCount++;
  }

  @override
  Future<void> cancel() async {
    scheduledAt = null;
    cancelCount++;
  }

  @override
  Future<bool> ensurePermission() async {
    permissionRequests++;
    return permissionGranted;
  }
}

/// Records reminder scheduling.
class FakeNotificationService implements NotificationService {
  bool initialized = false;
  List<int> workoutWeekdays = const [];
  String? workoutTime, weighInTime;
  List<int> gymBagWeekdays = const [];
  Map<int, String> workoutBodies = const {};
  int cancelAllCount = 0;

  @override
  Future<void> init() async => initialized = true;

  @override
  Future<void> scheduleWorkoutReminders(List<int> weekdays, String hhmm, String Function(int weekday) body) async {
    workoutWeekdays = List.of(weekdays);
    workoutTime = hhmm;
    workoutBodies = {for (final d in weekdays) d: body(d)};
  }

  @override
  Future<void> scheduleWeighIn(String hhmm) async => weighInTime = hhmm;

  @override
  Future<void> scheduleGymBag(List<int> workoutWeekdays) async => gymBagWeekdays = List.of(workoutWeekdays);

  @override
  Future<void> cancelAllReminders() async {
    cancelAllCount++;
    workoutWeekdays = const [];
    workoutTime = null;
    weighInTime = null;
    gymBagWeekdays = const [];
    workoutBodies = const {};
  }
}

/// Counts sounds instead of playing them.
class SilentSound implements SoundService {
  int beeps = 0, restDones = 0;

  @override
  Future<void> beep() async => beeps++;

  @override
  Future<void> restDone() async => restDones++;
}

/// Counts haptic pulses.
class NoopHaptics implements HapticsService {
  int lights = 0, heavyTriples = 0;

  @override
  Future<void> light() async => lights++;

  @override
  Future<void> heavyTriple() async => heavyTriples++;
}

/// Tracks whether the screen would be kept awake.
class NoopWakelock implements WakelockService {
  bool enabled = false;
  int enableCount = 0, disableCount = 0;

  @override
  Future<void> enable() async {
    enabled = true;
    enableCount++;
  }

  @override
  Future<void> disable() async {
    enabled = false;
    disableCount++;
  }
}

/// Records what would have been opened.
class FakeLauncher implements LauncherService {
  FakeLauncher({this.succeed = true});

  bool succeed;
  final List<String> openedVideos = [];
  final List<String> calledNumbers = [];

  @override
  Future<bool> openVideo(Exercise ex) async {
    openedVideos.add(ex.id);
    return succeed;
  }

  @override
  Future<bool> call(String number) async {
    calledNumbers.add(number);
    return succeed;
  }
}
