import 'package:flutter_test/flutter_test.dart';
import 'package:hog_sim/hog_sim.dart';
import 'package:sooey/game/clock.dart';
import 'package:sooey/game/game_controller.dart';
import 'package:sooey/game/screens/death_screen.dart';
import 'package:sooey/game/screens/device_screen.dart';

import 'screens/screen_test_support.dart';

const int _hour = 60 * 60 * 1000;

void main() {
  test('a pet can be fed, cleaned and played with, and dies if left alone', () {
    final clock = FakeClock(kRefNoon - 3 * _hour);
    final c = GameController(clock: clock, utcOffsetMinutes: 0);

    // Mark the egg.
    c.press(Button.b);

    // It hatches on its own after fifteen minutes, and three hours of piglet
    // is enough decay for the pig to accept a bucket.
    clock.advance(3 * _hour);
    c.tick();
    expect(c.pet.stage, Stage.piglet, reason: 'should have hatched');

    // Fed.
    final hungry = c.pet.fullness;
    c.press(Button.a); // feed
    c.press(Button.b); // open
    c.press(Button.b); // slop
    expect(c.pet.fullness, greaterThan(hungry));

    // Cleaned. The slop schedules a poop 150 minutes out; wait for it.
    clock.advance(3 * _hour);
    c.tick();
    expect(c.pet.poops, isNotEmpty, reason: 'a meal should produce a mess');
    // Walk to the icon rather than counting presses — the cursor is on feed
    // here, and a fixed count silently lands somewhere else if the icon order
    // ever moves.
    while (c.litIcon != DeviceIcon.clean) {
      c.press(Button.a);
    }
    c.press(Button.b);
    expect(c.pet.poops, isEmpty);
    expect(c.pet.cleanliness, 100);

    // Played with.
    final bored = c.pet.enrichment;
    while (c.litIcon != DeviceIcon.play) {
      c.press(Button.a);
    }
    c.press(Button.b); // open the hunt
    for (var i = 0; i < kPlayRounds; i++) {
      c.press(Button.a); // guess left
      clock.advance(2000);
      c.tick(); // let the reveal expire and the round turn over
    }
    expect(c.pet.enrichment, greaterThan(bored), reason: 'a hunt always pays');

    // And left alone.
    clock.advance(6 * 24 * _hour);
    c.tick();
    expect(c.pet.isDead, isTrue);
    expect(c.pet.deathCause, isNotNull);
    expect(c.screen, isA<DeathScreen>());
  });
}
