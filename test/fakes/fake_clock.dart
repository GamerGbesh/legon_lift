import 'package:legon_lift/core/clock.dart';

/// A controllable [Clock]. Times have millisecond precision so they survive JSON/DB round trips.
class FakeClock extends Clock {
  FakeClock([DateTime? start]) : _now = _truncate(start ?? defaultStart);

  /// Monday 16 Nov 2026, 17:00 local: the day after the sample history week.
  static final DateTime defaultStart = DateTime(2026, 11, 16, 17);

  DateTime _now;

  static DateTime _truncate(DateTime t) => DateTime.fromMillisecondsSinceEpoch(t.millisecondsSinceEpoch);

  @override
  DateTime now() => _now;

  void advance(Duration d) => _now = _now.add(d);

  void set(DateTime t) => _now = _truncate(t);
}
