/// Time source. Inject a [Clock] instead of calling `DateTime.now()` so tests can control time
/// (`test/fakes/fake_clock.dart`).
abstract class Clock {
  const Clock();

  /// The current local time.
  DateTime now();
}

/// The real wall clock.
class SystemClock extends Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}
