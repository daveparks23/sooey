import 'package:flutter_test/flutter_test.dart';
import 'package:sooey/game/clock.dart';

void main() {
  group('FakeClock', () {
    test('reports the time it was given', () {
      expect(FakeClock(1755000000000).nowMillis, 1755000000000);
    });

    test('advances by a delta', () {
      final c = FakeClock(1000)..advance(500);
      expect(c.nowMillis, 1500);
    });

    test('can be set outright, for jumping a day forward', () {
      final c = FakeClock(1000)..nowMillis = 99;
      expect(c.nowMillis, 99);
    });
  });

  group('SystemClock', () {
    test('is somewhere in the present century', () {
      // Loose on purpose: this is the one place a real clock is read, and the
      // only thing worth asserting is that it is wired to one.
      const c = SystemClock();
      expect(c.nowMillis, greaterThan(1600000000000));
    });
  });
}
