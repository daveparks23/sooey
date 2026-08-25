/// Where the game reads the time.
///
/// `advance` takes an `int nowMillis` rather than reading a clock itself, which
/// is what makes the simulation pure. This interface is the client's half of
/// that bargain: the device runs on [SystemClock], the dev harness runs the same
/// widget on a [FakeClock], and nothing between them knows the difference.
abstract interface class Clock {
  int get nowMillis;
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  int get nowMillis => DateTime.now().millisecondsSinceEpoch;
}

/// A clock the caller drives.
///
/// Deliberately dumb: it holds a number and nothing else. Speed multipliers and
/// jump buttons belong to the dev page that owns one, not in here, so tests can
/// step it exactly where they want it.
class FakeClock implements Clock {
  FakeClock(this.nowMillis);

  @override
  int nowMillis;

  void advance(int millis) => nowMillis += millis;
}
